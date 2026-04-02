"""
═══════════════════════════════════════════════════════════════════════════════
FILE        : 01_ingest.py
PROJECT     : MSRB SONS DAIRY PRODUCT PVT. LTD. — Analytics Pipeline
LAYER       : 1 — Data Ingestion
AUTHOR      : Pradeep Kumar
DESCRIPTION : Reads raw CSV files from data/raw/, runs structural validation,
              logs all issues found, and confirms files are ready for cleaning.
═══════════════════════════════════════════════════════════════════════════════
"""

from time import strftime
import os
import pandas as pd
import logging
from datetime import datetime

# ── CONFIGURATION ─────────────────────────────────────────────────────────────
BASE_DIR   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR    = os.path.join(BASE_DIR, 'data', 'raw')
LOG_DIR    = os.path.join(BASE_DIR, 'logs')
os.makedirs(LOG_DIR, exist_ok=True)

# ── LOGGING SETUP ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level    = logging.INFO,
    format   = '%(asctime)s | %(levelname)s | %(message)s',
    handlers = [
        logging.FileHandler(
    os.path.join(LOG_DIR, f'ingestion_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log')
),
        logging.StreamHandler()
    ]
)
log = logging.getLogger(__name__)

# ── EXPECTED SCHEMA PER FILE ──────────────────────────────────────────────────
EXPECTED_SCHEMA = {
    'fact_sales.csv': {
        'required_columns': [
            'sale_id','date','year','month','month_name','quarter',
            'customer_id','customer_name','customer_type',
            'route_id','route_name','product_id','product_name',
            'category','unit','quantity','unit_price',
            'gross_amount','discount','net_amount',
            'payment_mode','invoice_number'
        ],
        'date_columns'  : ['date'],
        'numeric_columns': ['quantity','unit_price','gross_amount','discount','net_amount'],
        'non_null_columns': ['sale_id','date','customer_id','product_id','net_amount'],
        'min_rows'      : 10000
    },
    'fact_production.csv': {
        'required_columns': [
            'production_id','date','year','month','month_name','quarter',
            'category','planned_qty','actual_qty','wastage_qty',
            'net_produced_qty','raw_milk_used_L',
            'production_efficiency_%','wastage_rate_%','shift','batch_number'
        ],
        'date_columns'  : ['date'],
        'numeric_columns': ['planned_qty','actual_qty','wastage_qty',
                            'net_produced_qty','raw_milk_used_L',
                            'production_efficiency_%','wastage_rate_%'],
        'non_null_columns': ['production_id','date','category','planned_qty','actual_qty'],
        'min_rows'      : 1000
    },
    'fact_inventory.csv': {
        'required_columns': [
            'inventory_id','date','year','month','month_name','quarter',
            'product_id','product_name','category',
            'opening_stock','received_qty','dispatched_qty',
            'closing_stock','reorder_level','stock_status'
        ],
        'date_columns'  : ['date'],
        'numeric_columns': ['opening_stock','received_qty','dispatched_qty',
                            'closing_stock','reorder_level'],
        'non_null_columns': ['inventory_id','date','product_id','closing_stock'],
        'min_rows'      : 2000
    },
    'fact_accounts.csv': {
        'required_columns': [
            'transaction_id','invoice_date','year','month','month_name','quarter',
            'customer_id','customer_name','customer_type','invoice_number',
            'due_date','invoice_amount','amount_paid','outstanding_balance',
            'payment_date','days_to_payment','payment_status','credit_days'
        ],
        'date_columns'  : ['invoice_date','due_date','payment_date'],
        'numeric_columns': ['invoice_amount','amount_paid',
                            'outstanding_balance','credit_days'],
        'non_null_columns': ['transaction_id','invoice_date','customer_id',
                             'invoice_amount'],
        'min_rows'      : 500
    }
}

# ── VALIDATION FUNCTIONS ───────────────────────────────────────────────────────
def check_required_columns(df: pd.DataFrame, required: list, fname: str) -> bool:
    missing = [c for c in required if c not in df.columns]
    if missing:
        log.error(f"[{fname}] Missing columns: {missing}")
        return False
    log.info(f"[{fname}] ✅ All {len(required)} required columns present")
    return True


def check_row_count(df: pd.DataFrame, min_rows: int, fname: str) -> bool:
    if len(df) < min_rows:
        log.warning(f"[{fname}] ⚠️  Only {len(df):,} rows — expected ≥ {min_rows:,}")
        return False
    log.info(f"[{fname}] ✅ Row count OK: {len(df):,}")
    return True


