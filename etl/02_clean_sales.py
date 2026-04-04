"""
═══════════════════════════════════════════════════════════════════════════════
FILE        : 02_clean_sales.py
PROJECT     : MSRBSONS DAIRY PRODUCT PVT. LTD. — Analytics Pipeline
LAYER       : 2 — Data Cleaning  |  Department: SALES
AUTHOR      : Pradeep Kumar
DESCRIPTION : Cleans fact_sales.csv — standardizes formats, validates business
              rules, flags anomalies, and exports to data/cleaned/
═══════════════════════════════════════════════════════════════════════════════

RAW DATA                    CLEANED DATA
fact_sales.csv    →     fact_sales_cleaned.csv
(messy, untrusted)          (validated, business-ready)
If bad data goes into our database → bad decisions.
"""

import os
import pandas as pd
import numpy as np
import logging
from datetime import datetime

# ── PATHS ─────────────────────────────────────────────────────────────────────
BASE_DIR    = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) #make the code portable
RAW_DIR     = os.path.join(BASE_DIR, 'data', 'raw')
CLEANED_DIR = os.path.join(BASE_DIR, 'data', 'cleaned')
LOG_DIR     = os.path.join(BASE_DIR, 'logs')
os.makedirs(CLEANED_DIR, exist_ok=True)
os.makedirs(LOG_DIR,     exist_ok=True)

