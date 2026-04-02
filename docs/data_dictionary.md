# MSRB SONS DAIRY — Data Dictionary
**Author:** Pradeep Kumar | **Version:** 1.0 | **Date:** April 2025

---

## fact_sales

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| sale_id | VARCHAR | Unique transaction ID | SL000001 |
| date | DATE | Transaction date | 2023-04-01 |
| year | INT | Calendar year | 2023 |
| month | INT | Month number (1–12) | 4 |
| month_name | VARCHAR | Full month name | April |
| quarter | VARCHAR | Quarter label | Q2 |
| financial_year | VARCHAR | Indian FY (Apr–Mar) | FY2023-24 |
| customer_id | VARCHAR | Customer reference key | C045 |
| customer_name | VARCHAR | Customer full name | Priya Kumar |
| customer_type | VARCHAR | Business type | Retailer |
| route_id | VARCHAR | Delivery route key | R08 |
| route_name | VARCHAR | Route description | Bypass Road Route |
| product_id | VARCHAR | Product reference key | P06 |
| product_name | VARCHAR | Product full name | Curd 400g |
| category | VARCHAR | Product category | Curd |
| unit | VARCHAR | Unit of measurement | Piece |
| quantity | NUMERIC | Units sold | 26 |
| unit_price | NUMERIC | Selling price per unit (₹) | 37.02 |
| gross_amount | NUMERIC | quantity × unit_price (₹) | 962.52 |
| discount | NUMERIC | Discount applied (₹) | 0.00 |
| net_amount | NUMERIC | gross_amount − discount (₹) | 962.52 |
| payment_mode | VARCHAR | How customer paid | UPI |
| invoice_number | VARCHAR | Invoice reference | INV-000001 |
| day_of_week | VARCHAR | Day name (derived) | Saturday |
| is_weekend | BOOLEAN | Weekend flag (derived) | FALSE |
| revenue_band | VARCHAR | Net amount bucket (derived) | 500-2K |
| data_quality_flag | VARCHAR | ETL quality flag | OK |

---

## fact_production

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| production_id | VARCHAR | Unique production run ID | PR000001 |
| date | DATE | Production date | 2023-04-01 |
| category | VARCHAR | Product category produced | Milk Bulk |
| planned_qty | NUMERIC | Quantity planned (L or kg) | 880 |
| actual_qty | NUMERIC | Quantity actually produced | 836 |
| wastage_qty | NUMERIC | Quantity wasted/rejected | 14 |
| net_produced_qty | NUMERIC | actual_qty − wastage_qty | 822 |
| raw_milk_used_L | NUMERIC | Input raw milk in litres | 877.8 |
| production_efficiency_% | NUMERIC | actual/planned × 100 | 95.00 |
| wastage_rate_% | NUMERIC | wastage/actual × 100 | 1.67 |
| shift | VARCHAR | Production shift | Evening |
| batch_number | VARCHAR | Batch reference | BATCH-20230401-MIL |
| efficiency_band | VARCHAR | Efficiency category (derived) | Good (95-100%) |
| data_quality_flag | VARCHAR | ETL quality flag | OK |

---

## fact_inventory

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| inventory_id | VARCHAR | Unique inventory record ID | IN000001 |
| date | DATE | Stock date | 2023-04-01 |
| product_id | VARCHAR | Product key | P01 |
| product_name | VARCHAR | Product name | Milk Bulk 1L |
| category | VARCHAR | Product category | Milk Bulk |
| opening_stock | NUMERIC | Stock at start of day | 174 |
| received_qty | NUMERIC | Stock received/produced | 121 |
| dispatched_qty | NUMERIC | Stock dispatched/sold | 137 |
| closing_stock | NUMERIC | opening + received − dispatched | 158 |
| reorder_level | NUMERIC | Minimum safe stock level | 200 |
| stock_status | VARCHAR | OK / Low / Critical / Stockout | Low |
| shelf_life_days | INT | Product shelf life in days | 2 |
| days_of_stock | NUMERIC | Estimated days stock will last | 1.2 |
| shelf_life_risk | VARCHAR | Safe / At Risk | At Risk |

---

## fact_accounts

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| transaction_id | VARCHAR | Unique account transaction ID | AC000001 |
| invoice_date | DATE | Invoice raised date | 2023-04-30 |
| customer_id | VARCHAR | Customer reference key | C001 |
| customer_name | VARCHAR | Customer name | Rekha Jain |
| customer_type | VARCHAR | Business type | Retailer |
| invoice_number | VARCHAR | Invoice reference | MINV-00001 |
| due_date | DATE | Payment due date | 2023-05-15 |
| invoice_amount | NUMERIC | Total amount billed (₹) | 17210.94 |
| amount_paid | NUMERIC | Amount received (₹) | 17210.94 |
| outstanding_balance | NUMERIC | invoice_amount − amount_paid | 0.00 |
| payment_date | DATE | Date payment received (null if unpaid) | 2023-05-05 |
| days_to_payment | NUMERIC | Days from invoice to payment | 5 |
| payment_status | VARCHAR | Paid / Paid Late / Overdue | Paid |
| credit_days | INT | Agreed credit period in days | 15 |
| days_overdue | NUMERIC | Days past due date (0 if paid) | 0 |
| aging_bucket | VARCHAR | Overdue aging category | Not Overdue |
| collection_efficiency_% | NUMERIC | amount_paid/invoice_amount × 100 | 100.00 |

---

## Business Rules Applied During ETL

| Rule | Department | Description |
|------|-----------|-------------|
| gross = qty × price | Sales | Tolerance ±1% |
| net = gross − discount | Sales | Hard rule |
| discount ≤ 20% | Sales | Flag if exceeded |
| actual ≤ 110% of planned | Production | Flag over-production |
| wastage ≤ actual | Production | Auto-corrected to 0 if violated |
| closing = opening + received − dispatched | Inventory | Auto-corrected |
| dispatched ≤ opening + received | Inventory | Capped to available |
| outstanding = invoice − paid | Accounts | Auto-corrected |
| paid ≤ invoice amount | Accounts | Capped to invoice value |
