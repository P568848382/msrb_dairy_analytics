-- ═══════════════════════════════════════════════════════════════════════════
-- FILE    : kpi_sales.sql
-- PROJECT : MSRB SONS DAIRY — Sales KPI Queries
-- AUTHOR  : Pradeep Kumar
-- ═══════════════════════════════════════════════════════════════════════════

-- ── KPI 1: Monthly Revenue Trend ────────────────────────────────────────────
SELECT
    year,
    month,
    month_name,
    quarter,
    financial_year,
    COUNT(DISTINCT invoice_number)          AS total_invoices,
    COUNT(DISTINCT customer_id)             AS unique_customers,
    SUM(quantity)                           AS total_qty_sold,
    ROUND(SUM(gross_amount),2)              AS gross_revenue,
    ROUND(SUM(discount),2)                  AS total_discount,
    ROUND(SUM(net_amount),2)                AS net_revenue,
    ROUND(SUM(net_amount) / COUNT(DISTINCT invoice_number), 2) AS avg_invoice_value,
    ROUND(SUM(discount) / NULLIF(SUM(gross_amount),0) * 100, 2) AS discount_pct
FROM fact_sales
GROUP BY year, month, month_name, quarter, financial_year
ORDER BY year, month;


-- ── KPI 2: Revenue by Product Category ──────────────────────────────────────
SELECT
    category,
    COUNT(*)                                AS transactions,
    SUM(quantity)                           AS total_qty,
    ROUND(SUM(net_amount),2)                AS net_revenue,
    ROUND(SUM(net_amount) * 100.0
          / SUM(SUM(net_amount)) OVER (), 2) AS revenue_share_pct,
    ROUND(AVG(unit_price),2)               AS avg_unit_price,
    ROUND(AVG(discount / NULLIF(gross_amount,0)) * 100, 2) AS avg_discount_pct
FROM fact_sales
GROUP BY category
ORDER BY net_revenue DESC;


-- ── KPI 3: Route Performance ─────────────────────────────────────────────────
SELECT
    route_id,
    route_name,
    COUNT(DISTINCT customer_id)             AS customers_served,
    COUNT(DISTINCT invoice_number)          AS total_invoices,
    ROUND(SUM(net_amount),2)                AS net_revenue,
    ROUND(AVG(net_amount),2)                AS avg_invoice_value,
    ROUND(SUM(net_amount) * 100.0
          / SUM(SUM(net_amount)) OVER (), 2) AS revenue_share_pct
FROM fact_sales
GROUP BY route_id, route_name
ORDER BY net_revenue DESC;


-- ── KPI 4: Top 20 Customers by Revenue ───────────────────────────────────────
SELECT
    customer_id,
    customer_name,
    customer_type,
    route_name,
    COUNT(DISTINCT invoice_number)          AS total_invoices,
    ROUND(SUM(net_amount),2)                AS lifetime_revenue,
    ROUND(AVG(net_amount),2)                AS avg_invoice_value,
    MIN(date)::TEXT                         AS first_purchase,
    MAX(date)::TEXT                         AS last_purchase,
    COUNT(DISTINCT date)                    AS active_days
FROM fact_sales
GROUP BY customer_id, customer_name, customer_type, route_name
ORDER BY lifetime_revenue DESC
LIMIT 20;


-- ── KPI 5: Payment Mode Analysis ─────────────────────────────────────────────
SELECT
    payment_mode,
    COUNT(*)                                AS transactions,
    ROUND(SUM(net_amount),2)                AS total_revenue,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS txn_share_pct,
    ROUND(SUM(net_amount) * 100.0
          / SUM(SUM(net_amount)) OVER (), 2) AS revenue_share_pct,
    ROUND(AVG(net_amount),2)               AS avg_transaction_value
FROM fact_sales
GROUP BY payment_mode
ORDER BY total_revenue DESC;


-- ── KPI 6: Year-over-Year Revenue Comparison ─────────────────────────────────
WITH monthly AS (
    SELECT
        year, month, month_name,
        ROUND(SUM(net_amount),2) AS net_revenue
    FROM fact_sales
    GROUP BY year, month, month_name
)
SELECT
    m1.month_name,
    m1.month,
    m1.net_revenue                          AS revenue_2023_24,
    m2.net_revenue                          AS revenue_2024_25,
    ROUND(m2.net_revenue - m1.net_revenue, 2) AS absolute_change,
    ROUND((m2.net_revenue - m1.net_revenue)
          / NULLIF(m1.net_revenue,0) * 100, 2) AS yoy_growth_pct
FROM monthly m1
JOIN monthly m2
  ON m1.month = m2.month AND m1.year = 2023 AND m2.year = 2024
ORDER BY m1.month;


-- ── KPI 7: Customer Segmentation by Spend Band ───────────────────────────────
WITH customer_revenue AS (
    SELECT
        customer_id,
        customer_name,
        customer_type,
        ROUND(SUM(net_amount),2) AS total_revenue
    FROM fact_sales
    GROUP BY customer_id, customer_name, customer_type
)
SELECT
    CASE
        WHEN total_revenue >= 500000 THEN 'Platinum (≥5L)'
        WHEN total_revenue >= 200000 THEN 'Gold (2L-5L)'
        WHEN total_revenue >= 100000 THEN 'Silver (1L-2L)'
        WHEN total_revenue >= 50000  THEN 'Bronze (50K-1L)'
        ELSE                              'Standard (<50K)'
    END                                     AS customer_segment,
    COUNT(*)                                AS customer_count,
    ROUND(SUM(total_revenue),2)             AS segment_revenue,
    ROUND(AVG(total_revenue),2)             AS avg_customer_revenue,
    ROUND(SUM(total_revenue) * 100.0
          / SUM(SUM(total_revenue)) OVER (), 2) AS revenue_share_pct
FROM customer_revenue
GROUP BY 1
ORDER BY segment_revenue DESC;
