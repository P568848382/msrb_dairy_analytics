-- ═══════════════════════════════════════════════════════════════════════════
-- FILE    : kpi_production.sql
-- PROJECT : MSRB SONS DAIRY — Production KPI Queries
-- AUTHOR  : Pradeep Kumar
-- ═══════════════════════════════════════════════════════════════════════════

-- ── KPI 1: Monthly Production Efficiency ────────────────────────────────────
SELECT
    year, month, month_name, quarter, financial_year,
    SUM(planned_qty)                        AS total_planned,
    SUM(actual_qty)                         AS total_actual,
    SUM(wastage_qty)                        AS total_wastage,
    SUM(net_produced_qty)                   AS total_net_produced,
    ROUND(SUM(raw_milk_used_l),0)           AS raw_milk_used_L,
    ROUND(SUM(actual_qty) * 100.0
          / NULLIF(SUM(planned_qty),0), 2)  AS overall_efficiency_pct,
    ROUND(SUM(wastage_qty) * 100.0
          / NULLIF(SUM(actual_qty),0), 2)   AS overall_wastage_pct
FROM fact_production
GROUP BY year, month, month_name, quarter, financial_year
ORDER BY year, month;


-- ── KPI 2: Efficiency by Product Category ────────────────────────────────────
SELECT
    category,
    SUM(planned_qty)                        AS total_planned,
    SUM(actual_qty)                         AS total_actual,
    SUM(wastage_qty)                        AS total_wastage,
    ROUND(AVG(production_efficiency_pct),2) AS avg_efficiency_pct,
    ROUND(AVG(wastage_rate_pct),2)          AS avg_wastage_pct,
    ROUND(SUM(raw_milk_used_l),0)           AS total_raw_milk_L,
    ROUND(SUM(net_produced_qty)
          / NULLIF(SUM(raw_milk_used_l),0) * 100, 3) AS yield_pct
FROM fact_production
GROUP BY category
ORDER BY avg_efficiency_pct DESC;


-- ── KPI 3: Efficiency Band Distribution ──────────────────────────────────────
SELECT
    efficiency_band,
    COUNT(*)                                AS production_runs,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_runs
FROM fact_production
WHERE efficiency_band IS NOT NULL
GROUP BY efficiency_band
ORDER BY 2 DESC;


-- ── KPI 4: Shift-wise Performance ────────────────────────────────────────────
SELECT
    shift,
    COUNT(*)                                AS production_runs,
    ROUND(AVG(production_efficiency_pct),2) AS avg_efficiency_pct,
    ROUND(AVG(wastage_rate_pct),2)          AS avg_wastage_pct,
    SUM(actual_qty)                         AS total_produced
FROM fact_production
GROUP BY shift
ORDER BY avg_efficiency_pct DESC;


-- ── KPI 5: Monthly Raw Milk Utilization ──────────────────────────────────────
SELECT
    year, month, month_name,
    ROUND(SUM(raw_milk_used_l),0)           AS raw_milk_used_L,
    ROUND(SUM(net_produced_qty),0)          AS net_produced,
    ROUND(SUM(net_produced_qty)
          / NULLIF(SUM(raw_milk_used_l),0) * 100, 3) AS yield_efficiency_pct
FROM fact_production
GROUP BY year, month, month_name
ORDER BY year, month;


-- ══════════════════════════════════════════════════════════════════════════════
-- FILE    : kpi_inventory.sql
-- ══════════════════════════════════════════════════════════════════════════════

-- ── KPI 1: Current Stock Status (Latest Date) ────────────────────────────────
SELECT
    product_id, product_name, category,
    closing_stock,
    reorder_level,
    stock_status,
    shelf_life_risk,
    ROUND(days_of_stock,1)                  AS days_of_stock,
    date
FROM fact_inventory
WHERE date = (SELECT MAX(date) FROM fact_inventory)
ORDER BY stock_status, category;


-- ── KPI 2: Stockout Frequency by Product ─────────────────────────────────────
SELECT
    product_id,
    product_name,
    category,
    COUNT(*)                                AS total_days,
    SUM(CASE WHEN stock_status = 'Stockout' THEN 1 ELSE 0 END) AS stockout_days,
    SUM(CASE WHEN stock_status = 'Critical' THEN 1 ELSE 0 END) AS critical_days,
    ROUND(SUM(CASE WHEN stock_status = 'Stockout' THEN 1 ELSE 0 END)
          * 100.0 / COUNT(*), 2)            AS stockout_rate_pct
FROM fact_inventory
GROUP BY product_id, product_name, category
ORDER BY stockout_rate_pct DESC;


-- ── KPI 3: Monthly Stock Turnover ─────────────────────────────────────────────
SELECT
    year, month, month_name,
    product_id, product_name, category,
    ROUND(AVG(opening_stock + closing_stock) / 2, 0) AS avg_inventory,
    SUM(dispatched_qty)                     AS total_dispatched,
    ROUND(SUM(dispatched_qty)
          / NULLIF(AVG((opening_stock + closing_stock)/2),0), 2) AS turnover_ratio
