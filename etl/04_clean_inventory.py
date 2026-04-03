"""
═══════════════════════════════════════════════════════════════════════════════
FILE        : 04_clean_inventory.py
PROJECT     : MSRB SONS DAIRY PRODUCT PVT. LTD. — Analytics Pipeline
LAYER       : 2 — Data Cleaning  |  Department: INVENTORY
AUTHOR      : Pradeep Kumar
DESCRIPTION : Cleans fact_inventory.csv — validates stock balance equation,
              flags stockout events, derives turnover-ready columns.
═══════════════════════════════════════════════════════════════════════════════
"""

import os
import pandas as pd
import logging
import numpy as np
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(BASE_DIR, 'data','raw')
CLEANED_DIR = os.path.join(BASE_DIR, 'data','cleaned')
LOG_DIR = os.path.join(BASE_DIR, 'logs')
os.makedirs(CLEANED_DIR,exist_ok=True)
os.makedirs(LOG_DIR,exist_ok=True)

log = logging.getLogger('clean_inventory')
log.setLevel(logging.INFO)
log.handlers.clear()

# File handler — timestamped
fh = logging.FileHandler(
    os.path.join(LOG_DIR, f'clean_inventory_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'),
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
DATE_START = pd.Timestamp('2023-04-01')
DATE_END = pd.Timestamp('2025-03-31')

SHELF_LIFE_DAYS = {
    'Milk Bulk':2,
    'Milk Packet':3,
    'Paneer':7,
    'Curd':5,
    'Ghee':180,
    'Butter':90,
    'Cream':10
}

def clean_inventory(df:pd.DataFrame):
    original_rows=len(df)
    log.info(f"Satrting cleaning - {original_rows:,} rows loaded")
    df=df.copy()

    # ── STEP 1: Strip whitespace ───────────────────────────────────────────────
    str_cols=df.select_dtypes(include='object').columns
    for col in str_cols:
        df[col]=df[col].str.strip()
    log.info("✅ Step 1: Whitespace stripped from all string columns")

    # ── STEP 2: Date validation ────────────────────────────────────────────────
    df['date']=pd.to_datetime(df['date'],errors='coerce')
    bad_dates=df['date'].isnull().sum()
    if bad_dates:
        log.warning(f"⚠️  Step 2: {bad_dates} unparseable dates — rows dropped")
        df=df.dropna(subset=['date'])
    out_of_range=df[(df['date']<DATE_START)|(df['date']>DATE_END)]
    if len(out_of_range):
        log.warning(f"⚠️  Step 2: {len(out_of_range)} rows outside date range — dropped")
        log.warning(f" Dropped Date range:{out_of_range['date'].min().date()}->{out_of_range['date'].max().date()}")
        log.warning(f" Check if DATE_END Needs updating")
    df=df[(df['date']>=DATE_START)&(df['date']<=DATE_END)]
    log.info(f"✅ Step 2: Dates validated. Range: {df['date'].min().date()} → {df['date'].max().date()}")

    # ── STEP 3: Cast numeric columns ──────────────────────────────────────────
    num_cols=[
        'opening_stock','received_qty','dispatched_qty','closing_stock','reorder_level'
    ]
    for col in num_cols:
        df[col]=pd.to_numeric(df[col],errors='coerce').fillna(0).clip(lower=0)
    log.info("✅ Step 3: Numeric columns cast and negative clipped")

    # ── STEP 4: Business rule — stock balance equation ────────────────────────
    # closing_stock = opening_stock + received_qty - dispatched_qty
    df['expected_closing_stock']=df['opening_stock']+df['received_qty']-df['dispatched_qty']
    df['balance_diff']=abs(df['closing_stock']-df['expected_closing_stock'])
    
    balance_errors = df[df['balance_diff']>1]
    if len(balance_errors):
        log.warning(f"⚠️  Step 4: {len(balance_errors)} rows where closing ≠ opening+received-dispatched")
        log.warning(" Correcting closing_stock from the equation...")
        df['closing_stock'] = df['expected_closing_stock'].clip(lower=0)

    log.info("✅ Step 4: Stock balance equation enforced")

    # ── STEP 5: Cannot dispatch more than available ────────────────────────────
    available = df['opening_stock']+df['received_qty']
    over_dispatch = df[df['dispatched_qty']>available]
    if len(over_dispatch):
        log.warning(f"⚠️  Step 5: {len(over_dispatch)} rows with dispatched > available stock capping")
        log.warning(" Correcting dispatched_qty from the equation...")
        df['dispatched_qty'] = df['dispatch_qty'].clip(upper=available)
        df['closing_stock'] = (df['opening_stock'] + df['received_qty'] - df['dispatched_qty']).clip(lower=0)
    log.info("✅ Step 5: Dispatched quantity capped by available stock")


    # ── STEP 6: Recalculate stock_status ──────────────────────────────────────
    def get_stock_status(row):
        reorder = row['reorder_level']
        closing = row['closing_stock']
        if closing == 0:
            return 'Stockout'
        elif closing <= reorder * 0.5:
            return 'Critical'
        elif closing < reorder :
            return 'Low'
        else:
            return 'OK'
    
    df['stock_status'] = df.apply(get_stock_status, axis=1)
    stockouts =  (df['stock_status']=='Stockout').sum()
    critical = (df['stock_status']=='Critical').sum()
    low = (df['stock_status']=='Low').sum()
    ok = (df['stock_status']=='OK').sum()
    log.info(f" ✅ Step 6: Stock status recalculated | Stockouts: {stockouts:,} | Critical: {critical:,} | Low: {low:,} | OK: {ok:,}")

    # ── STEP 7: Remove duplicates ──────────────────────────────────────────────
    dups = df.duplicated(subset=['inventory_id']).sum()
    if dups:
        log.warning(f"⚠️  Step 7: {dups} duplicate inventory_ids removed")
        df = df.drop_duplicates(subset=['inventory_id'])
    log.info("✅ Step 7: Duplicates removed")

    # ── STEP 8: Derived columns ────────────────────────────────────────────────
    df['financial_year'] = df['date'].apply(
        lambda x: f"FY{x.year}-{str(x.year+1)[2:]}" if x.month >= 4 
                  else f"FY{x.year-1}-{str(x.year)[2:]}"
        )
    df['day_of_week']=df['date'].dt.day_name()

    # Shelf life risk flag — how many days of stock do we have?
    df['shelf_life_days'] = df['category'].map(SHELF_LIFE_DAYS)
    df['days_of_stock'] = np.where(
        df['dispatched_qty']>0,
        (df['closing_stock']/(df['dispatched_qty']/1)).round(1),
        df['closing_stock']
    )
    df['shelf_life_risk']=np.where(
        df['days_of_stock']<=df['shelf_life_days'],
        'At Risk',
        'Safe'
    )

    # Drop helper columns
    df=df.drop(columns=['expected_closing_stock','balance_diff'],errors='ignore')
    log.info("✅ Step 8: Derived columns added (financial_year, day_of_week, days_of_stock, shelf_life_risk)")

    # ── FINAL SUMMARY ─────────────────────────────────────────────────────────
    dropped=original_rows-len(df)
    log.info(f"\n{'-'*50}")
    log.info("CLEAN INVENTORY SUMMARY")
    log.info(f"  Input rows         : {original_rows:>8,}")
    log.info(f"  Output rows        : {len(df):>8,}")
    log.info(f"  Rows dropped       : {dropped:>8,}")
    log.info(f"  Stockout events    : {(df['stock_status']=='Stockout').sum():>8,}")
    log.info(f"  Critical events    : {(df['stock_status']=='Critical').sum():>8,}")
    log.info(f"  Shelf life at risk : {(df['shelf_life_risk']=='At Risk').sum():>8,}")
    log.info(f"{'─'*50}")

    return df

def main():
    log.info("═"*60)
    log.info("MSRB DAIRY — INVENTORY CLEANING PIPELINE")
    log.info(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log.info("═"*60)

    input_path=os.path.join(RAW_DIR,'fact_inventory.csv')
    output_path=os.path.join(CLEANED_DIR,'fact_inventory_cleaned.csv')

    df_raw=pd.read_csv(input_path)
    df_cleaned=clean_inventory(df_raw)

    df_cleaned.to_csv(output_path,index=False)
    log.info(f"✅ Saved cleaned inventory to -> {output_path}")

    log.info("═"*60)
    log.info("MSRB DAIRY — INVENTORY CLEANING PIPELINE COMPLETED")
    log.info(f"Finished: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log.info("═"*60)

if __name__ == "__main__":
    main()


    


    

