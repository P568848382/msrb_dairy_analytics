# MSRB SONS DAIRY — End-to-End Business Analytics Project

**Prepared by:** Pradeep Kumar  
**Company:** MSRBSONS DAIRY PRODUCT PVT. LTD., Rohtak, Haryana  
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
[LAYER 4]  KPI Queries     → SQL (7 Sales + 5 Prod + 5 Inv + 5 Acc KPIs)
[LAYER 5]  Semantic Model  → Tabular Model (DAX — 35+ measures)
[LAYER 6]  Tableau Views   → 15 PostgreSQL Views + CSV Export Pipeline
[LAYER 7]  Dashboards      → 5 Tableau Dashboards (Executive, Sales, & Production Complete)
[LAYER 8]  Insights        → [Executive Report](docs/executive_performance_report.md) · [Sales Report](docs/sales_performance_report.md) · [Production Report](docs/production_operation_report.md)
```

---

## 🔥 Featured Dashboard: Executive Overview

![MSRB Executive Dashboard](dashboards/screenshots/Executive%20Dashboard.png)

> **Live Dashboard Link:** [View on Tableau Public](https://public.tableau.com/views/msrbsexecutivedashboard/Dashboard1?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

---

## 🔥 Featured Dashboard: Sales Performance

![MSRB Sales Performance Dashboard](dashboards/screenshots/Sales%20Performance.png)

> **Live Dashboard Link:** [View on Tableau Public](https://public.tableau.com/shared/NBH9N4P4F?:display_count=n&:origin=viz_share_link)

---

## 🔥 Featured Dashboard: Production & Operations

![MSRB Production Dashboard](dashboards/screenshots/MSRB%20PRODUCTION%20AND%20OPERATIONS%20DASHBOARD.png)

> **Live Dashboard Link:** [View on Tableau Public](https://public.tableau.com/shared/NBH9N4P4F?:display_count=n&:origin=viz_share_link)

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

### 📈 Executive Performance (FY 2023-25)
- **Total Net Revenue: ₹ 92M (9.2 Crore)** 
- **MoM Sales Growth:** **22.0%** average month-over-month growth.
- **Production Efficiency:** **93.54%** (Target: 95%).
- **Collection Efficiency:** **89.59%** (Target: 95%).
- **Stock Out Rate:** **0.35%** overall.

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

### 💳 Accounts & Finance (Critical Finding)
- **Overdue Crisis:** **83.5% (₹ 8M+)** of all outstanding receivables are in the **90+ Days** bucket.
- **Overall Collection Efficiency:** **89.59%**.
- **Days Sales Outstanding (DSO):** 14.2 days.
- **Risk:** High concentration of 90+ day overdue signifies a major liquidity risk.

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
msrb_dairy_analytics/
├── data/
│   ├── raw/              ← Source CSV files (Input)
│   ├── cleaned/          ← Post-ETL validated files
│   ├── sample/           ← Sample datasets for testing
│   └── tableau_export/   ← Final CSV exports for Tableau Public
├── docs/
│   ├── 02–06_*.md        ← Detailed ETL documentation for each step
│   ├── kpi_*.md          ← KPI logic and analysis documentation
│   ├── data_dictionary.md ← Comprehensive column documentation
│   └── tableau_dashboard_guide.md ← Step-by-step UI build guide
├── etl/
│   ├── 01_ingest.py      ← Structural validation + logging
│   ├── 02–05_clean_*.py  ← Modular cleaning scripts
│   ├── 06_load_to_postgres.py ← Star schema deployment
│   └── 07_export_for_tableau.py ← Automated CSV export pipeline
├── sql/
│   ├── schema_create.sql ← Full star schema DDL (Fact & Dim tables)
│   ├── kpi_*.sql         ← Departmental KPI queries (Sales, Prod, Inv, Acc)
│   └── tableau_views.sql ← 15 PostgreSQL views for Tableau optimization
├── tabular_model/
│   └── README_dax_measures.md ← 35+ Business measures (DAX)
├── dashboards/
│   └── screenshots/      ← Captures of final departmental dashboards
└── logs/                 ← Automated ETL execution logs (timestamped)
```

---

## Technology Stack

| Layer | Tool |
|-------|------|
| Data Processing | Python 3.11 — Pandas, NumPy |
| Data Warehouse | PostgreSQL 15 — Star Schema |
| Semantic Layer | Tabular Model — DAX |
| BI Views Layer | PostgreSQL Views (15 pre-computed) |
| Visualization | Tableau Desktop / Tableau Public |
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

# 7. Create Tableau views
# Run sql/tableau_views.sql in pgAdmin

# 8a. Tableau Desktop → Connect directly to PostgreSQL
# 8b. Tableau Public → Export CSVs first:
python etl/07_export_for_tableau.py

# 9. Follow docs/tableau_dashboard_guide.md to build all 5 dashboards
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

## Dashboard Design & Technical Decisions

### Why use PostgreSQL Views instead of Raw Tables?
"Each view pre-aggregates data to the grain Tableau actually needs. For example, `vw_shift_performance` reduces 4,382 production rows to 2 rows — one per shift. Tableau renders these instantly. If I connected `fact_production` directly for the shift comparison chart, Tableau would aggregate 4,382 rows live on every filter interaction. Views move computation to PostgreSQL where it is optimized, and Tableau only handles presentation. This is the same principle as a semantic layer in enterprise BI — the database does the math, the visualization tool does the display."

### Chart-Specific Design Logic

| Component | Design Decision | Business Rationale |
|-----------|-----------------|---------------------|
| **KPI Cards** | Calculated fields and conditional coloring. | Uses `SUM(actual)/SUM(planned)` for correct weighted efficiency. Visual cues (Green/Amber/Red) provide immediate status without manual calculation. |
| **Dual Axis Chart** | Independent scales (Efficiency vs Wastage). | Different metrics require different scales to remain visible. Highlights the inverse relationship: dips in efficiency often correlate with spikes in wastage. |
| **Bar Chart** | Horizontal layout with fixed X-axis (88-100%). | Horizontal labels are more readable for multi-word categories. Starting the axis at 88% highlights meaningful business variation (e.g., a 1.55% gap) that would be invisible on a 0-100% scale. |
| **Heatmap** | 2D color encoding (Category vs Year). | Simplifies 21 data points (7 categories × 3 years) into a single visual pattern. Instantly reveals that yield efficiency is stagnant year-over-year. |
| **Donut Chart** | Dual-axis with central total count. | Provides context by showing that percentages represent 4,382 runs. Reveals that while no catastrophic failures occur, performance is consistently capped below target. |
| **Shift Comparison** | Vertically stacked independent panels. | Allows accurate reading of metrics on incompatible scales (93% vs 2%). Highlights the volume superiority of the Evening shift (approx. 58,000 extra units). |
| **Area + Line** | Synchronized dual-axis (Input vs Output). | Both measures use the same unit (Litres). The visual gap between the area and line is proportional to conversion loss, making the yield concept intuitive. |

---

*Built with Python, PostgreSQL, Tabular Model (DAX), and Tableau.*  
*Full pipeline, SQL queries, Tableau views, and dashboard guide documented in this repository.*  
*GitHub: [https://github.com/P568848382](https://github.com/P568848382)*
