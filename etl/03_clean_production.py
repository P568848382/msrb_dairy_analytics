"""
═══════════════════════════════════════════════════════════════════════════════
FILE        : 03_clean_production.py
PROJECT     : MSRB SONS DAIRY PRODUCT PVT. LTD. — Analytics Pipeline
LAYER       : 2 — Data Cleaning  |  Department: PRODUCTION
AUTHOR      : Pradeep Kumar
DESCRIPTION : Cleans fact_production.csv — validates efficiency metrics,
              flags impossible values, derives KPI-ready columns.
═══════════════════════════════════════════════════════════════════════════════
"""

import os
import pandas as pd
import numpy as np
import logging
from datetime import datetime

BASE_DIR    = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR     = os.path.join(BASE_DIR, 'data', 'raw')
CLEANED_DIR = os.path.join(BASE_DIR, 'data', 'cleaned')
LOG_DIR     = os.path.join(BASE_DIR, 'logs')
os.makedirs(CLEANED_DIR, exist_ok=True)
os.makedirs(LOG_DIR,     exist_ok=True)

logging.basicConfig(
    level    = logging.INFO,
    format   = '%(asctime)s | %(levelname)s | %(message)s',
    handlers = [
        logging.FileHandler(os.path.join(LOG_DIR, 'clean_production.log')),
        logging.StreamHandler()
    ]
)
log = logging.getLogger(__name__)

VALID_CATEGORIES = {'Milk Bulk','Milk Packet','Paneer','Curd','Ghee','Butter','Cream'}
VALID_SHIFTS     = {'Morning','Evening','Night'}
DATE_START       = pd.Timestamp('2023-04-01')
DATE_END         = pd.Timestamp('2025-03-31')