def check_nulls(df: pd.DataFrame, non_null_cols: list, fname: str) -> dict:
    null_report = {}
    for col in df.columns:
        n = df[col].isnull().sum()
        if n > 0:
            pct = round(n / len(df) * 100, 2)
            null_report[col] = {'count': n, 'pct': pct}
            severity = 'ERROR' if col in non_null_cols else 'INFO'
            log.log(
                logging.ERROR if severity == 'ERROR' else logging.INFO,
                f"[{fname}] {severity}: '{col}' has {n:,} nulls ({pct}%)"
            )
    if not null_report:
        log.info(f"[{fname}] ✅ No nulls in any column")
    return null_report


def check_duplicates(df: pd.DataFrame, id_col: str, fname: str) -> int:
    dups = df[id_col].duplicated().sum()
    if dups > 0:
        log.warning(f"[{fname}] ⚠️  {dups:,} duplicate values in '{id_col}'")
    else:
        log.info(f"[{fname}] ✅ No duplicates in '{id_col}'")
    return dups


def check_date_columns(df: pd.DataFrame, date_cols: list, fname: str):
    for col in date_cols:
        if col not in df.columns:
            continue
        try:
            parsed = pd.to_datetime(df[col], errors='coerce')
            bad    = parsed.isnull().sum() - df[col].isnull().sum()
            if bad > 0:
                log.warning(f"[{fname}] ⚠️  '{col}': {bad} unparseable date values")
            else:
                date_min = parsed.min()
                date_max = parsed.max()
                log.info(f"[{fname}] ✅ '{col}' range: {date_min.date()} → {date_max.date()}")
        except Exception as e:
            log.error(f"[{fname}] Date parse error in '{col}': {e}")


def check_numeric_columns(df: pd.DataFrame, numeric_cols: list, fname: str):
    for col in numeric_cols:
        if col not in df.columns:
            continue
        non_numeric = pd.to_numeric(df[col], errors='coerce').isnull().sum()
        if non_numeric > df[col].isnull().sum():
            log.warning(f"[{fname}] ⚠️  '{col}': non-numeric values detected")
        else:
            mn  = pd.to_numeric(df[col], errors='coerce').min()
            mx  = pd.to_numeric(df[col], errors='coerce').max()
            neg = (pd.to_numeric(df[col], errors='coerce') < 0).sum()
            if neg > 0:
                log.warning(f"[{fname}] ⚠️  '{col}': {neg} negative values (min={mn})")
            else:
                log.info(f"[{fname}] ✅ '{col}' range: {mn} → {mx}")


# ── MAIN INGESTION FUNCTION ───────────────────────────────────────────────────
def ingest_file(filename: str) -> pd.DataFrame | None:
    filepath = os.path.join(RAW_DIR, filename)

    log.info(f"\n{'═'*60}")
    log.info(f"INGESTING: {filename}")
    log.info(f"{'═'*60}")

    # — File exists check
    if not os.path.exists(filepath):
        log.error(f"[{filename}] FILE NOT FOUND at: {filepath}")
        return None

    # — Load
    try:
        df = pd.read_csv(filepath, low_memory=False)
        log.info(f"[{filename}] Loaded → {len(df):,} rows × {df.shape[1]} columns")
    except Exception as e:
        log.error(f"[{filename}] Failed to load: {e}")
        return None

    schema = EXPECTED_SCHEMA[filename]

    # — Run all checks
    check_required_columns(df, schema['required_columns'],  filename)
    check_row_count(df,        schema['min_rows'],           filename)
    check_nulls(df,            schema['non_null_columns'],   filename)
    check_duplicates(df,       schema['required_columns'][0],filename)   # first col = ID
    check_date_columns(df,     schema['date_columns'],       filename)
    check_numeric_columns(df,  schema['numeric_columns'],    filename)

    log.info(f"[{filename}] INGESTION COMPLETE ✅\n")
    return df


# ── ENTRY POINT ───────────────────────────────────────────────────────────────
def main():
    log.info(f"\n{'#'*60}")
    log.info(f"  MSRB DAIRY — DATA INGESTION PIPELINE")
    log.info(f"  Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log.info(f"  Source : {RAW_DIR}")
    log.info(f"{'#'*60}")

    files    = list(EXPECTED_SCHEMA.keys())
    results  = {}
    all_pass = True

    for fname in files:
        df = ingest_file(fname)
        results[fname] = df
        if df is None:
            all_pass = False

    # — Summary
    log.info(f"\n{'═'*60}")
    log.info("INGESTION SUMMARY")
    log.info(f"{'═'*60}")
    for fname, df in results.items():
        status = f"✅  {len(df):>7,} rows" if df is not None else "❌  FAILED"
        log.info(f"  {fname:<30} {status}")

    if all_pass:
        log.info("\n✅  ALL FILES INGESTED SUCCESSFULLY — Ready for cleaning layer")
    else:
        log.error("\n❌  SOME FILES FAILED — Fix errors before proceeding")

    log.info(f"  Finished: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    return results


if __name__ == '__main__':
    main()
