"""
═══════════════════════════════════════════════════════════════════════════════
FILE        : 06_load_to_postgres.py
PROJECT     : MSRB SONS DAIRY PRODUCT PVT. LTD. — Analytics Pipeline
LAYER       : 3 — Data Load  |  Target: PostgreSQL Data Warehouse
AUTHOR      : Pradeep Kumar
DESCRIPTION : Reads all 4 cleaned CSVs and loads them into PostgreSQL
              star schema tables. Runs post-load row count verification.

PREREQUISITES:
  pip install sqlalchemy psycopg2-binary pandas
  PostgreSQL running with schema already created (run schema_create.sql first)
═══════════════════════════════════════════════════════════════════════════════
"""

import os
import pandas as pd
import numpy as np  
import logging
from datetime import datetime
from sqlalchemy import create_engine,text

# ── PATHS ─────────────────────────────────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLEANED_DIR = os.path.join(BASE_DIR,'data','cleaned')
LOG_DIR = os.path.join(BASE_DIR,'logs')
os.makedirs(CLEANED_DIR,exist_ok=True)

os.makedirs(LOG_DIR,exist_ok=True)

log = logging.getLogger('load_to_postgres')
log.setLevel(logging.INFO)
log.handlers.clear()

# File handler — timestamped
fh = logging.FileHandler(
    os.path.join(LOG_DIR, f'load_to_postgres_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'),
    encoding='utf-8'
)
fh.setLevel(logging.INFO)

# Console handler
ch = logging.StreamHandler()
ch.setLevel(logging.INFO)

# Formatter
fmt = logging.Formatter('%(asctime)s | %(levelname)s | %(message)s')
fh.setFormatter(fmt)
ch.setFormatter(fmt)

log.addHandler(fh)
log.addHandler(ch)

# ── DATABASE CONFIG ────────────────────────────────────────────────────────────
# ⚠️  UPDATE THESE VALUES before running
DB_CONFIG = {
    'host'    : 'localhost',
    'port'    : 5432,
    'database': 'msrb_dairy_dw',       # create this DB first in pgAdmin
    'user'    : 'postgres',             # your PostgreSQL username
    'password': '****'    # your PostgreSQL password
}

# Build SQLAlchemy connection string
DB_URL = (
    f"postgresql+psycopg2://{DB_CONFIG['user']}:{DB_CONFIG['password']}"
    f"@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"
)

# ── FILE → TABLE MAPPING ───────────────────────────────────────────────────────
LOAD_CONFIG = {
    'fact_sales_cleaned.csv'      : 'fact_sales',
    'fact_production_cleaned.csv' : 'fact_production',
    'fact_inventory_cleaned.csv'  : 'fact_inventory',
    'fact_accounts_cleaned.csv'   : 'fact_accounts',
}

# ── COLUMN TYPE OVERRIDES per table ───────────────────────────────────────────
# Ensures date columns load correctly into PostgreSQL DATE type
DATE_COLUMNS = {
    'fact_sales'      : ['date'],
    'fact_production' : ['date'],
    'fact_inventory'  : ['date'],
    'fact_accounts'   : ['invoice_date','due_date','payment_date'],
}


def get_engine():
    """Create and test SQLAlchemy engine."""
    try:
        engine = create_engine(DB_URL, echo=False)
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        log.info(f"✅ Connected to PostgreSQL: {DB_CONFIG['database']} @ {DB_CONFIG['host']}")
        return engine
    except Exception as e:
        log.error(f"❌ Database connection failed: {e}")
        log.error("   Check DB_CONFIG values in this file")
        raise


def parse_dates(df: pd.DataFrame, table_name: str) -> pd.DataFrame:
    """Parse date columns for a given table."""
    date_cols = DATE_COLUMNS.get(table_name, [])
    for col in date_cols:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors='coerce')
    return df


def load_table(engine, filename: str, table_name: str, chunk_size: int = 5000):
    """Load a single cleaned CSV into PostgreSQL."""
    filepath = os.path.join(CLEANED_DIR, filename)

    if not os.path.exists(filepath):
        log.error(f"❌ File not found: {filepath}")
        log.error(f"   Run cleaning scripts first (02-05)")
        return False

    log.info(f"\n{'─'*55}")
    log.info(f"Loading: {filename} → {table_name}")

    try:
        df = pd.read_csv(filepath, low_memory=False)
        log.info(f"  Read {len(df):,} rows × {df.shape[1]} columns")

        # Parse dates
        df = parse_dates(df, table_name)

        # Load to PostgreSQL (replace = full reload each run)
        rows_loaded = 0
        for i, chunk in enumerate(range(0, len(df), chunk_size)):
            chunk_df = df.iloc[chunk:chunk+chunk_size]
            if_exists = 'replace' if chunk == 0 else 'append'
            chunk_df.to_sql(
                table_name,
                engine,
                if_exists = if_exists,
                index     = False,
                method    = 'multi'       # faster batch insert
            )
            rows_loaded += len(chunk_df)
            log.info(f"  Chunk {i+1}: {rows_loaded:,}/{len(df):,} rows loaded")

        log.info(f"  ✅ {table_name}: {len(df):,} rows loaded successfully")
        return True

    except Exception as e:
        log.error(f"  ❌ Failed to load {table_name}: {e}")
        return False