def clean_production(df: pd.DataFrame) -> pd.DataFrame:
    original_rows = len(df)
    log.info(f"Starting clean — {original_rows:,} rows loaded")
    df = df.copy()

    # ── STEP 1: Strip whitespace ───────────────────────────────────────────────
    str_cols = df.select_dtypes(include='object').columns
    for col in str_cols:
        df[col] = df[col].astype(str).str.strip()
    log.info("✅ Step 1: Whitespace stripped")

    # ── STEP 2: Date validation ────────────────────────────────────────────────
    df['date'] = pd.to_datetime(df['date'], errors='coerce')
    bad_dates  = df['date'].isnull().sum()
    if bad_dates:
        log.warning(f"⚠️  Step 2: {bad_dates} unparseable dates — rows dropped")
        df = df.dropna(subset=['date'])
    df = df[(df['date'] >= DATE_START) & (df['date'] <= DATE_END)]
    log.info(f"✅ Step 2: Date range: {df['date'].min().date()} → {df['date'].max().date()}")

    # ── STEP 3: Standardize categoricals ──────────────────────────────────────
    df['category'] = df['category'].str.strip().str.title()
    df['shift']    = df['shift'].str.strip().str.title()
    invalid_cat    = df[~df['category'].isin(VALID_CATEGORIES)]
    if len(invalid_cat):
        log.warning(f"⚠️  Step 3: {len(invalid_cat)} unrecognised category values")
    log.info("✅ Step 3: Categoricals standardized")

    # ── STEP 4: Cast and validate numeric columns ──────────────────────────────
    num_cols = ['planned_qty','actual_qty','wastage_qty',
                'net_produced_qty','raw_milk_used_L',
                'production_efficiency_%','wastage_rate_%']
    for col in num_cols:
        df[col] = pd.to_numeric(df[col], errors='coerce')

    # Drop rows where core production quantities are null
    df = df.dropna(subset=['planned_qty','actual_qty'])

    # No negatives allowed in production quantities
    for col in ['planned_qty','actual_qty','wastage_qty','net_produced_qty']:
        neg = (df[col] < 0).sum()
        if neg:
            log.warning(f"⚠️  Step 4: {neg} negative values in '{col}' — set to 0")
            df[col] = df[col].clip(lower=0)
    log.info("✅ Step 4: Numerics validated")

    # ── STEP 5: Business rule validations ─────────────────────────────────────
    # Rule 1: actual_qty must not exceed 110% of planned (impossible overproduction)
    over_prod = df[df['actual_qty'] > df['planned_qty'] * 1.10]
    if len(over_prod):
        log.warning(f"⚠️  Step 5: {len(over_prod)} rows with actual > 110% of planned")

    # Rule 2: wastage cannot exceed actual production
    bad_wastage = df[df['wastage_qty'] > df['actual_qty']]
    if len(bad_wastage):
        log.warning(f"⚠️  Step 5: {len(bad_wastage)} rows where wastage > actual — fixing")
        df.loc[df['wastage_qty'] > df['actual_qty'], 'wastage_qty'] = 0

    # Rule 3: net_produced = actual - wastage
    df['net_produced_qty'] = df['actual_qty'] - df['wastage_qty']

    # Rule 4: efficiency must be between 0–110%
    df['production_efficiency_%'] = (
        df['actual_qty'] / df['planned_qty'].replace(0, np.nan) * 100
    ).round(2)

    # Rule 5: wastage rate
    df['wastage_rate_%'] = (
        df['wastage_qty'] / df['actual_qty'].replace(0, np.nan) * 100
    ).round(2)

    log.info("✅ Step 5: Business rules applied — efficiency & wastage recalculated")

    # ── STEP 6: Remove duplicates ──────────────────────────────────────────────
    dups = df.duplicated(subset=['production_id']).sum()
    if dups:
        log.warning(f"⚠️  Step 6: {dups} duplicate production_ids removed")
        df = df.drop_duplicates(subset=['production_id'])
    log.info("✅ Step 6: Duplicates removed")

    # ── STEP 7: Derived columns ────────────────────────────────────────────────
    df['day_of_week']    = df['date'].dt.day_name()
    df['financial_year'] = df['date'].apply(
        lambda d: f"FY{d.year}-{str(d.year+1)[-2:]}" if d.month >= 4
                  else f"FY{d.year-1}-{str(d.year)[-2:]}"
    )

    # Efficiency band — useful for Power BI conditional formatting
    df['efficiency_band'] = pd.cut(
        df['production_efficiency_%'],
        bins   = [0, 85, 90, 95, 100, 110],
        labels = ['Critical (<85%)','Poor (85-90%)','Fair (90-95%)',
                  'Good (95-100%)','Excellent (>100%)']
    )

    # Data quality flag
    df['data_quality_flag'] = 'OK'
    df.loc[df['production_efficiency_%'] > 110, 'data_quality_flag'] = 'OVER_PRODUCTION'
    df.loc[df['wastage_rate_%'] > 10,            'data_quality_flag'] = 'HIGH_WASTAGE'

    log.info("✅ Step 7: Derived columns added (efficiency_band, financial_year)")

    # ── FINAL SUMMARY ─────────────────────────────────────────────────────────
    dropped = original_rows - len(df)
    log.info(f"\n{'─'*50}")
    log.info("CLEAN PRODUCTION SUMMARY")
    log.info(f"  Input rows          : {original_rows:>8,}")
    log.info(f"  Rows dropped        : {dropped:>8,}")
    log.info(f"  Output rows         : {len(df):>8,}")
    log.info(f"  Avg efficiency      : {df['production_efficiency_%'].mean():.2f}%")
    log.info(f"  Avg wastage rate    : {df['wastage_rate_%'].mean():.2f}%")
    log.info(f"  Total raw milk used : {df['raw_milk_used_L'].sum():,.0f} L")
    log.info(f"{'─'*50}")

    return df


def main():
    log.info("═"*60)
    log.info("MSRB DAIRY — PRODUCTION CLEANING PIPELINE")
    log.info(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log.info("═"*60)

    input_path  = os.path.join(RAW_DIR,     'fact_production.csv')
    output_path = os.path.join(CLEANED_DIR, 'fact_production_cleaned.csv')

    df_raw     = pd.read_csv(input_path)
    df_cleaned = clean_production(df_raw)

    df_cleaned.to_csv(output_path, index=False)
    log.info(f"✅ Cleaned file saved → {output_path}")
    return df_cleaned


if __name__ == '__main__':
    main()
