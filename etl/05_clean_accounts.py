"""
═══════════════════════════════════════════════════════════════════════════════
FILE        : 05_clean_accounts.py
PROJECT     : MSRB SONS DAIRY PRODUCT PVT. LTD. — Analytics Pipeline
LAYER       : 2 — Data Cleaning  |  Department: ACCOUNTS & FINANCE
AUTHOR      : Pradeep Kumar
DESCRIPTION : Cleans fact_accounts.csv — validates invoice balances,
              computes DSO, flags overdue accounts, derives aging buckets.
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
        logging.FileHandler(os.path.join(LOG_DIR, 'clean_accounts.log')),
        logging.StreamHandler()
    ]
)
log = logging.getLogger(__name__)

DATE_START = pd.Timestamp('2023-04-01')
DATE_END   = pd.Timestamp('2025-03-31')
ANALYSIS_DATE = pd.Timestamp('2025-03-31')   # "as of" date for aging


def clean_accounts(df: pd.DataFrame) -> pd.DataFrame:
    original_rows = len(df)
    log.info(f"Starting clean — {original_rows:,} rows loaded")
    df = df.copy()

    # ── STEP 1: Strip whitespace ───────────────────────────────────────────────
    str_cols = df.select_dtypes(include='object').columns
    for col in str_cols:
        df[col] = df[col].astype(str).str.strip()
    log.info("✅ Step 1: Whitespace stripped")

    # ── STEP 2: Parse all date columns ────────────────────────────────────────
    for dcol in ['invoice_date','due_date','payment_date']:
        df[dcol] = pd.to_datetime(df[dcol], errors='coerce')

    # Drop rows with no invoice date
    null_inv = df['invoice_date'].isnull().sum()
    if null_inv:
        log.warning(f"⚠️  Step 2: {null_inv} rows with null invoice_date — dropped")
        df = df.dropna(subset=['invoice_date'])

    # Payment date null is VALID for unpaid invoices — do NOT drop
    null_pay = df['payment_date'].isnull().sum()
    log.info(f"   payment_date nulls: {null_pay:,} (expected for unpaid invoices)")

    df = df[(df['invoice_date'] >= DATE_START) & (df['invoice_date'] <= DATE_END)]
    log.info(f"✅ Step 2: Dates parsed. Invoice range: {df['invoice_date'].min().date()} → {df['invoice_date'].max().date()}")

    # ── STEP 3: Cast numeric columns ──────────────────────────────────────────
    num_cols = ['invoice_amount','amount_paid','outstanding_balance','credit_days']
    for col in num_cols:
        df[col] = pd.to_numeric(df[col], errors='coerce')

    df = df.dropna(subset=['invoice_amount'])
    log.info("✅ Step 3: Numerics cast")

    # ── STEP 4: Business rule — invoice balance ────────────────────────────────
    # outstanding = invoice_amount - amount_paid
    df['calc_outstanding'] = (df['invoice_amount'] - df['amount_paid']).round(2)
    balance_errors         = df[abs(df['outstanding_balance'] - df['calc_outstanding']) > 1]
    if len(balance_errors):
        log.warning(f"⚠️  Step 4: {len(balance_errors)} balance mismatches — correcting")
        df['outstanding_balance'] = df['calc_outstanding'].clip(lower=0)

    # amount_paid cannot exceed invoice_amount
    overpaid = df[df['amount_paid'] > df['invoice_amount']]
    if len(overpaid):
        log.warning(f"⚠️  Step 4: {len(overpaid)} rows with amount_paid > invoice — capping")
        df['amount_paid']         = df['amount_paid'].clip(upper=df['invoice_amount'])
        df['outstanding_balance'] = (df['invoice_amount'] - df['amount_paid']).clip(lower=0)

    log.info("✅ Step 4: Invoice balance validated")

    # ── STEP 5: Remove duplicates ──────────────────────────────────────────────
    dups = df.duplicated(subset=['transaction_id']).sum()
    if dups:
        log.warning(f"⚠️  Step 5: {dups} duplicate transaction_ids removed")
        df = df.drop_duplicates(subset=['transaction_id'])
    log.info("✅ Step 5: Duplicates removed")

    # ── STEP 6: Recalculate payment_status ────────────────────────────────────
    def classify_payment(row):
        if row['outstanding_balance'] <= 0 and not pd.isnull(row['payment_date']):
            if row['payment_date'] <= row['due_date']:
                return 'Paid'
            else:
                return 'Paid Late'
        elif row['outstanding_balance'] > 0:
            return 'Overdue'
        else:
            return 'Paid'

    df['payment_status'] = df.apply(classify_payment, axis=1)
    log.info(f"✅ Step 6: Payment status recalculated")
    log.info(f"   Paid      : {(df['payment_status']=='Paid').sum():,}")
    log.info(f"   Paid Late : {(df['payment_status']=='Paid Late').sum():,}")
    log.info(f"   Overdue   : {(df['payment_status']=='Overdue').sum():,}")

    # ── STEP 7: Derived columns — Aging & DSO ────────────────────────────────
    df['financial_year'] = df['invoice_date'].apply(
        lambda d: f"FY{d.year}-{str(d.year+1)[-2:]}" if d.month >= 4
                  else f"FY{d.year-1}-{str(d.year)[-2:]}"
    )

    # Days overdue as of analysis date (for overdue invoices)
    df['days_overdue'] = np.where(
        df['payment_status'] == 'Overdue',
        (ANALYSIS_DATE - df['due_date']).dt.days.clip(lower=0),
        0
    )

    # Aging bucket — standard 30-day buckets
    def aging_bucket(row):
        if row['payment_status'] != 'Overdue':
            return 'Not Overdue'
        days = row['days_overdue']
        if days <= 30:
            return '1-30 Days'
        elif days <= 60:
            return '31-60 Days'
        elif days <= 90:
            return '61-90 Days'
        else:
            return '90+ Days'

    df['aging_bucket'] = df.apply(aging_bucket, axis=1)

    # Collection efficiency per invoice
    df['collection_efficiency_%'] = (
        df['amount_paid'] / df['invoice_amount'].replace(0, np.nan) * 100
    ).round(2).clip(0, 100)

    # Days to payment (only for paid invoices)
    df['days_to_payment'] = np.where(
        df['payment_date'].notnull(),
        (df['payment_date'] - df['invoice_date']).dt.days,
        np.nan
    )

    log.info("✅ Step 7: Derived columns added (aging_bucket, days_overdue, collection_efficiency)")

    # ── DROP HELPER COLUMN ─────────────────────────────────────────────────────
    df = df.drop(columns=['calc_outstanding'], errors='ignore')

    # ── FINAL SUMMARY ─────────────────────────────────────────────────────────
    dropped = original_rows - len(df)
    total_billed      = df['invoice_amount'].sum()
    total_collected   = df['amount_paid'].sum()
    total_outstanding = df['outstanding_balance'].sum()
    coll_eff          = total_collected / total_billed * 100 if total_billed else 0

    log.info(f"\n{'─'*50}")
    log.info("CLEAN ACCOUNTS SUMMARY")
    log.info(f"  Input rows           : {original_rows:>8,}")
    log.info(f"  Output rows          : {len(df):>8,}")
    log.info(f"  Total Billed         : ₹{total_billed:>14,.2f}")
    log.info(f"  Total Collected      : ₹{total_collected:>14,.2f}")
    log.info(f"  Total Outstanding    : ₹{total_outstanding:>14,.2f}")
    log.info(f"  Collection Efficiency: {coll_eff:>7.2f}%")
    log.info(f"  Overdue invoices     : {(df['payment_status']=='Overdue').sum():>8,}")
    log.info(f"  90+ day overdue      : {(df['aging_bucket']=='90+ Days').sum():>8,}")
    log.info(f"{'─'*50}")

    return df


def main():
    log.info("═"*60)
    log.info("MSRB DAIRY — ACCOUNTS CLEANING PIPELINE")
    log.info(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log.info("═"*60)

    input_path  = os.path.join(RAW_DIR,     'fact_accounts.csv')
    output_path = os.path.join(CLEANED_DIR, 'fact_accounts_cleaned.csv')

    df_raw     = pd.read_csv(input_path)
    df_cleaned = clean_accounts(df_raw)

    df_cleaned.to_csv(output_path, index=False)
    log.info(f"✅ Cleaned file saved → {output_path}")
    return df_cleaned


if __name__ == '__main__':
    main()
