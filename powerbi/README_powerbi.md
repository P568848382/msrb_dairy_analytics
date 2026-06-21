# MSRB SONS DAIRY — Power BI Tabular Model & Dashboard Suite

**Built by:** Pradeep Kumar
**Tool:** Microsoft Power BI Desktop
**Data Source:** PostgreSQL (`msrb_dairy_dw`) — live import, 4 fact tables + 4 dimension tables
**Pages:** 5 interactive dashboards + 1 drill-through detail page
**DAX Measures:** 44 measures across 6 organised measure tables

---

## Why This Exists

This project already had a complete Tableau Public implementation (5 dashboards, 15 PostgreSQL views, full interactivity). This Power BI build is a **second, independent BI layer on the same data warehouse** — built to demonstrate Tabular modeling, DAX, and Power BI's native AI visuals (Key Influencers, Decomposition Tree, Smart Narrative, Anomaly Detection) that Tableau does not offer natively.

Same data. Same business questions. Two different BI engines, built end-to-end by one person.

---

## Data Model

```
                         ┌────────────┐
                         │  dim_date  │
                         │ (date_key) │
                         └─────┬──────┘
              ┌────────────────┼────────────────┬─────────────────┐
              │                │                │                 │
       ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐  ┌───────▼──────┐
       │ fact_sales  │  │fact_product. │  │fact_invent. │  │fact_accounts │
       └──────┬──────┘  └─────────────┘  └──────┬──────┘  └──────┬───────┘
              │                                  │                │
       ┌──────┴───────┐                   ┌──────┴──────┐  ┌──────┴──────┐
       │ dim_customer │◄──────────────────┤             │  │ dim_customer│
       │ dim_route    │                   │ dim_product │  │             │
       │ dim_product  │                   └─────────────┘  └─────────────┘
       └──────────────┘
```

**11 relationships total — 9 active, 2 intentionally inactive.**

`fact_accounts` has three date columns (`invoice_date`, `due_date`, `payment_date`). Only `invoice_date` is the active relationship to `dim_date`; the other two are kept inactive and activated selectively in DAX via `USERELATIONSHIP()` where needed (e.g. payment-date-based DSO variants).

All cross-filter directions are set to **Single** (dimension → fact) to prevent filter ambiguity across the 4-fact-table model.

---

## DAX Measures — 44 Total Across 6 Tables

Measures are organised into department-based tables — a pattern used in enterprise Tabular models so each analyst only needs to look in their own table.

| Measure Table | Count | Covers |
|---|---|---|
| `_Sales_Measures` | 12 | Revenue, invoices, discount %, credit sales, Ghee share |
| `_Production_Measures_` | 8 | Efficiency %, wastage %, raw milk usage, target gap |
| `_Inventory_Measures` | 3 | Closing stock, stockout days, current snapshot |
| `_Accounts_Measures` | 9 | Billed, collected, outstanding, overdue, collection % |
| `_Time_Intelligence_Measures` | 5 | YTD, SPLY, YoY%, MoM%, MTD |
| `_Rank_TopN_Iterator_Measures` | 7 | RANKX, TOPN, SUMX, AVERAGEX, MAXX |

Full DAX code for every measure is in [`dax_measures/`](dax_measures/).

### Sample — Why `SUM(actual)/SUM(planned)`, Not `AVERAGE(efficiency%)`

```dax
Production Efficiency % =
DIVIDE(
    SUM(fact_production[actual_qty]),
    SUM(fact_production[planned_qty]),
    0
)
```

Averaging a pre-calculated row-level efficiency column weights every production run equally regardless of size — a 10-unit run and a 1,000-unit run would distort the average identically. Recalculating from raw SUMs gives a volume-weighted efficiency, which is the only mathematically defensible aggregation here. The same principle is applied identically in the PostgreSQL SQL KPI layer for consistency across both BI tools.

### Sample — Context-Safe YoY% (Card + Matrix Compatible)

```dax
Revenue YOY% =
VAR CurrentPeriod = [Total Revenue]
VAR LastYear      = [Revenue SPLY]
VAR GrowthPct     = DIVIDE(CurrentPeriod - LastYear, LastYear, BLANK())
RETURN
    IF(
        ISBLANK(LastYear),
        BLANK(),
        IF(
            ISINSCOPE('dim_date'[month_number])
                || ISINSCOPE('dim_date'[financial_year])
                || HASONEVALUE('dim_date'[financial_year]),
            GrowthPct,
            BLANK()
        )
    )
```

`ISINSCOPE` alone handles matrix row/subtotal context correctly but returns `BLANK()` unconditionally on a card visual — cards have no row/column scope at all. Adding `HASONEVALUE` as an OR-condition makes the same measure work correctly in both a matrix (showing per-month and per-FY subtotals, hiding the meaningless grand-total sum-of-percentages) and a single KPI card filtered by a slicer.

### Sample — Avoiding Statistical Data Leakage in Key Influencers

While building the AI-powered Key Influencers visual on the Accounts & Finance page to explain `payment_status = OverDue`, the initial Explain-by field list included `aging_bucket`. This produced a misleading "100% match, 1 segment" result because `aging_bucket` is a column **computed from** `payment_status` during ETL — using it to explain the same field it was derived from is target leakage. It also caused Power BI's underlying logistic regression to fail to converge (perfect class separation), surfacing as "no influencers found" on the main tab. The field list was corrected to only genuinely independent predictors (`customer_type`, `credit_days`, `credit_limit`, `invoice_amount`, `month_name`) that exist before an invoice's payment outcome is known.

