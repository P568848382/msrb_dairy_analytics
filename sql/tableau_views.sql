-- ═══════════════════════════════════════════════════════════════════════════
-- FILE    : tableau_views.sql
-- PROJECT : MSRB SONS DAIRY — Tableau BI Layer
-- AUTHOR  : Pradeep Kumar
-- PURPOSE : Creates PostgreSQL VIEWs for Tableau Dashboard consumption.
--           These views pre-compute complex KPIs (CTEs, pivots, self-joins)
--           so Tableau can consume them as flat tables.
--           Run this ONCE after schema_create.sql and 06_load_to_postgres.py
-- ═══════════════════════════════════════════════════════════════════════════
-- ───────────────────────────────────────────────────────────────────────────
-- DROP EXISTING VIEWS (safe re-run)
-- ───────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS vw_sales_monthly          CASCADE;
DROP VIEW IF EXISTS vw_yoy_revenue            CASCADE;
DROP VIEW IF EXISTS vw_customer_segments      CASCADE;
DROP VIEW IF EXISTS vw_production_yoy_yield   CASCADE;
DROP VIEW IF EXISTS vw_receivables_aging      CASCADE;
DROP VIEW IF EXISTS vw_stock_supply_risk      CASCADE;
DROP VIEW IF EXISTS vw_production_monthly     CASCADE;
DROP VIEW IF EXISTS vw_category_efficiency    CASCADE;
DROP VIEW IF EXISTS vw_shift_performance      CASCADE;
DROP VIEW IF EXISTS vw_stockout_frequency     CASCADE;
DROP VIEW IF EXISTS vw_monthly_turnover       CASCADE;
DROP VIEW IF EXISTS vw_billing_collections    CASCADE;
DROP VIEW IF EXISTS vw_customer_payment       CASCADE;
DROP VIEW IF EXISTS vw_dso_monthly            CASCADE;
DROP VIEW IF EXISTS vw_custtype_efficiency    CASCADE;
-- ═══════════════════════════════════════════════════════════════════════════
--  SALES VIEWS
-- ═══════════════════════════════════════════════════════════════════════════
-- ── VIEW 1: Monthly Revenue Trend (Sales KPI #1) ─────────────────────────
-- Purpose: Time-series revenue with month-over-month growth calculation
CREATE VIEW vw_sales_monthly AS
WITH monthly AS (
    SELECT
        year,
        month,
        month_name,
        quarter,
        financial_year,
        COUNT(DISTINCT invoice_number)                          AS total_invoices,
        COUNT(DISTINCT customer_id)                             AS unique_customers,
        SUM(quantity)                                           AS total_qty_sold,
        ROUND(SUM(gross_amount)::NUMERIC, 2)                   AS gross_revenue,
        ROUND(SUM(discount)::NUMERIC, 2)                       AS total_discount,
        ROUND(SUM(net_amount)::NUMERIC, 2)                     AS net_revenue,
        ROUND((SUM(net_amount) / NULLIF(COUNT(DISTINCT invoice_number), 0))::NUMERIC, 2)
                                                                AS avg_invoice_value,
        ROUND((SUM(discount) / NULLIF(SUM(gross_amount), 0) * 100)::NUMERIC, 2)
                                                                AS discount_pct
    FROM fact_sales
    GROUP BY year, month, month_name, quarter, financial_year
)
SELECT
    m.*,
    LAG(m.net_revenue) OVER (ORDER BY m.year, m.month)          AS prev_month_revenue,
    ROUND(
        ((m.net_revenue - LAG(m.net_revenue) OVER (ORDER BY m.year, m.month))
        / NULLIF(LAG(m.net_revenue) OVER (ORDER BY m.year, m.month), 0)
        * 100)::NUMERIC, 2
    )                                                           AS mom_growth_pct
FROM monthly m
ORDER BY m.year, m.month;
-- ── VIEW 2: Year-over-Year Revenue Comparison (Sales KPI #6) ─────────────
-- Purpose: FY2023-24 vs FY2024-25 side-by-side for each month
CREATE VIEW vw_yoy_revenue AS
WITH monthly AS (
    SELECT
        month,
        month_name,
        financial_year,
        ROUND(SUM(net_amount)::NUMERIC, 2) AS net_revenue
    FROM fact_sales
    GROUP BY month, month_name, financial_year
)
SELECT
    m1.month,
    m1.month_name,
    m1.net_revenue                                              AS revenue_fy2023_24,
    m2.net_revenue                                              AS revenue_fy2024_25,
    ROUND((m2.net_revenue - m1.net_revenue)::NUMERIC, 2)        AS absolute_change,
    ROUND(
        ((m2.net_revenue - m1.net_revenue)
        / NULLIF(m1.net_revenue, 0) * 100)::NUMERIC, 2
    )                                                           AS yoy_growth_pct
FROM monthly m1
JOIN monthly m2
    ON  m1.month = m2.month
    AND m1.financial_year = 'FY2023-24'
    AND m2.financial_year = 'FY2024-25'
ORDER BY m1.month;
-- ── VIEW 3: Customer Segmentation by Spend Band (Sales KPI #7) ───────────
-- Purpose: Platinum/Gold/Silver/Bronze/Standard tiering
CREATE VIEW vw_customer_segments AS
WITH customer_revenue AS (
    SELECT
        customer_id,
        customer_name,
        customer_type,
        route_name,
        COUNT(DISTINCT invoice_number)                          AS total_invoices,
        ROUND(SUM(net_amount)::NUMERIC, 2)                     AS total_revenue,
        MIN(date)::DATE                                         AS first_purchase,
        MAX(date)::DATE                                         AS last_purchase
    FROM fact_sales
    GROUP BY customer_id, customer_name, customer_type, route_name
)
SELECT
    *,
    CASE
        WHEN total_revenue >= 900000 THEN 'Platinum (>=9L)'
        WHEN total_revenue >= 850000 THEN 'Gold (8.5L-9L)'
        WHEN total_revenue >= 750000 THEN 'Silver (7.5L-8.5L)'
        WHEN total_revenue >= 650000 THEN 'Bronze (6.5L-7.5L)'
        ELSE                              'Standard (<6L)'
    END                                                         AS customer_segment,
    CASE
        WHEN total_revenue >= 900000 THEN 1
        WHEN total_revenue >= 850000 THEN 2
        WHEN total_revenue >= 750000 THEN 3
        WHEN total_revenue >= 650000 THEN 4
        ELSE                              5
    END                                                         AS segment_rank
FROM customer_revenue;
-- ═══════════════════════════════════════════════════════════════════════════
--  PRODUCTION VIEWS
-- ═══════════════════════════════════════════════════════════════════════════
-- ── VIEW 4: Monthly Production Efficiency (Production KPI #1) ────────────
CREATE VIEW vw_production_monthly AS
SELECT
    year,
    month,
    month_name,
    quarter,
    financial_year,
    SUM(planned_qty)                                            AS total_planned,
    SUM(actual_qty)                                             AS total_actual,
    SUM(wastage_qty)                                            AS total_wastage,
    SUM(net_produced_qty)                                       AS total_net_produced,
    ROUND(SUM(raw_milk_used_l)::NUMERIC, 2)                    AS raw_milk_used_l,
    ROUND((SUM(actual_qty) * 100.0
        / NULLIF(SUM(planned_qty), 0))::NUMERIC, 2)            AS efficiency_pct,
    ROUND((SUM(wastage_qty) * 100.0
        / NULLIF(SUM(actual_qty), 0))::NUMERIC, 2)             AS wastage_pct,
    ROUND((SUM(net_produced_qty) * 100.0
        / NULLIF(SUM(raw_milk_used_l), 0))::NUMERIC, 2)        AS yield_pct
FROM fact_production
GROUP BY year, month, month_name, quarter, financial_year
ORDER BY year, month;
-- ── VIEW 5: Category Efficiency + YoY Yield Pivot (Production KPI #2) ────
CREATE VIEW vw_category_efficiency AS
SELECT
    year,
    category,
    SUM(planned_qty)                                            AS total_planned,
    SUM(actual_qty)                                             AS total_actual,
    SUM(wastage_qty)                                            AS total_wastage,
    ROUND((SUM(actual_qty) * 100.0
        / NULLIF(SUM(planned_qty), 0))::NUMERIC, 2)            AS efficiency_pct,
    ROUND((SUM(wastage_qty) * 100.0
        / NULLIF(SUM(actual_qty), 0))::NUMERIC, 2)             AS wastage_pct,
    ROUND(SUM(raw_milk_used_l)::NUMERIC, 2)                    AS total_raw_milk_l,
    ROUND((SUM(net_produced_qty)
        / NULLIF(SUM(raw_milk_used_l), 0) * 100)::NUMERIC, 2) AS yield_pct
FROM fact_production
GROUP BY year, category
ORDER BY year, efficiency_pct DESC;
-- ── VIEW 6: YoY Yield Pivot by Category (Production KPI #2 bonus) ────────
CREATE VIEW vw_production_yoy_yield AS
WITH category_yearly AS (
    SELECT
        year,
        category,
        ROUND((SUM(net_produced_qty)
            / NULLIF(SUM(raw_milk_used_l), 0) * 100)::NUMERIC, 2) AS yield_pct
    FROM fact_production
    GROUP BY year, category
)
SELECT
    category,
    MAX(CASE WHEN year = 2023 THEN yield_pct END)               AS yield_2023,
    MAX(CASE WHEN year = 2024 THEN yield_pct END)               AS yield_2024,
    MAX(CASE WHEN year = 2025 THEN yield_pct END)               AS yield_2025
FROM category_yearly
GROUP BY category;
-- ── VIEW 7: Shift-wise Performance (Production KPI #4) ──────────────────
CREATE VIEW vw_shift_performance AS
SELECT
    shift,
    COUNT(*)                                                    AS production_runs,
    ROUND((SUM(actual_qty) * 100.0
        / NULLIF(SUM(planned_qty), 0))::NUMERIC, 2)            AS avg_efficiency_pct,
    ROUND((SUM(wastage_qty) * 100.0
        / NULLIF(SUM(actual_qty), 0))::NUMERIC, 2)             AS avg_wastage_pct,
    SUM(actual_qty)                                             AS total_produced,
    ROUND(SUM(actual_qty) * 100.0
        / SUM(SUM(actual_qty)) OVER ()::NUMERIC, 2)            AS production_share_pct
FROM fact_production
GROUP BY shift;
-- ═══════════════════════════════════════════════════════════════════════════
--  INVENTORY VIEWS
-- ═══════════════════════════════════════════════════════════════════════════
-- ── VIEW 8: Stockout Frequency by Product (Inventory KPI #2) ─────────────
CREATE VIEW vw_stockout_frequency AS
WITH stockout_data AS (
    SELECT
        product_id,
        product_name,
        category,
        COUNT(*)                                                AS total_days,
        SUM(CASE WHEN stock_status = 'Stockout' THEN 1 ELSE 0 END)
                                                                AS stockout_days,
        SUM(CASE WHEN stock_status = 'Critical' THEN 1 ELSE 0 END)
                                                                AS critical_days,
        ROUND((SUM(CASE WHEN stock_status = 'Stockout' THEN 1 ELSE 0 END)
            * 100.0 / COUNT(*))::NUMERIC, 2)                    AS stockout_rate_pct
    FROM fact_inventory
    GROUP BY product_id, product_name, category
)
SELECT
    *,
    CASE
        WHEN stockout_days >= 5 THEN 'High Risk'
        WHEN stockout_days >= 2 THEN 'Medium Risk'
        WHEN stockout_days >= 1 THEN 'Low Risk'
        ELSE                         'No Stockout'
    END                                                         AS risk_category
FROM stockout_data
ORDER BY stockout_rate_pct DESC;
-- ── VIEW 9: Monthly Stock Turnover (Inventory KPI #3) ───────────────────
CREATE VIEW vw_monthly_turnover AS
WITH monthly_stock AS (
    SELECT
        year,
        month,
        month_name,
        product_id,
        product_name,
        category,
        ROUND((AVG(opening_stock + closing_stock) / 2)::NUMERIC, 2)
                                                                AS avg_inventory,
        SUM(dispatched_qty)                                     AS total_dispatched,
        ROUND((SUM(dispatched_qty)
            / NULLIF(AVG((opening_stock + closing_stock) / 2), 0))::NUMERIC, 2)
                                                                AS turnover_ratio
    FROM fact_inventory
    GROUP BY year, month, month_name, product_id, product_name, category
)
SELECT
    *,
    CASE
        WHEN turnover_ratio >= 10 THEN 'Fast Moving'
        WHEN turnover_ratio >= 5  THEN 'Normal'
        WHEN turnover_ratio >= 1  THEN 'Slow Moving'
        ELSE                           'Dead Stock Risk'
    END                                                         AS movement_category
FROM monthly_stock
ORDER BY year, month, turnover_ratio DESC;
-- ── VIEW 10: Days of Supply Remaining (Inventory KPI #5) ────────────────
CREATE VIEW vw_stock_supply_risk AS
WITH current_stock AS (
    SELECT
        product_id,
        product_name,
        category,
        closing_stock,
        reorder_level,
        stock_status,
        shelf_life_days
    FROM fact_inventory
    WHERE date = (SELECT MAX(date) FROM fact_inventory)
),
avg_dispatch AS (
    SELECT
        product_id,
        ROUND(AVG(dispatched_qty)::NUMERIC, 2)                 AS avg_daily_dispatch
    FROM fact_inventory
    GROUP BY product_id
)
SELECT
    cs.*,
    ad.avg_daily_dispatch,
    ROUND((cs.closing_stock
        / NULLIF(ad.avg_daily_dispatch, 0))::NUMERIC, 2)       AS days_of_stock_remaining,
    CASE
        WHEN cs.closing_stock = 0 THEN 'Stockout'
        WHEN ROUND((cs.closing_stock
            / NULLIF(ad.avg_daily_dispatch, 0))::NUMERIC, 2) < 1
            THEN 'Critical - Under 1 Day'
        WHEN ROUND((cs.closing_stock
            / NULLIF(ad.avg_daily_dispatch, 0))::NUMERIC, 2) > cs.shelf_life_days
            THEN 'At Risk - Expires Before Sold'
        ELSE 'Safe - Sells Before Expiry'
    END                                                         AS supply_risk
FROM current_stock cs
JOIN avg_dispatch ad ON cs.product_id = ad.product_id
ORDER BY days_of_stock_remaining DESC;
-- ═══════════════════════════════════════════════════════════════════════════
--  ACCOUNTS & FINANCE VIEWS
-- ═══════════════════════════════════════════════════════════════════════════
-- ── VIEW 11: Monthly Billing vs Collections (Accounts KPI #1) ───────────
CREATE VIEW vw_billing_collections AS
SELECT
    year,
    month,
    month_name,
    quarter,
    financial_year,
    COUNT(DISTINCT customer_id)                                 AS customers_billed,
    ROUND(SUM(invoice_amount)::NUMERIC, 2)                     AS total_billed,
    ROUND(SUM(amount_paid)::NUMERIC, 2)                        AS total_collected,
    ROUND(SUM(outstanding_balance)::NUMERIC, 2)                AS total_outstanding,
    ROUND((SUM(amount_paid) * 100.0
        / NULLIF(SUM(invoice_amount), 0))::NUMERIC, 2)         AS collection_efficiency_pct
FROM fact_accounts
GROUP BY year, month, month_name, quarter, financial_year
ORDER BY year, month;
-- ── VIEW 12: Receivables Aging Summary (Accounts KPI #2) ────────────────
CREATE VIEW vw_receivables_aging AS
SELECT
    aging_bucket,
    COUNT(*)                                                    AS invoices,
    COUNT(DISTINCT customer_id)                                 AS customers,
    ROUND(SUM(outstanding_balance)::NUMERIC, 2)                AS outstanding_amount,
    ROUND((SUM(outstanding_balance) * 100.0
        / NULLIF(SUM(SUM(outstanding_balance)) OVER (), 0))::NUMERIC, 2)
                                                                AS pct_of_total,
    CASE aging_bucket
        WHEN '1-30 Days'  THEN 1
        WHEN '31-60 Days' THEN 2
        WHEN '61-90 Days' THEN 3
        WHEN '90+ Days'   THEN 4
        ELSE 5
    END                                                         AS sort_order
FROM fact_accounts
WHERE payment_status = 'OverDue'
GROUP BY aging_bucket
ORDER BY sort_order;
-- ── VIEW 13: Customer Payment Behaviour (Accounts KPI #3) ───────────────
CREATE VIEW vw_customer_payment AS
SELECT
    customer_id,
    customer_name,
    customer_type,
    COUNT(*)                                                    AS total_invoices,
    ROUND(SUM(invoice_amount)::NUMERIC, 2)                     AS total_billed,
    ROUND(SUM(amount_paid)::NUMERIC, 2)                        AS total_paid,
    ROUND(SUM(outstanding_balance)::NUMERIC, 2)                AS outstanding_amount,
    ROUND(AVG(days_to_payment)::NUMERIC, 2)                    AS avg_days_to_pay,
    SUM(CASE WHEN payment_status = 'Paid'      THEN 1 ELSE 0 END)
                                                                AS on_time_count,
    SUM(CASE WHEN payment_status = 'Paid Late' THEN 1 ELSE 0 END)
                                                                AS paid_late_count,
    SUM(CASE WHEN payment_status = 'OverDue'   THEN 1 ELSE 0 END)
                                                                AS overdue_count,
    ROUND((SUM(amount_paid) * 100.0
        / NULLIF(SUM(invoice_amount), 0))::NUMERIC, 2)         AS collection_efficiency_pct
FROM fact_accounts
GROUP BY customer_id, customer_name, customer_type
ORDER BY outstanding_amount DESC;
-- ── VIEW 14: DSO by Month (Accounts KPI #4) ─────────────────────────────
CREATE VIEW vw_dso_monthly AS
SELECT
    year,
    month,
    month_name,
    ROUND((SUM(outstanding_balance) * 30.0
        / NULLIF(SUM(invoice_amount), 0))::NUMERIC, 2)         AS dso_days
FROM fact_accounts
GROUP BY year, month, month_name
ORDER BY year, month;
-- ── VIEW 15: Customer Type Collection Efficiency (Accounts KPI #5) ──────
CREATE VIEW vw_custtype_efficiency AS
SELECT
    customer_type,
    COUNT(DISTINCT customer_id)                                 AS customers,
    COUNT(*)                                                    AS invoices,
    ROUND(SUM(invoice_amount)::NUMERIC, 2)                     AS total_billed,
    ROUND(SUM(amount_paid)::NUMERIC, 2)                        AS total_collected,
    ROUND(SUM(outstanding_balance)::NUMERIC, 2)                AS outstanding_amount,
    ROUND((SUM(amount_paid) * 100.0
        / NULLIF(SUM(invoice_amount), 0))::NUMERIC, 2)         AS collection_efficiency_pct,
    ROUND(AVG(CASE WHEN payment_status != 'OverDue'
        THEN days_to_payment END)::NUMERIC, 2)                  AS avg_days_to_pay
FROM fact_accounts
GROUP BY customer_type
ORDER BY collection_efficiency_pct DESC;
-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION: List all views and their row counts
-- ═══════════════════════════════════════════════════════════════════════════
SELECT 'vw_sales_monthly'        AS view_name, COUNT(*) AS rows FROM vw_sales_monthly        UNION ALL
SELECT 'vw_yoy_revenue',                       COUNT(*)         FROM vw_yoy_revenue            UNION ALL
SELECT 'vw_customer_segments',                  COUNT(*)         FROM vw_customer_segments      UNION ALL
SELECT 'vw_production_monthly',                 COUNT(*)         FROM vw_production_monthly     UNION ALL
SELECT 'vw_category_efficiency',                COUNT(*)         FROM vw_category_efficiency    UNION ALL
SELECT 'vw_production_yoy_yield',               COUNT(*)         FROM vw_production_yoy_yield   UNION ALL
SELECT 'vw_shift_performance',                  COUNT(*)         FROM vw_shift_performance      UNION ALL
SELECT 'vw_stockout_frequency',                 COUNT(*)         FROM vw_stockout_frequency     UNION ALL
SELECT 'vw_monthly_turnover',                   COUNT(*)         FROM vw_monthly_turnover       UNION ALL
SELECT 'vw_stock_supply_risk',                  COUNT(*)         FROM vw_stock_supply_risk      UNION ALL
SELECT 'vw_billing_collections',                COUNT(*)         FROM vw_billing_collections    UNION ALL
SELECT 'vw_receivables_aging',                  COUNT(*)         FROM vw_receivables_aging      UNION ALL
SELECT 'vw_customer_payment',                   COUNT(*)         FROM vw_customer_payment       UNION ALL
SELECT 'vw_dso_monthly',                        COUNT(*)         FROM vw_dso_monthly            UNION ALL
SELECT 'vw_custtype_efficiency',                COUNT(*)         FROM vw_custtype_efficiency
ORDER BY 1;