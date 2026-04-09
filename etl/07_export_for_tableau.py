"""
═══════════════════════════════════════════════════════════════════════════
FILE    : 07_export_for_tableau.py
PROJECT : MSRB SONS DAIRY — Tableau Data Export
AUTHOR  : Pradeep Kumar
PURPOSE : Exports all fact tables + pre-computed KPI views as CSV files
          for Tableau Public (which cannot connect to PostgreSQL directly).
          
          If using Tableau Desktop, you do NOT need this script —
          connect directly to PostgreSQL instead.
          
USAGE   : python etl/07_export_for_tableau.py
OUTPUT  : data/tableau_export/*.csv (19 files)
═══════════════════════════════════════════════════════════════════════════
"""

import os
import sys
import logging
from datetime import datetime

import pandas as pd
from sqlalchemy import create_engine, text

# ─── Configuration ───────────────────────────────────────────────────────

# PostgreSQL connection string
# Update these values to match your local PostgreSQL setup
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "msrb_dairy_dw"
DB_USER = "postgres"
DB_PASS = "1234"        # ← Change this to your password

CONNECTION_STRING = f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# Output directory
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "data", "tableau_export")

# ─── Logging Setup ───────────────────────────────────────────────────────

LOG_DIR = os.path.join(PROJECT_ROOT, "logs")
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    handlers=[
        logging.FileHandler(
            os.path.join(LOG_DIR, f"tableau_export_{datetime.now():%Y%m%d_%H%M%S}.log")
        ),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger(__name__)

# ─── Tables & Views to Export ────────────────────────────────────────────

EXPORTS = {
    # ── Fact Tables ──
    "fact_sales":               "SELECT * FROM fact_sales",
    "fact_production":          "SELECT * FROM fact_production",
    "fact_inventory":           "SELECT * FROM fact_inventory",
    "fact_accounts":            "SELECT * FROM fact_accounts",

    # ── Dimension Tables ──
    "dim_date":                 "SELECT * FROM dim_date",
    "dim_product":              "SELECT * FROM dim_product",
    "dim_route":                "SELECT * FROM dim_route",
    "dim_customer":             "SELECT * FROM dim_customer",

    # ── Sales Views ──
    "vw_sales_monthly":         "SELECT * FROM vw_sales_monthly",
    "vw_yoy_revenue":           "SELECT * FROM vw_yoy_revenue",
    "vw_customer_segments":     "SELECT * FROM vw_customer_segments",

    # ── Production Views ──
    "vw_production_monthly":    "SELECT * FROM vw_production_monthly",
    "vw_category_efficiency":   "SELECT * FROM vw_category_efficiency",
    "vw_production_yoy_yield":  "SELECT * FROM vw_production_yoy_yield",
    "vw_shift_performance":     "SELECT * FROM vw_shift_performance",

    # ── Inventory Views ──
    "vw_stockout_frequency":    "SELECT * FROM vw_stockout_frequency",
    "vw_monthly_turnover":      "SELECT * FROM vw_monthly_turnover",
    "vw_stock_supply_risk":     "SELECT * FROM vw_stock_supply_risk",

    # ── Accounts Views ──
    "vw_billing_collections":   "SELECT * FROM vw_billing_collections",
    "vw_receivables_aging":     "SELECT * FROM vw_receivables_aging",
    "vw_customer_payment":      "SELECT * FROM vw_customer_payment",
    "vw_dso_monthly":           "SELECT * FROM vw_dso_monthly",
    "vw_custtype_efficiency":   "SELECT * FROM vw_custtype_efficiency",
}


# ─── Main Export Function ────────────────────────────────────────────────

def export_all():
    """Connect to PostgreSQL and export each table/view to CSV."""

    # Create output directory
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    log.info(f"Output directory: {OUTPUT_DIR}")

    # Connect to PostgreSQL
    log.info(f"Connecting to PostgreSQL: {DB_HOST}:{DB_PORT}/{DB_NAME}")
    try:
        engine = create_engine(CONNECTION_STRING)
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        log.info("[OK] PostgreSQL connection successful")
    except Exception as e:
        log.error(f"[FAIL] PostgreSQL connection failed: {e}")
        log.error("   -> Update DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS in this script")
        sys.exit(1)

    # Export each table/view
    total = len(EXPORTS)
    success = 0
    failed = 0

    log.info(f"\n{'='*70}")
    log.info(f" EXPORTING {total} TABLES/VIEWS FOR TABLEAU")
    log.info(f"{'='*70}\n")

    for name, query in EXPORTS.items():
        try:
            log.info(f"[>>] Exporting: {name}")
            df = pd.read_sql(query, engine)
            
            # Output file path
            csv_path = os.path.join(OUTPUT_DIR, f"{name}.csv")
            df.to_csv(csv_path, index=False, encoding="utf-8")
            
            log.info(f"   [OK] {name}.csv -> {len(df):,} rows x {len(df.columns)} cols")
            success += 1

        except Exception as e:
            log.warning(f"   [WARN] SKIPPED {name}: {e}")
            log.warning(f"      -> Ensure tableau_views.sql has been run in pgAdmin first")
            failed += 1

    # Summary
    log.info(f"\n{'='*70}")
    log.info(f" EXPORT COMPLETE")
    log.info(f"{'='*70}")
    log.info(f" [OK] Exported:  {success}/{total}")
    if failed:
        log.info(f" [WARN] Skipped: {failed}/{total}")
    log.info(f" [DIR] Output:   {OUTPUT_DIR}")
    log.info(f"{'='*70}\n")

    # File size summary
    log.info("File sizes:")
    total_size = 0
    for f in sorted(os.listdir(OUTPUT_DIR)):
        if f.endswith(".csv"):
            fpath = os.path.join(OUTPUT_DIR, f)
            size = os.path.getsize(fpath)
            total_size += size
            log.info(f"   {f:40s} {size/1024:>10,.1f} KB")
    log.info(f"   {'TOTAL':40s} {total_size/1024/1024:>10,.2f} MB")

    return success, failed


# ─── Entry Point ─────────────────────────────────────────────────────────

if __name__ == "__main__":
    log.info("=" * 70)
    log.info(" MSRB SONS DAIRY — TABLEAU DATA EXPORT")
    log.info(f" Started: {datetime.now():%Y-%m-%d %H:%M:%S}")
    log.info("=" * 70)

    success, failed = export_all()

    if failed == 0:
        log.info("\n[OK] All exports successful! Import these CSVs into Tableau Public.")
    else:
        log.info(f"\n[WARN] {failed} exports failed. Check if tableau_views.sql was executed.")
    
    log.info("\n--- NEXT STEPS ---")
    log.info("   1. Open Tableau Public")
    log.info("   2. Connect -> Text File")
    log.info(f"   3. Navigate to: {OUTPUT_DIR}")
    log.info("   4. Import each CSV as a separate data source")
    log.info("   5. Follow docs/tableau_dashboard_guide.md")