---

## Dashboard Pages

### 1. Executive Summary
One-page health check across all 4 departments. 5 KPI cards (Revenue, Collection Eff%, Production Eff%, Outstanding, Revenue YoY%) with conditional Green/Amber/Red coloring against business targets, FY-comparison trend line, category revenue donut, receivables aging bar, top-customer table, and a production efficiency gauge with a 95% target marker.

### 2. Sales Performance
4 KPI cards, a line-and-clustered-column combo chart (FY bars + YoY% on a true secondary axis), a **Field Parameter**-driven bar chart letting the user toggle the same chart between Revenue / Qty Sold / Unique Customers, route performance ranking, payment mode mix, and a Top-15 customer matrix with dynamic ranking via `RANKX`.

### 3. Customer Detail *(Drill-through target)*
Right-click any customer anywhere in the model → Drill through → lands here pre-filtered. Shows that customer's monthly trend, full invoice history with payment status, and a **Decomposition Tree** that auto-explains their revenue by Financial Year → Month → Route → Category → Customer Type.

### 4. Production & Operations
Introduces a **What-If Parameter** — a slider that lets the plant manager simulate any efficiency target between 88–100% and see, live, how many additional units (`Units Recovered if Target Met`) would be produced at that target. Combo chart (efficiency bars + wastage line), category efficiency ranking with fixed business-threshold conditional formatting (not a relative gradient — see note below), shift comparison, efficiency-band donut, and a planned-vs-actual scatter with a diagonal reference line.

> **Design note on conditional formatting:** Power BI's default "Color scale" conditional formatting stretches red→green across the *current data's own* min/max, which manufactures visual drama between values that are actually business-equivalent (e.g. 7 categories all sitting within the same 92–94% "Fair" band would render as a full red-to-green spread). This dashboard uses explicit **rule-based** formatting (`≥95% Green / ≥90% Amber / <90% Red`) tied to the actual business target instead.

### 5. Inventory & Supply Chain
5 KPI cards, a **Smart Narrative** AI visual that generates a live, filter-aware English summary, a current-stock highlight table with data bars and risk-status conditional formatting, stockout frequency ranking, a monthly turnover trend with **Anomaly Detection** enabled, a 100%-stacked shelf-life-risk bar, and a days-of-supply table.

> Anomaly Detection requires a single-series line (no Legend field) — a category-legended trend chart was kept separately for comparison, with a second un-legended overall trend line carrying the anomaly detection layer.

### 6. Accounts & Finance
6 KPI cards including DSO and On-Time Payment %, a billing-vs-collections combo chart, gradient-red aging bar, DSO trend with a 30-day reference line, collection efficiency by customer type, and the **Key Influencers** AI visual explaining what drives overdue payments (see leakage note above).

---

## Power BI Features Used (Beyond Standard Visuals)

| Feature | Page | Purpose |
|---|---|---|
| Field Parameters | Sales Performance | One chart, switchable measure (Revenue/Qty/Customers) |
| Drill-through | Customer Detail | Row-level customer investigation from any page |
| Decomposition Tree | Customer Detail | AI-assisted automatic revenue breakdown |
| What-If Parameter | Production & Operations | Interactive target simulation |
| Smart Narrative | Inventory & Supply Chain | Auto-generated, filter-aware text insight |
| Anomaly Detection | Inventory & Supply Chain | Statistical outlier flagging on turnover trend |
| Key Influencers | Accounts & Finance | AI-driven root-cause analysis on overdue payments |
| Dynamic measure-driven titles | Sales Performance | Chart title changes with active slicer selection |
| Sync Slicers | All pages | Financial Year filter persists across navigation |

---

## How to Open

```bash
# 1. Install Power BI Desktop (free, Windows only)
https://powerbi.microsoft.com/desktop/

# 2. Open MSRB_Dairy_Analytics.pbix

# 3. On first open, update the PostgreSQL connection:
File → Options and settings → Data source settings
Server: localhost | Database: msrb_dairy_dw
(Requires the PostgreSQL warehouse from /sql/schema_create.sql to be loaded locally —
 see the main repository README for the full ETL → PostgreSQL setup)
```

---

## Relationship to the Tableau Build

| | Tableau Public | Power BI |
|---|---|---|
| Data source | 15 PostgreSQL views (pre-aggregated) | Direct import of fact/dim tables, aggregation in DAX |
| Semantic layer | SQL views | DAX measures (Tabular model) |
| AI-assisted visuals | None | Key Influencers, Decomposition Tree, Smart Narrative, Anomaly Detection |
| Parameter-driven interactivity | Tableau Parameters | Field Parameters, What-If Parameters |
| Pages | 5 | 5 + 1 drill-through |

Both tools answer the same business questions from the same warehouse — included together to demonstrate cross-platform BI capability rather than tool lock-in.

---

*Part of the [MSRB SONS DAIRY Analytics Project](../README.md). Built with PostgreSQL, DAX, and Power BI Desktop.*
