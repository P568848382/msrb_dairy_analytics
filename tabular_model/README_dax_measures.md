# MSRB SONS DAIRY — Tabular Model DAX Measures
**Author:** Pradeep Kumar  
**Model:** SSAS Tabular / Power BI Desktop  
**Connection:** PostgreSQL → msrb_dairy_dw  

---

## HOW TO USE THIS FILE
Import all 4 fact tables from PostgreSQL into Power BI Desktop.  
Create one **Measure Table** (empty table) per department.  
Paste each DAX measure into that table.

---

## TABLE 1 — BASE MEASURES (Sales)

```dax
-- Total Revenue
Total Revenue =
SUM ( fact_sales[net_amount] )

-- Total Gross Revenue
Total Gross Revenue =
SUM ( fact_sales[gross_amount] )

-- Total Discount
Total Discount =
SUM ( fact_sales[discount] )

-- Total Quantity Sold
Total Qty Sold =
SUM ( fact_sales[quantity] )

-- Total Invoices
Total Invoices =
DISTINCTCOUNT ( fact_sales[invoice_number] )

-- Total Unique Customers
Total Customers =
DISTINCTCOUNT ( fact_sales[customer_id] )

-- Average Invoice Value
Avg Invoice Value =
DIVIDE ( [Total Revenue], [Total Invoices] )

-- Discount Percentage
Discount % =
DIVIDE ( [Total Discount], [Total Gross Revenue] ) * 100
```

---

## TABLE 2 — TIME INTELLIGENCE (Sales)

```dax
-- Revenue Month-to-Date
Revenue MTD =
TOTALMTD ( [Total Revenue], dim_date[date_key] )

-- Revenue Year-to-Date
Revenue YTD =
TOTALYTD ( [Total Revenue], dim_date[date_key], "31-03" )
-- Note: "31-03" sets financial year end to March 31

-- Revenue Same Month Last Year
Revenue SMLY =
CALCULATE (
    [Total Revenue],
    SAMEPERIODLASTYEAR ( dim_date[date_key] )
)

-- Revenue Month-over-Month Growth %
Revenue MoM % =
VAR CurrentMonth = [Total Revenue]
VAR LastMonth =
    CALCULATE (
        [Total Revenue],
        DATEADD ( dim_date[date_key], -1, MONTH )
    )
RETURN
    DIVIDE ( CurrentMonth - LastMonth, LastMonth ) * 100

-- Revenue Year-over-Year Growth %
Revenue YoY % =
VAR CurrentYear = [Total Revenue]
VAR LastYear    = [Revenue SMLY]
RETURN
    DIVIDE ( CurrentYear - LastYear, LastYear ) * 100

-- Rolling 3-Month Average Revenue
Revenue 3M Rolling Avg =
CALCULATE (
    AVERAGEX (
        DISTINCT ( dim_date[month_number] ),
        [Total Revenue]
    ),
    DATESINPERIOD ( dim_date[date_key], LASTDATE ( dim_date[date_key] ), -3, MONTH )
)
```

---

## TABLE 3 — PRODUCTION MEASURES

```dax
-- Total Planned Production
Total Planned Qty =
SUM ( fact_production[planned_qty] )

-- Total Actual Production
Total Actual Qty =
SUM ( fact_production[actual_qty] )

-- Total Wastage
Total Wastage Qty =
SUM ( fact_production[wastage_qty] )

-- Production Efficiency %
Production Efficiency % =
DIVIDE (
    SUM ( fact_production[actual_qty] ),
    SUM ( fact_production[planned_qty] )
) * 100

-- Wastage Rate %
Wastage Rate % =
DIVIDE (
    SUM ( fact_production[wastage_qty] ),
    SUM ( fact_production[actual_qty] )
) * 100

-- Total Raw Milk Used (Litres)
Total Raw Milk Used L =
SUM ( fact_production[raw_milk_used_l] )

-- Yield Efficiency %
Yield Efficiency % =
DIVIDE (
    SUM ( fact_production[net_produced_qty] ),
    SUM ( fact_production[raw_milk_used_l] )
) * 100

-- Production Efficiency vs Target (Target = 95%)
Efficiency vs Target =
VAR Actual = [Production Efficiency %]
VAR Target = 95
RETURN Actual - Target
```

---

## TABLE 4 — INVENTORY MEASURES

