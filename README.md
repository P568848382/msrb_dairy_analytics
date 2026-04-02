# MSRB SONS DAIRY — End-to-End Business Analytics Project

**Prepared by:** Pradeep Kumar  
**Company:** MSRB SONS DAIRY PRODUCT PVT. LTD., Rohtak, Haryana  
**Analysis Period:** April 2023 – March 2025 (2 Financial Years)  
**Dataset:** 120 Customers · 12 Products · 8 Delivery Routes · 69,242 Total Records

---

## Business Context

MSRB SONS DAIRY is a mid-size dairy manufacturer and distributor operating in
Rohtak, Haryana. The company produces and sells Milk, Paneer, Curd, Ghee,
Butter, and Cream across 8 delivery routes serving 120+ customers including
Retailers, Wholesalers, Hotels, and Institutional buyers.

This project builds a complete, production-level analytics system from raw
transactional records — simulating exactly how a real organization implements
data-driven decision making across Sales, Production, Inventory, and Finance.

---

## Project Architecture

```
RAW DATA (Excel / Tally Exports / Paper Registers)
         ↓
[LAYER 1]  Ingestion       → 01_ingest.py
[LAYER 2]  Cleaning        → 02–05_clean_*.py
[LAYER 3]  Data Warehouse  → PostgreSQL Star Schema
[LAYER 4]  KPI Queries     → SQL (7 Sales + 5 Prod + 4 Inv + 5 Acc KPIs)
[LAYER 5]  Semantic Model  → Tabular Model (DAX — 35+ measures)
[LAYER 6]  Dashboards      → 4 Interactive Reports
[LAYER 7]  Insights        → Executive Summary + Recommendations
```

---

## Dataset Summary

| Table | Rows | Description |
|-------|------|-------------|
| fact_sales | 54,469 | All product sales transactions |
| fact_production | 4,382 | Daily production runs by category |
| fact_inventory | 7,512 | Daily stock levels per product |
| fact_accounts | 2,879 | Monthly invoice & payment records |
| **Total** | **69,242** | April 2023 → March 2025 |

---

## Key Business Findings

### Sales & Revenue
- **Total Net Revenue: ₹4.2 Cr+** across 2 financial years
- **Top Category:** Milk Bulk + Milk Packets drive 45%+ of revenue
- **Top Route:** Civil Lines Route generates highest revenue per customer
- **Peak Month:** November–December consistently 15–20% above average (festive season)
- **Payment Mode:** 35% Cash, 35% Credit, 20% UPI, 10% Cheque

### Production
- **Average Production Efficiency: 93.4%** — below 95% target
- **Average Wastage Rate: 2.1%** — within acceptable 3% threshold
- **Ghee and Butter** show highest raw milk yield efficiency
- **Evening shift** outperforms Morning shift by 1.8% avg efficiency

### Inventory
- **Milk Bulk and Milk Packets** have highest stockout frequency (short shelf life)
- **Critical stock events** most common in peak months (Nov–Jan)
- **Ghee and Butter** maintain healthiest stock levels (long shelf life)
- **Days of Stock** for perishables consistently under 2 days — requires daily replenishment

### Accounts & Finance
- **Overall Collection Efficiency: 86.4%**
- **Days Sales Outstanding (DSO): 14.2 days** — within credit terms
- **Hotel/Restaurant segment** has the highest overdue rate (22% of invoices)
- **23% of customers account for 67% of outstanding receivables** — Pareto confirmed
- **90+ day overdue balance** requires immediate management intervention

---

## Critical Finding — Receivables Concentration Risk

> **Top 15 customers hold 61% of total outstanding receivables.**

Of 120 customers, 18 have been overdue for 90+ days. The Hotel/Restaurant
segment is the highest-risk segment for collection. Without intervention,
these accounts risk becoming bad debts.

---

## Top 5 Business Recommendations

### 1. Fix Production Efficiency in Low-Performing Shifts
**Gap:** Morning shift efficiency is 91.6% vs 95% target
**Action:** Audit morning shift process — raw material preparation, equipment warmup, staffing
**Impact:** Closing the gap to 95% recovers approximately 3.4% more production volume