log = logging.getLogger('clean_sales')
log.setLevel(logging.INFO)
log.handlers.clear()
# File handler — timestamped
fh = logging.FileHandler(
    os.path.join(LOG_DIR, f'clean_sales_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'),
    encoding='utf-8'                     # fixes the garbled characters (🔴→?)
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
# ── VALID REFERENCE VALUES just like LOOKUP Tables────────────────────────────────────────────────────
VALID_CATEGORIES     = {'Milk Bulk','Milk Packet','Paneer','Curd','Ghee','Butter','Cream'}
VALID_PAYMENT_MODES  = {'Cash','Credit','UPI','Cheque'}
VALID_CUSTOMER_TYPES = {'Retailer','Wholesaler','Hotel/Restaurant','Institutional','Direct Consumer'}
VALID_ROUTE_NAME     = {'Bypass Road Route','Model Town Route','Sector-7 Route','Railway Colony Route',
                        'Civil Lines Route','Old City Route','Sadar Bazar Route','Industrial Area Route'}
DATE_START           = pd.Timestamp('2023-04-01')
DATE_END             = pd.Timestamp('2025-03-31')


def clean_sales(df: pd.DataFrame) -> pd.DataFrame:
    original_rows = len(df)
    log.info(f"Starting clean — {original_rows:,} rows loaded")
    df = df.copy()

    # ── STEP 1: Strip whitespace from all string columns ──────────────────────
    str_cols = df.select_dtypes(include='object').columns
    for col in str_cols:
        df[col] = df[col].str.strip()#finds all text columns.str.strip() → removes leading/trailing spaces
    log.info("✅ Step 1: Whitespace stripped from all string columns")

    # ── STEP 2: Parse and validate date column ────────────────────────────────
    df['date'] = pd.to_datetime(df['date'], errors='coerce')#Without errors='coerce' → the entire script would crash on the first bad date.
    bad_dates  = df['date'].isnull().sum()
    if bad_dates:
        log.warning(f"⚠️  Step 2: {bad_dates} unparseable dates — rows dropped")
        df = df.dropna(subset=['date'])
    out_of_range = df[(df['date'] < DATE_START) | (df['date'] > DATE_END)]
    if len(out_of_range):
        log.warning(f"⚠️  Step 2: {len(out_of_range)} rows outside date range — dropped")
        log.warning(f" Dropped Date range:{out_of_range['date'].min().date()}->{out_of_range['date'].max().date()}")
        log.warning(f" Check if DATE_END Needs updating")
        df = df[(df['date'] >= DATE_START) & (df['date'] <= DATE_END)]
    log.info(f"✅ Step 2: Dates validated. Range: {df['date'].min().date()} → {df['date'].max().date()}")

    # ── STEP 3: Standardize categorical columns ───────────────────────────────
    df['category']      = df['category'].str.strip().str.title()
    df['payment_mode']  = df['payment_mode'].str.strip()
    df['customer_type'] = df['customer_type'].str.strip().str.title()
    df['route_name']    = df['route_name'].str.strip().str.title()
    df['product_name']  = df['product_name'].str.strip()
    df['customer_name'] = df['customer_name'].str.strip()
    invalid_cat  = df[~df['category'].isin(VALID_CATEGORIES)]
    invalid_pay  = df[~df['payment_mode'].isin(VALID_PAYMENT_MODES)]
    invalid_cust = df[~df['customer_type'].isin(VALID_CUSTOMER_TYPES)]
    invalid_route = df[~df['route_name'].isin(VALID_ROUTE_NAME)]

    if len(invalid_cat):
        log.warning(f"⚠️  Step 3: {len(invalid_cat)} invalid category values — flagged")
        df.loc[~df['category'].isin(VALID_CATEGORIES), 'data_quality_flag'] = 'INVALID_CATEGORY'
    if len(invalid_pay):
        log.warning(f"⚠️  Step 3: {len(invalid_pay)} invalid payment modes — flagged")
    if len(invalid_cust):
        log.warning(f"⚠️  Step 3: {len(invalid_cust)} invalid customer types — flagged")
    if len(invalid_route):
        log.warning(f"⚠️  Step 3: {len(invalid_route)} invalid route values — flagged")
    log.info("✅ Step 3: Categorical columns standardized")

    # ── STEP 4: Validate and cast numeric columns ─────────────────────────────
    num_cols = ['quantity','unit_price','gross_amount','discount','net_amount']
    for col in num_cols:
        df[col] = pd.to_numeric(df[col], errors='coerce')

    nulls_after = df[num_cols].isnull().sum()
    if nulls_after.sum() > 0:
        log.warning(f"⚠️  Step 4: Non-numeric values coerced to NaN:\n{nulls_after[nulls_after>0]}")
        df = df.dropna(subset=['quantity','unit_price','net_amount'])# drops the rows based on only those cols when the customer does not 
                                                                     #buy then quantity is empty so and so not all rows having nulls other than these columns.

    # Negative values check
    for col in num_cols:
        neg = (df[col] < 0).sum()
        if neg:
            log.warning(f"⚠️  Step 4: {neg} negative values in '{col}' — flagged")
            if 'data_quality_flag' not in df.columns:
                df['data_quality_flag'] = 'OK'
            df.loc[df[col] < 0, 'data_quality_flag'] = f'NEGATIVE_{col.upper()}'
    log.info("✅ Step 4: Numeric columns validated")

    # ── STEP 5: Business rule validations ─────────────────────────────────────
    # Rule 1: gross_amount = quantity × unit_price (allow 1% tolerance)
    #if someone sold 100 pckets and price of each packet is 54 then gross will be 5400.
    # But they type ₹5,000 in the gross column. That ₹400 difference is either a discount not recorded or a data entry error. 
    # This rule catches it.

    df['calc_gross']    = (df['quantity'] * df['unit_price']).round(2)
    df['gross_diff']    = abs(df['gross_amount'] - df['calc_gross'])
    df['gross_pct_err'] = df['gross_diff'] / df['calc_gross'].replace(0, np.nan) #Prevents division by zero. If calc_gross is 0 (someone sold 0 units?), we skip that row instead of crashing.
    gross_errors        = df[df['gross_pct_err'] > 0.01]
    if len(gross_errors):
        log.warning(f"⚠️  Step 5: {len(gross_errors)} rows where gross ≠ qty×price (>1% tolerance)")

    # Rule 2: net_amount = gross_amount - discount
    df['calc_net'] = (df['gross_amount'] - df['discount']).round(2)
    net_errors     = df[abs(df['net_amount'] - df['calc_net']) > 1]
    if len(net_errors):
        log.warning(f"⚠️  Step 5: {len(net_errors)} rows where net ≠ gross - discount")

    # Rule 3: discount must not exceed 20% of gross
    df['discount_pct'] = (df['discount'] / df['gross_amount'].replace(0, np.nan) * 100).round(2)
    high_discount      = df[df['discount_pct'] > 20] #if a salesman gives more than 20% discount he is either giving it away at a loss 
                                                     #or creating a fake invoice. This flag goes to the manager to review.
    if len(high_discount):
        log.warning(f"⚠️  Step 5: {len(high_discount)} rows with discount > 20%")
    log.info("✅ Step 5: Business rules validated")
    #Rule 4: net_amount must be > 0
    zero_net=df[df['net_amount']<=0]
    if len(zero_net):
        log.warning(f"⚠️  Step 5: {len(zero_net)} rows with net_amount ≤ 0 — flagged")
        df.loc[df['net_amount']<=0,'data_quality_flag']='ZERO_OR_NEGATIVE_NET'

    # ── STEP 6: Remove exact duplicates ───────────────────────────────────────
    dups = df.duplicated(subset=['sale_id'],keep='first')
    if dups.sum()>0:
        log.warning(f"⚠️  Step 6: {dups.sum()} duplicate sale_ids keeping first occurence")
        df = df.drop_duplicates(subset=['sale_id'])
    log.info("✅ Step 6: Duplicates removed")

    # ── STEP 7: Add derived columns ───────────────────────────────────────────
    df['day_of_week']      = df['date'].dt.day_name()
    df['is_weekend']       = df['date'].dt.weekday >= 5
    df['financial_year']   = df['date'].apply(
        lambda d: f"FY{d.year}-{str(d.year+1)[-2:]}" if d.month >= 4
                  else f"FY{d.year-1}-{str(d.year)[-2:]}"
        
        # date=2023-04-01  → month=4 ≥ 4  → FY2023-24  
        # date=2024-01-15  → month=1 < 4  → FY2023-24  
        # date=2024-05-20  → month=5 ≥ 4  → FY2024-25  
        # date=2025-01-10  → month=1 < 4  → FY2024-25  
    )
    df['revenue_band']     = pd.cut(df['net_amount'],
        bins   = [0, 500, 2000, 5000, 10000, float('inf')],
        labels = ['<500','500-2K','2K-5K','5K-10K','10K+']
    )
    log.info("✅ Step 7: Derived columns added (day_of_week, financial_year, revenue_band)")

    # ── STEP 8: Drop helper columns before saving ─────────────────────────────
    df = df.drop(columns=['calc_gross','calc_net','gross_diff',
                           'gross_pct_err','discount_pct'], errors='ignore')

    # ── FINAL SUMMARY ─────────────────────────────────────────────────────────
    dropped = original_rows - len(df)
    log.info(f"\n{'─'*50}")
    log.info(f"CLEAN SALES SUMMARY")
    log.info(f"  Input rows       : {original_rows:>8,}")
    log.info(f"  Rows dropped     : {dropped:>8,}")
    log.info(f"  Output rows      : {len(df):>8,}")
    log.info(f"  Columns          : {df.shape[1]}")
    log.info(f"  Date range       : {df['date'].min().date()} → {df['date'].max().date()}")
    log.info(f"  Total net revenue: ₹{df['net_amount'].sum():>15,.2f}")
    log.info(f"  Unique customers : {df['customer_id'].nunique()}")
    log.info(f"  Unique products  : {df['product_id'].nunique()}")
    log.info(f"{'─'*50}")

    return df


def main():
    log.info("═"*60)
    log.info("MSRB DAIRY — SALES CLEANING PIPELINE")
    log.info(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log.info("═"*60)

    input_path  = os.path.join(RAW_DIR,     'fact_sales.csv')
    output_path = os.path.join(CLEANED_DIR, 'fact_sales_cleaned.csv')

    df_raw     = pd.read_csv(input_path, low_memory=False)
    df_cleaned = clean_sales(df_raw)

    df_cleaned.to_csv(output_path, index=False)
    log.info(f"✅ Cleaned file saved → {output_path}")
    log.info(f"Finished: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    return df_cleaned


if __name__ == '__main__':
    main()