```dax
-- Current Closing Stock
Current Closing Stock =
CALCULATE (
    SUM ( fact_inventory[closing_stock] ),
    LASTDATE ( fact_inventory[date] )
)

-- Average Daily Dispatch
Avg Daily Dispatch =
AVERAGEX (
    VALUES ( fact_inventory[date] ),
    CALCULATE ( SUM ( fact_inventory[dispatched_qty] ) )
)

-- Days of Stock Remaining
Days of Stock =
DIVIDE ( [Current Closing Stock], [Avg Daily Dispatch] )

-- Stockout Days Count
Stockout Days =
CALCULATE (
    COUNTROWS ( fact_inventory ),
    fact_inventory[stock_status] = "Stockout"
)

-- Stock Turnover Ratio
Stock Turnover Ratio =
DIVIDE (
    SUM ( fact_inventory[dispatched_qty] ),
    AVERAGEX (
        VALUES ( fact_inventory[date] ),
        CALCULATE (
            ( SUM ( fact_inventory[opening_stock] )
            + SUM ( fact_inventory[closing_stock] ) ) / 2
        )
    )
)
```

---

## TABLE 5 — ACCOUNTS & FINANCE MEASURES

```dax
-- Total Invoiced Amount
Total Billed =
SUM ( fact_accounts[invoice_amount] )

-- Total Collected
Total Collected =
SUM ( fact_accounts[amount_paid] )

-- Total Outstanding
Total Outstanding =
SUM ( fact_accounts[outstanding_balance] )

-- Collection Efficiency %
Collection Efficiency % =
DIVIDE ( [Total Collected], [Total Billed] ) * 100

-- Days Sales Outstanding (DSO)
DSO =
DIVIDE (
    [Total Outstanding],
    DIVIDE ( [Total Billed], 30 )
)

-- Overdue Amount
Overdue Amount =
CALCULATE (
    SUM ( fact_accounts[outstanding_balance] ),
    fact_accounts[payment_status] = "Overdue"
)

-- Overdue % of Total Billed
Overdue % =
DIVIDE ( [Overdue Amount], [Total Billed] ) * 100

-- Count of Overdue Invoices
Overdue Invoice Count =
CALCULATE (
    COUNTROWS ( fact_accounts ),
    fact_accounts[payment_status] = "Overdue"
)

-- 90+ Day Overdue Amount
90+ Day Overdue =
CALCULATE (
    SUM ( fact_accounts[outstanding_balance] ),
    fact_accounts[aging_bucket] = "90+ Days"
)

-- Average Days to Pay (paid invoices only)
Avg Days to Pay =
CALCULATE (
    AVERAGE ( fact_accounts[days_to_payment] ),
    fact_accounts[payment_status] <> "Overdue"
)
```

---

## TABLE 6 — RANKING MEASURES

```dax
-- Top N Customers by Revenue (use with slicer)
Top N Customer Rank =
RANKX (
    ALL ( fact_sales[customer_name] ),
    [Total Revenue],
    ,
    DESC,
    DENSE
)

-- Top N Products by Revenue
Top N Product Rank =
RANKX (
    ALL ( fact_sales[product_name] ),
    [Total Revenue],
    ,
    DESC,
    DENSE
)

-- Route Rank by Revenue
Route Revenue Rank =
RANKX (
    ALL ( fact_sales[route_name] ),
    [Total Revenue],
    ,
    DESC,
    DENSE
)
```

---

## TABLE 7 — KPI STATUS MEASURES (for KPI cards / traffic lights)

```dax
-- Production Efficiency Status
Efficiency Status =
VAR Eff = [Production Efficiency %]
RETURN
    SWITCH (
        TRUE(),
        Eff >= 95, "✅ On Target",
        Eff >= 90, "⚠️ Below Target",
        "❌ Critical"
    )

-- Collection Status
Collection Status =
VAR CE = [Collection Efficiency %]
RETURN
    SWITCH (
        TRUE(),
        CE >= 90, "✅ Healthy",
        CE >= 80, "⚠️ Watch",
        "❌ At Risk"
    )

-- DSO Status
DSO Status =
VAR D = [DSO]
RETURN
    SWITCH (
        TRUE(),
        D <= 15, "✅ Good",
        D <= 30, "⚠️ Moderate",
        "❌ High"
    )
```

---

## POWER BI DASHBOARD TIPS

### Relationships to set in Model View:
- `fact_sales[date]` → `dim_date[date_key]`  
- `fact_sales[product_id]` → `dim_product[product_id]`  
- `fact_sales[route_id]` → `dim_route[route_id]`  
- `fact_production[date]` → `dim_date[date_key]`  
- `fact_inventory[date]` → `dim_date[date_key]`  
- `fact_inventory[product_id]` → `dim_product[product_id]`  
- `fact_accounts[invoice_date]` → `dim_date[date_key]`  

### Recommended Slicers:
- Financial Year (from dim_date)  
- Month (from dim_date)  
- Category (from fact_sales or dim_product)  
- Customer Type  
- Route Name  