FROM fact_inventory
GROUP BY year, month, month_name, product_id, product_name, category
ORDER BY year, month, turnover_ratio DESC;


-- ── KPI 4: Shelf Life Risk Summary ────────────────────────────────────────────
SELECT
    category,
    shelf_life_risk,
    COUNT(*)                                AS records,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY category), 2) AS pct
FROM fact_inventory
GROUP BY category, shelf_life_risk
ORDER BY category, shelf_life_risk;


-- ══════════════════════════════════════════════════════════════════════════════
-- FILE    : kpi_accounts.sql
-- ══════════════════════════════════════════════════════════════════════════════

-- ── KPI 1: Monthly Billing vs Collections ─────────────────────────────────────
SELECT
    year, month, month_name, quarter, financial_year,
    COUNT(DISTINCT customer_id)             AS customers_billed,
    ROUND(SUM(invoice_amount),2)            AS total_billed,
    ROUND(SUM(amount_paid),2)               AS total_collected,
    ROUND(SUM(outstanding_balance),2)       AS total_outstanding,
    ROUND(SUM(amount_paid) * 100.0
          / NULLIF(SUM(invoice_amount),0),2) AS collection_efficiency_pct
FROM fact_accounts
GROUP BY year, month, month_name, quarter, financial_year
ORDER BY year, month;


-- ── KPI 2: Receivables Aging Summary ─────────────────────────────────────────
SELECT
    aging_bucket,
    COUNT(*)                                AS invoices,
    COUNT(DISTINCT customer_id)             AS customers,
    ROUND(SUM(outstanding_balance),2)       AS outstanding_amount,
    ROUND(SUM(outstanding_balance) * 100.0
          / NULLIF(SUM(SUM(outstanding_balance)) OVER (),0), 2) AS pct_of_total
FROM fact_accounts
WHERE payment_status = 'Overdue'
GROUP BY aging_bucket
ORDER BY
    CASE aging_bucket
        WHEN '1-30 Days'   THEN 1
        WHEN '31-60 Days'  THEN 2
        WHEN '61-90 Days'  THEN 3
        WHEN '90+ Days'    THEN 4
        ELSE 5
    END;


-- ── KPI 3: Customer Payment Behaviour ─────────────────────────────────────────
SELECT
    customer_id,
    customer_name,
    customer_type,
    COUNT(*)                                AS total_invoices,
    ROUND(SUM(invoice_amount),2)            AS total_billed,
    ROUND(SUM(amount_paid),2)               AS total_paid,
    ROUND(SUM(outstanding_balance),2)       AS outstanding,
    ROUND(AVG(days_to_payment),1)           AS avg_days_to_pay,
    SUM(CASE WHEN payment_status='Overdue'    THEN 1 ELSE 0 END) AS overdue_count,
    SUM(CASE WHEN payment_status='Paid Late'  THEN 1 ELSE 0 END) AS late_count,
    SUM(CASE WHEN payment_status='Paid'       THEN 1 ELSE 0 END) AS on_time_count,
    ROUND(SUM(amount_paid)*100.0
          / NULLIF(SUM(invoice_amount),0),2) AS collection_efficiency_pct
FROM fact_accounts
GROUP BY customer_id, customer_name, customer_type
ORDER BY outstanding DESC;


-- ── KPI 4: Days Sales Outstanding (DSO) by Month ─────────────────────────────
SELECT
    year, month, month_name,
    ROUND(SUM(outstanding_balance),2)       AS month_end_receivables,
    ROUND(SUM(invoice_amount) / 30.0, 2)    AS avg_daily_sales,
    ROUND(
        SUM(outstanding_balance)
        / NULLIF(SUM(invoice_amount) / 30.0, 0)
    , 1)                                    AS dso_days
FROM fact_accounts
GROUP BY year, month, month_name
ORDER BY year, month;


-- ── KPI 5: Customer Type Collection Efficiency ────────────────────────────────
SELECT
    customer_type,
    COUNT(DISTINCT customer_id)             AS customers,
    COUNT(*)                                AS invoices,
    ROUND(SUM(invoice_amount),2)            AS total_billed,
    ROUND(SUM(amount_paid),2)               AS total_collected,
    ROUND(SUM(outstanding_balance),2)       AS outstanding,
    ROUND(SUM(amount_paid)*100.0
          / NULLIF(SUM(invoice_amount),0),2) AS collection_efficiency_pct,
    ROUND(AVG(CASE WHEN payment_status != 'Overdue'
               THEN days_to_payment END),1)  AS avg_days_to_pay
FROM fact_accounts
GROUP BY customer_type
ORDER BY collection_efficiency_pct DESC;