### 2. Implement 48-Hour Reorder Trigger for Perishables
**Problem:** Milk Bulk stockout rate of 8.3% causes lost sales
**Action:** Set automated reorder alerts when closing stock < 2 days of average dispatch
**Impact:** Estimated 6–8% reduction in stockout-related lost revenue

### 3. Launch Overdue Recovery Campaign for Hotel/Restaurant Segment
**At Risk:** Hotel/Restaurant segment — 22% overdue rate, highest across all types
**Action:** Dedicated collections follow-up, reduce credit days from 15 to 7 for repeat offenders
**Impact:** Recovering 50% of overdue amount = ₹12–15L additional cash flow

### 4. Concentrate Sales Effort on Top 3 Routes
**Finding:** Top 3 routes generate 58% of revenue with 45% of customers
**Action:** Increase delivery frequency, offer loyalty pricing on top routes
**Impact:** 10% uplift on top routes = ₹20L+ incremental revenue

### 5. Introduce Seasonal Production Planning
**Finding:** November–December demand is 18% above monthly average
**Problem:** Production is not adjusted ahead of peak months
**Action:** Increase planned production by 15–20% in October for peak-season buffer
**Impact:** Reduces November stockouts and improves customer satisfaction

---

## Repository Structure

```
msrb-dairy-analytics/
├── data/
│   ├── raw/              ← Source CSV files
│   └── cleaned/          ← Post-ETL validated files
├── etl/
│   ├── 01_ingest.py      ← Structural validation + logging
│   ├── 02_clean_sales.py ← Sales data cleaning
│   ├── 03_clean_production.py
│   ├── 04_clean_inventory.py
│   ├── 05_clean_accounts.py
│   └── 06_load_to_postgres.py ← Star schema load
├── sql/
│   ├── schema_create.sql      ← Full star schema DDL
│   ├── kpi_sales.sql          ← 7 Sales KPI queries
│   └── kpi_production_inventory_accounts.sql
├── tabular_model/
│   └── README_dax_measures.md ← 35+ DAX measures
├── dashboards/
│   └── screenshots/           ← Power BI exports
└── docs/
    └── data_dictionary.md     ← All columns documented
```

---

## Technology Stack

| Layer | Tool |
|-------|------|
| Data Processing | Python 3.11 — Pandas, NumPy |
| Data Warehouse | PostgreSQL 15 — Star Schema |
| Semantic Layer | Tabular Model — DAX |
| Visualization | Power BI Desktop |
| Version Control | GitHub |

---

## How to Run This Project

```bash
# 1. Clone repository
git clone https://github.com/P568848382/MSRB-Dairy-Analytics

# 2. Install dependencies
pip install pandas numpy sqlalchemy psycopg2-binary

# 3. Place raw CSV files in data/raw/

# 4. Run ETL pipeline in order
python etl/01_ingest.py
python etl/02_clean_sales.py
python etl/03_clean_production.py
python etl/04_clean_inventory.py
python etl/05_clean_accounts.py

# 5. Create PostgreSQL database and schema
# Run sql/schema_create.sql in pgAdmin

# 6. Load data
python etl/06_load_to_postgres.py

# 7. Connect Power BI Desktop to PostgreSQL
# Import tables → Build Tabular Model → Apply DAX measures
```

---

## Conclusion

This project demonstrates a complete, production-level analytics implementation
for a real manufacturing business. Starting from unstructured raw data across
multiple formats, the pipeline produces a clean, validated data warehouse with
executive-level insights across all four business functions.

The most critical finding is the receivables concentration risk — 15 customers
hold 61% of outstanding balance. Combined with the Hotel/Restaurant segment's
22% overdue rate, cash flow management is the single highest-priority action
item for the business.

---

*Built with Python, PostgreSQL, Tabular Model (DAX), and Power BI.*  
*Full pipeline, SQL queries, and DAX measures documented in this repository.*  
*GitHub: [https://github.com/P568848382](https://github.com/P568848382)*
