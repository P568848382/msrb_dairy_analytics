# MSRB SONS DAIRY — Tableau Dashboard Build Guide

**Author:** Pradeep Kumar  
**Project:** MSRB SONS DAIRY PRODUCT PVT. LTD. — Business Analytics  
**Tool:** Tableau Desktop / Tableau Public  
**Data Source:** PostgreSQL `msrb_dairy_dw` or CSV Exports

---

## Table of Contents

1. [Pre-Requisites](#1-pre-requisites)
2. [Data Connection Setup](#2-data-connection-setup)
3. [Calculated Fields Reference](#3-calculated-fields-reference)
4. [Dashboard 1: Executive Summary](#4-dashboard-1-executive-summary)
5. [Dashboard 2: Sales & Revenue](#5-dashboard-2-sales--revenue)
6. [Dashboard 3: Production & Operations](#6-dashboard-3-production--operations)
7. [Dashboard 4: Inventory & Supply Chain](#7-dashboard-4-inventory--supply-chain)
8. [Dashboard 5: Accounts & Finance](#8-dashboard-5-accounts--finance)
9. [Formatting Standards](#9-formatting-standards)
10. [Navigation & Interactivity](#10-navigation--interactivity)

---

## 1. Pre-Requisites

### Option A: Tableau Desktop (PostgreSQL Live Connection)
1. Tableau Desktop installed (2022.x or later)
2. PostgreSQL 15 running with `msrb_dairy_dw` database populated
3. Run `sql/tableau_views.sql` in pgAdmin first — this creates 15 VIEWs

### Option B: Tableau Public (CSV Import)
1. Tableau Public installed (free)
2. Run `etl/07_export_for_tableau.py` — this exports 19 CSV files to `data/tableau_export/`
3. Import CSVs into Tableau Public

---

## 2. Data Connection Setup

### Tableau Desktop → PostgreSQL

1. Open Tableau Desktop
2. **Connect** → Under "To a Server" → **PostgreSQL**
3. Enter:
   - Server: `localhost`
   - Port: `5432`
   - Database: `msrb_dairy_dw`
   - Username: `postgres` (or your user)
   - Password: your password
4. Click **Sign In**

### Setting Up the Data Model

After connecting, you'll see the tables list. Set up **4 separate data sources**:

#### Data Source 1: Sales Analysis
```
Drag fact_sales to canvas
    Left Join → dim_date       ON fact_sales.date = dim_date.date_key
    Left Join → dim_product    ON fact_sales.product_id = dim_product.product_id
    Left Join → dim_route      ON fact_sales.route_id = dim_route.route_id
```

#### Data Source 2: Production Analysis
```
Drag fact_production to canvas
    Left Join → dim_date       ON fact_production.date = dim_date.date_key
```

#### Data Source 3: Inventory Analysis
```
Drag fact_inventory to canvas
    Left Join → dim_date       ON fact_inventory.date = dim_date.date_key
    Left Join → dim_product    ON fact_inventory.product_id = dim_product.product_id
```

#### Data Source 4: Accounts Analysis
```
Drag fact_accounts to canvas
    Left Join → dim_date       ON fact_accounts.invoice_date = dim_date.date_key
```

#### Data Source 5: Pre-computed Views (Standalone)
```
Add each view as a separate connection:
    vw_sales_monthly, vw_yoy_revenue, vw_customer_segments,
    vw_production_monthly, vw_category_efficiency, vw_production_yoy_yield,
    vw_shift_performance, vw_stockout_frequency, vw_monthly_turnover,
    vw_stock_supply_risk, vw_billing_collections, vw_receivables_aging,
    vw_customer_payment, vw_dso_monthly, vw_custtype_efficiency
```

### Tableau Public → CSV Files

1. Open Tableau Public
2. **Connect** → **Text File**
3. Navigate to `data/tableau_export/`
4. Import each CSV file as a separate data source

---

## 3. Calculated Fields Reference

Create these calculated fields in Tableau. Go to **Analysis → Create Calculated Field**.

### Sales Calculated Fields

| Field Name | Formula | Notes |
|-----------|---------|-------|
| Total Revenue | `SUM([Net Amount])` | Core metric |
| Total Gross Revenue | `SUM([Gross Amount])` | Before discounts |
| Total Discount | `SUM([Discount])` | Total discount given |
| Discount % | `SUM([Discount]) / SUM([Gross Amount]) * 100` | Discount rate |
| Avg Invoice Value | `SUM([Net Amount]) / COUNTD([Invoice Number])` | Per-invoice average |
| Unique Customers | `COUNTD([Customer Id])` | Distinct count |
| Revenue Share % | `SUM([Net Amount]) / TOTAL(SUM([Net Amount])) * 100` | Table Calculation |

### Production Calculated Fields

| Field Name | Formula | Notes |
|-----------|---------|-------|
| Efficiency % | `SUM([Actual Qty]) / SUM([Planned Qty]) * 100` | Core KPI |
| Wastage Rate % | `SUM([Wastage Qty]) / SUM([Actual Qty]) * 100` | Wastage tracking |
| Yield Efficiency % | `SUM([Net Produced Qty]) / SUM([Raw Milk Used L]) * 100` | Raw material yield |
| Efficiency vs Target | `(SUM([Actual Qty]) / SUM([Planned Qty]) * 100) - 95` | Gap from 95% target |
| Efficiency Status | `IF [Efficiency %] >= 95 THEN "✅ On Target" ELSEIF [Efficiency %] >= 90 THEN "⚠️ Below Target" ELSE "❌ Critical" END` | Traffic light |

### Inventory Calculated Fields

| Field Name | Formula | Notes |
|-----------|---------|-------|
| Stockout Days | `COUNTD(IF [Stock Status] = "Stockout" THEN [Date] END)` | Days at zero |
| Stockout Rate % | `[Stockout Days] / COUNTD([Date]) * 100` | Rate of stockouts |
| Avg Inventory | `(SUM([Opening Stock]) + SUM([Closing Stock])) / 2` | Average stock |
| Turnover Ratio | `SUM([Dispatched Qty]) / [Avg Inventory]` | Speed of movement |

### Accounts Calculated Fields

| Field Name | Formula | Notes |
|-----------|---------|-------|
| Collection Efficiency % | `SUM([Amount Paid]) / SUM([Invoice Amount]) * 100` | Cash collection rate |
| DSO Days | `(SUM([Outstanding Balance]) * 30) / SUM([Invoice Amount])` | Days Sales Outstanding |
| Overdue Amount | `SUM(IF [Payment Status] = "OverDue" THEN [Outstanding Balance] END)` | Total overdue |
| 90+ Day Overdue | `SUM(IF [Aging Bucket] = "90+ Days" THEN [Outstanding Balance] END)` | Critical aging |
| Collection Status | `IF [Collection Efficiency %] >= 90 THEN "✅ Healthy" ELSEIF [Collection Efficiency %] >= 80 THEN "⚠️ Watch" ELSE "❌ At Risk" END` | Traffic light |

---

## 4. Dashboard 1: Executive Summary

**Target Audience:** CEO, Board Members, Senior Leadership  
**Purpose:** One-page health check across all 4 business functions  
**Tableau Size:** Dashboard → Size → Fixed → **1920 × 1080**

### Step-by-Step Build

#### Step 1: Create KPI Cards (5 Sheets)

**Sheet: `KPI_Total_Revenue`**
1. Data Source: `vw_sales_monthly` or `fact_sales`
2. Drag `Net Amount` → Text → change to `SUM`
3. Format: Currency (₹), Font Size 36, Bold, Color White
4. Background: Dark card color (`#2d3748`)

**Sheet: `KPI_MoM_Growth`**
1. Data Source: `vw_sales_monthly`
2. Create calculated field: `Latest MoM % = LOOKUP([Mom Growth Pct], 0)` using the last row
3. Format: Percentage, Font Size 28, Color Green/Red conditional

**Sheet: `KPI_Prod_Efficiency`**
1. Data Source: `fact_production`
2. Use `Efficiency %` calculated field  
3. Format: Percentage, Font Size 28
4. Conditional color: Green ≥95%, Amber ≥90%, Red <90%

**Sheet: `KPI_Stockout_Rate`**
1. Data Source: `fact_inventory`
2. Use `Stockout Rate %` calculated field
3. Format: Percentage, Font Size 28, Red color

**Sheet: `KPI_Collection_Eff`**
1. Data Source: `fact_accounts`
2. Use `Collection Efficiency %` calculated field
3. Format: Percentage, Font Size 28

#### Step 2: Monthly Revenue Trend (Area Chart)

**Sheet: `Exec_Revenue_Trend`**
1. Data Source: `vw_sales_monthly`
2. Columns: `Month` (as dimension, discrete)
3. Rows: `Net Revenue` (SUM)
4. Color by: `Financial Year`
5. Mark Type: **Area**
6. Add reference line at average revenue
7. Dual axis: Add `Mom Growth Pct` as line on secondary axis

#### Step 3: Revenue by Category (Treemap)

**Sheet: `Exec_Category_Split`**
1. Data Source: `fact_sales`
2. Mark Type: **Treemap**
3. Drag `Category` → Color and Label
4. Drag `Net Amount` (SUM) → Size
5. Drag `Revenue Share %` → Label
6. Color Palette: Tableau 10 Medium

#### Step 4: Receivables Aging (Stacked Bar)

**Sheet: `Exec_Aging_Bars`**
1. Data Source: `vw_receivables_aging`
2. Columns: `Aging Bucket`
3. Rows: `Outstanding Amount` (SUM)
4. Sort by: `Sort Order` field
5. Color: Gradient Red (darkest = 90+ Days)

#### Step 5: Production vs Target (Bullet Chart)

**Sheet: `Exec_Efficiency_Bullet`**
1. Data Source: `vw_production_monthly`
2. Rows: `Financial Year`
3. Columns: `Efficiency Pct` (AVG)
4. Add Reference Line at 95 (Target)
5. Mark Type: Bar, width thin
6. Color: Conditional on above/below target

#### Step 6: Stock Status (Horizontal Bar)

**Sheet: `Exec_Stock_Status`**
1. Data Source: `fact_inventory` (filter to latest date)
2. Rows: `Stock Status`
3. Columns: `COUNTD([Product Id])`
4. Color by `Stock Status`: OK=Green, Low=Yellow, Critical=Orange, Stockout=Red
5. Sort descending by count

#### Step 7: Assemble Dashboard

1. **Dashboard** → New Dashboard → Fixed Size 1920 × 1080
2. Set background to `#1e2a3a` (dark navy)
3. Add Title: "MSRB SONS DAIRY — EXECUTIVE DASHBOARD" (Font: 20pt Trebuchet MS, White)
4. Arrange:
   - **Row 1 (top):** 5 KPI Cards evenly spaced (each in a horizontal container)
   - **Row 2 (middle):** Revenue Trend chart (full width)
   - **Row 3 (bottom-left):** Category Treemap | Aging Bars
   - **Row 3 (bottom-right):** Efficiency Bullet | Stock Status
5. Add Filters:
   - `Financial Year` → Apply to All Using This Data Source
   - `Month` → Apply to All Using This Data Source

---

## 5. Dashboard 2: Sales & Revenue

**Target Audience:** Sales Head, Route Managers  
**Data Sources:** `fact_sales`, `vw_sales_monthly`, `vw_yoy_revenue`, `vw_customer_segments`

### Sheets to Build (8 Total)

#### Sheet 1: `Sales_KPI_Cards`
Build 5 separate BAN sheets (same technique as Executive):
- Total Revenue, Total Invoices, Unique Customers, Avg Invoice Value, Discount %

#### Sheet 2: `Monthly_Revenue_Combo`
1. Columns: `Month` (discrete), Color/Detail: `Financial Year`
2. Rows: `Net Revenue` (SUM) — Bar
3. Dual Axis: `Mom Growth Pct` — Line with circle markers
4. Synchronize axes, adjust colors

#### Sheet 3: `Category_Treemap`
1. Mark: Treemap
2. Size: `SUM(Net Amount)`, Color: `Category`, Label: Category + Revenue Share %

#### Sheet 4: `YoY_Grouped_Bar`
1. Data Source: `vw_yoy_revenue`
2. Columns: `Month Name`
3. Rows: Measure Values (Revenue FY2023-24, Revenue FY2024-25)
4. Color by Measure Names
5. Side-by-side bars

#### Sheet 5: `Route_Performance_Bar`
1. Data Source: `fact_sales`
2. Rows: `Route Name` (sorted by revenue)
3. Columns: `SUM(Net Amount)`
4. Color gradient: Light to dark teal
5. Label: Revenue + Customer count

#### Sheet 6: `Payment_Mode_Donut`
1. Rows: `Payment Mode`
2. Columns: `SUM(Net Amount)`
3. Mark: Pie → convert to donut using dual axis with white circle
4. Label: Payment Mode + percentage

#### Sheet 7: `Top_20_Customers_Table`
1. Data Source: `vw_customer_segments` (filter Top 20 by revenue)
2. Rows: Customer Name
3. Columns: Total Revenue, Invoices, First Purchase, Last Purchase
4. Conditional formatting: highlight top 5 in gold

#### Sheet 8: `Customer_Segmentation_Bar`
1. Data Source: `vw_customer_segments`
2. Rows: `Customer Segment` (sorted by Segment Rank)
3. Columns: `COUNT(Customer Id)`
4. Second Columns: `SUM(Total Revenue)` — dual axis
5. Color each segment: Platinum=Gold, Gold=Amber, Silver=Gray, etc.

#### Assemble Dashboard
- Size: 1920 × 1080
- Background: `#1e2a3a`
- Top: 5 KPI cards
- Middle: Monthly Combo (full width)
- Bottom-Left: Category Treemap + Route Bar
- Bottom-Right: YoY Comparison + Payment Mode + Segmentation
- Filters: FY, Quarter, Category, Route, Customer Type, Payment Mode

---

## 6. Dashboard 3: Production & Operations

**Target Audience:** Plant Manager, Production Head  
**Data Sources:** `fact_production`, `vw_production_monthly`, `vw_category_efficiency`, `vw_production_yoy_yield`, `vw_shift_performance`

### Sheets to Build (7 Total)

#### Sheet 1: `Prod_KPI_Cards` (4 cards)
- Efficiency %, Wastage %, Total Raw Milk (L), Efficiency vs Target

#### Sheet 2: `Monthly_Efficiency_Line`
1. Data Source: `vw_production_monthly`
2. Columns: Year-Month continuous
3. Rows: `Efficiency Pct` — Line
4. Add Reference Line at 95% (dashed red)
5. Dual Axis: `Wastage Pct` — Area (light red)

#### Sheet 3: `Category_Efficiency_Bar`
1. Data Source: `vw_category_efficiency`
2. Rows: `Category`
3. Columns: `Efficiency Pct`
4. Color: Conditional (Green ≥95, Amber ≥90, Red <90)
5. Label: Efficiency % value

#### Sheet 4: `YoY_Yield_Heatmap`
1. Data Source: `vw_production_yoy_yield`
2. Rows: `Category`
3. Columns: Year labels (2023, 2024, 2025)
4. Mark: Square, Color: Yield % (green=high, red=low)
5. Label: Yield % value — creates a heatmap

#### Sheet 5: `Efficiency_Band_Donut`
1. Data Source: `fact_production`
2. Rows: `Efficiency Band`
3. Columns: `COUNT(*)` — Pie
4. Label: Band name + percentage

#### Sheet 6: `Shift_Comparison_Bar`
1. Data Source: `vw_shift_performance`
2. Rows: `Shift` (Morning, Evening)
3. Columns: `Avg Efficiency Pct` and `Avg Wastage Pct` side by side
4. Color: Morning=Blue, Evening=Purple

#### Sheet 7: `Milk_Utilization_Area`
1. Data Source: `vw_production_monthly`
2. Columns: Month
3. Rows: `Raw Milk Used L` (Area, light blue)
4. Dual Axis: `Total Net Produced` (Line, dark green)

#### Assemble Dashboard
- Standard layout with KPIs at top
- Efficiency line chart full width
- Category bar + YoY heatmap side by side
- Band donut + Shift comparison side by side
- Milk utilization at bottom

---

## 7. Dashboard 4: Inventory & Supply Chain

**Target Audience:** Inventory Manager, Supply Chain Head  
**Data Sources:** `fact_inventory`, `vw_stockout_frequency`, `vw_monthly_turnover`, `vw_stock_supply_risk`

### Sheets to Build (6 Total)

#### Sheet 1: `Inv_KPI_Cards` (4 cards)
- Total Closing Stock, Stockout Rate %, Products At Risk, Avg Turnover Ratio

#### Sheet 2: `Current_Stock_Highlight`
1. Data Source: `fact_inventory` (filter: date = MAX date)
2. Rows: Product Name
3. Columns: Closing Stock, Reorder Level, Stock Status, Shelf Life Risk, Days of Stock
4. Mark: Text table with conditional formatting
5. Color cells by Stock Status: OK=Green, Low=Yellow, Critical=Orange, Stockout=Red

#### Sheet 3: `Stockout_Frequency_Bar`
1. Data Source: `vw_stockout_frequency`
2. Rows: `Product Name` (sorted by stockout rate DESC)
3. Columns: `Stockout Rate Pct`
4. Color by `Risk Category`

#### Sheet 4: `Monthly_Turnover_Line`
1. Data Source: `vw_monthly_turnover`
2. Columns: Year-Month
3. Rows: AVG(Turnover Ratio)
4. Color/Detail: `Category`
5. Mark: Line with circle markers

#### Sheet 5: `Shelf_Life_100_Bar`
1. Data Source: `fact_inventory`
2. Rows: `Category`
3. Columns: `COUNT(*)` — stack by `Shelf Life Risk`
4. Quick Table Calc: Percent of Total → Running along Table
5. Color: Safe=Green, At Risk=Red

#### Sheet 6: `Days_Supply_Lollipop`
1. Data Source: `vw_stock_supply_risk`
2. Rows: `Product Name`
3. Columns: `Days of Stock Remaining`
4. Mark: Circle (lollipop style)
5. Add Reference Line at Shelf Life Days
6. Color by `Supply Risk`

---

## 8. Dashboard 5: Accounts & Finance

**Target Audience:** Finance Head, Accounts Manager  
**Data Sources:** `fact_accounts`, `vw_billing_collections`, `vw_receivables_aging`, `vw_customer_payment`, `vw_dso_monthly`, `vw_custtype_efficiency`

### Sheets to Build (6 Total)

#### Sheet 1: `Acc_KPI_Cards` (5 cards)
- Total Billed, Total Collected, Outstanding, DSO Days, Collection %

#### Sheet 2: `Billing_Collections_Combo`
1. Data Source: `vw_billing_collections`
2. Columns: Year-Month
3. Rows: `Total Billed` (Bar, Blue), `Total Collected` (Bar, Green)
4. Dual Axis: `Collection Efficiency Pct` (Line, Orange)

#### Sheet 3: `Aging_Stacked_Bar`
1. Data Source: `vw_receivables_aging`
2. Columns: `Aging Bucket` (sorted by Sort Order)
3. Rows: `Outstanding Amount`
4. Color: Gradient (1-30d=Light Red → 90+d=Dark Red)
5. Label: Amount + % of total

#### Sheet 4: `Customer_Payment_Table`
1. Data Source: `vw_customer_payment`
2. Scrollable highlight table — top 20 by outstanding
3. Columns: Total Billed, Total Paid, Outstanding, On-Time %, Overdue %
4. Conditional formatting on Collection Efficiency

#### Sheet 5: `DSO_Trend_Line`
1. Data Source: `vw_dso_monthly`
2. Columns: Year-Month
3. Rows: `DSO Days`
4. Reference Line at 15 (Good threshold) and 30 (Warning threshold)
5. Color zones: Green <15, Amber 15-30, Red >30

#### Sheet 6: `CustType_Grouped_Bar`
1. Data Source: `vw_custtype_efficiency`
2. Rows: `Customer Type`
3. Columns: `Collection Efficiency Pct`
4. Color: Conditional on efficiency level
5. Label: Efficiency % + Avg Days to Pay

---

## 9. Formatting Standards

Apply these **globally** across all dashboards for a premium, consistent look.

### Color Palette

| Use Case | Hex Code | Example |
|----------|----------|---------|
| Dashboard Background | `#1e2a3a` | Dark navy |
| Card Background | `#2d3748` | Slate gray |
| Primary Text | `#FFFFFF` | White |
| Secondary Text | `#A0AEC0` | Light gray |
| Primary Accent | `#17A2B8` | Teal |
| Success/Green | `#28A745` | On target |
| Warning/Amber | `#FFC107` | Below target |
| Danger/Red | `#DC3545` | Critical |
| Revenue Bars | `#4299E1` | Blue |
| Positive Growth | `#48BB78` | Green |
| Negative Growth | `#F56565` | Red |

### Font Settings

| Element | Font | Size | Style |
|---------|------|------|-------|
| Dashboard Title | Trebuchet MS | 20pt | Bold, White |
| Sheet Title | Trebuchet MS | 14pt | Bold, White |
| KPI Number | Trebuchet MS | 36pt | Bold, White |
| KPI Label | Trebuchet MS | 10pt | Regular, Gray |
| Axis Labels | Trebuchet MS | 10pt | Regular, Gray |
| Tooltips | Trebuchet MS | 11pt | Regular, Dark |

### Tooltip Template (Example for Revenue)
```
<b>Month:</b> <Month Name> <Year>
<b>Revenue:</b> ₹<SUM(Net Amount)>
<b>Invoices:</b> <COUNTD(Invoice Number)>
<b>Customers:</b> <COUNTD(Customer Id)>
<b>MoM Growth:</b> <Mom Growth Pct>%
```

### Number Formatting

| Metric | Format | Example |
|--------|--------|---------|
| Revenue (₹) | Custom: `₹#,##,##0` | ₹42,15,340 |
| Large Revenue | Custom: `₹#,##0.0,,"Cr"` | ₹4.2Cr |
| Percentage | Percentage, 1 decimal | 93.4% |
| Count | Number, 0 decimals | 12,400 |
| DSO Days | Number, 1 decimal + " days" | 14.2 days |

---

## 10. Navigation & Interactivity

### Dashboard Navigation Bar

Add a **horizontal container** at the top of every dashboard with 5 navigation buttons:

```
[ 🏠 Executive ]  [ 💰 Sales ]  [ 🏭 Production ]  [ 📦 Inventory ]  [ 💳 Finance ]
```

**Implementation:**
1. Create 5 blank sheets with just a title (e.g., "🏠 Executive")
2. Format each as a button (colored background, white text)
3. Add Dashboard Action → **Navigate** → target the respective dashboard
4. Highlight the current dashboard's button with a brighter color

### Filter Actions

On each dashboard, add:
1. **Dashboard** → Actions → Add Action → **Filter**
2. Source: Any chart on the dashboard
3. Target: All other sheets on same dashboard
4. Run on: **Select**
5. Clear selection: Show all values

### Highlight Actions

1. **Dashboard** → Actions → Add Action → **Highlight**
2. Source: Category charts, Route charts
3. Target: Neighboring charts
4. Run on: **Hover**

### Parameter for Top N (Sales Dashboard)

1. Create Parameter: `Top N Customers`
   - Data type: Integer
   - Range: 5 to 50, Step: 5
2. Create Calculated Field: `Customer Rank = RANK(SUM([Net Amount]))`
3. Filter: `Customer Rank <= [Top N Customers]`
4. Show parameter control as slider

---

## Quick Reference: Dashboard → Data Source Map

| Dashboard | Primary Tables | Pre-computed Views |
|-----------|---------------|-------------------|
| Executive Summary | fact_sales, fact_production, fact_inventory, fact_accounts | vw_sales_monthly, vw_receivables_aging |
| Sales & Revenue | fact_sales | vw_sales_monthly, vw_yoy_revenue, vw_customer_segments |
| Production & Ops | fact_production | vw_production_monthly, vw_category_efficiency, vw_production_yoy_yield, vw_shift_performance |
| Inventory & Supply | fact_inventory | vw_stockout_frequency, vw_monthly_turnover, vw_stock_supply_risk |
| Accounts & Finance | fact_accounts | vw_billing_collections, vw_receivables_aging, vw_customer_payment, vw_dso_monthly, vw_custtype_efficiency |

---

## Final Checklist Before Publishing

- [ ] All 5 dashboards render at 1920 × 1080
- [ ] Navigation buttons work across all dashboards
- [ ] Filter actions tested — click on one chart filters all others
- [ ] All KPI card values match SQL output:
  - Total Revenue ≈ ₹4.2 Cr
  - Production Efficiency ≈ 93.4%
  - Stockout Rate ≈ 8.3%
  - Collection Efficiency ≈ 86.4%
  - DSO ≈ 14.2 days
- [ ] Tooltips display clean formatted values
- [ ] No overlapping labels or truncated text
- [ ] Dark theme applied consistently
- [ ] Saved as `.twbx` (Packaged Workbook) for portability