def verify_load(engine, table_name: str, expected_rows: int) -> bool:
    """Post-load row count verification."""
    try:
        with engine.connect() as conn:
            result = conn.execute(text(f"SELECT COUNT(*) FROM {table_name}"))
            actual = result.scalar()
        if actual == expected_rows:
            log.info(f"  ✅ {table_name}: {actual:,} rows verified")
            return True
        else:
            log.warning(f"  ⚠️  {table_name}: expected {expected_rows:,}, found {actual:,}")
            return False
    except Exception as e:
        log.error(f"  ❌ Verification failed for {table_name}: {e}")
        return False


def add_indexes(engine):
    """Add indexes for query performance — run after load."""
    indexes = [
        "CREATE INDEX IF NOT EXISTS idx_sales_date        ON fact_sales(date);",
        "CREATE INDEX IF NOT EXISTS idx_sales_customer    ON fact_sales(customer_id);",
        "CREATE INDEX IF NOT EXISTS idx_sales_product     ON fact_sales(product_id);",
        "CREATE INDEX IF NOT EXISTS idx_sales_route       ON fact_sales(route_id);",
        "CREATE INDEX IF NOT EXISTS idx_prod_date         ON fact_production(date);",
        "CREATE INDEX IF NOT EXISTS idx_prod_category     ON fact_production(category);",
        "CREATE INDEX IF NOT EXISTS idx_inv_date          ON fact_inventory(date);",
        "CREATE INDEX IF NOT EXISTS idx_inv_product       ON fact_inventory(product_id);",
        "CREATE INDEX IF NOT EXISTS idx_acc_customer      ON fact_accounts(customer_id);",
        "CREATE INDEX IF NOT EXISTS idx_acc_status        ON fact_accounts(payment_status);",
        "CREATE INDEX IF NOT EXISTS idx_acc_invoice_date  ON fact_accounts(invoice_date);",
    ]
    log.info("\nCreating indexes for query performance...")
    with engine.connect() as conn:
        for sql in indexes:
            try:
                conn.execute(text(sql))
                conn.commit()
                idx_name = sql.split('idx_')[1].split(' ')[0]
                log.info(f"  ✅ Index created: idx_{idx_name}")
            except Exception as e:
                log.warning(f"  ⚠️  Index skipped: {e}")
    log.info("✅ All indexes created")


def main():
    log.info("═"*60)
    log.info("MSRB DAIRY — POSTGRESQL LOAD PIPELINE")
    log.info(f"Started : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log.info(f"Target  : {DB_CONFIG['database']} @ {DB_CONFIG['host']}")
    log.info("═"*60)

    # Connect
    engine = get_engine()

    # Load each table
    results       = {}
    expected_rows = {}

    for filename, table_name in LOAD_CONFIG.items():
        filepath = os.path.join(CLEANED_DIR, filename)
        if os.path.exists(filepath):
            df_temp = pd.read_csv(filepath, nrows=0)  # just get row count
            expected_rows[table_name] = sum(1 for _ in open(filepath)) - 1
        success = load_table(engine, filename, table_name)
        results[table_name] = success

    # Verify loads
    log.info("\n" + "─"*55)
    log.info("POST-LOAD VERIFICATION")
    log.info("─"*55)
    for table_name, success in results.items():
        if success:
            exp = expected_rows.get(table_name, 0)
            verify_load(engine, table_name, exp)

    # Add indexes
    add_indexes(engine)

    # Final summary
    log.info("\n" + "═"*60)
    log.info("LOAD SUMMARY")
    log.info("═"*60)
    all_ok = all(results.values())
    for table, ok in results.items():
        status = "✅ SUCCESS" if ok else "❌ FAILED"
        log.info(f"  {table:<25} {status}")

    if all_ok:
        log.info("\n✅ ALL TABLES LOADED — Data warehouse is ready")
        log.info("   Next step: Open Tabular Model / Power BI Desktop")
        log.info("   Connect to: localhost | msrb_dairy_dw")
    else:
        log.error("\n❌ SOME TABLES FAILED — Check logs above")

    log.info(f"Finished: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")


if __name__ == '__main__':
    main()
