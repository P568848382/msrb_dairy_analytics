
-- ══════════════════════════════════════════════════════════════════════════
-- FILE    : 09_dw_views_and_materialized_views.sql
-- PROJECT : MSRB SONS DAIRY — Data Warehouse Layer
-- PURPOSE : Views (always-live, joined) and Materialized Views (pre-computed,
--           refreshed on schedule) sitting on top of dw.fact_* + dw.dim_*.
--           This completes the diagram's "Data Warehouse" box annotation:
--           Stored Procedure / Materialized View / View (Facts & Dimensions).
-- ═══════════════════════════════════════════════════════════════════════════
 
-- ═══════════════════════════════════════════════════════════════════════════
-- VIEWS:-Views (VIEW): The Real-Time Security & Logic Abstraction Layer (Zero Storage)
-- Always run live against current fact/dim data. Use these when
-- freshness matters more than speed, or when the result set is small enough
-- that re-computing it every time costs nothing.
-- ═══════════════════════════════════════════════════════════════════════════
 
-- Row-level sales detail with every dimension joined in — this is what a
-- BI tool would query directly for drill-through/detail-level reporting.
CREATE OR REPLACE VIEW dw.vw_sales_detail AS
SELECT
    fs.sale_id, fs.date_key, dd.day_of_week, dd.financial_year, dd.quarter,
    c.customer_id, c.customer_name, c.customer_type,
    r.route_id, r.route_name,
    p.product_id, p.product_name, p.category,
    fs.quantity, fs.unit_price, fs.gross_amount, fs.discount, fs.net_amount,
    fs.payment_mode, fs.revenue_band
FROM dw.fact_sales fs
JOIN dw.dim_date dd     ON fs.date_key = dd.date_key
JOIN dw.dim_customer c  ON fs.customer_id = c.customer_id
JOIN dw.dim_route r     ON fs.route_id = r.route_id
JOIN dw.dim_product p   ON fs.product_id = p.product_id;
 
-- Row-level accounts detail — for receivables drill-through
CREATE OR REPLACE VIEW dw.vw_accounts_detail AS
SELECT
    fa.transaction_id, fa.date_key, fa.due_date, fa.payment_date,
    c.customer_id, c.customer_name, c.customer_type,
    fa.invoice_amount, fa.amount_paid, fa.outstanding_balance,
    fa.payment_status, fa.aging_bucket, fa.days_overdue, fa.collection_efficiency_pct
FROM dw.fact_accounts fa
JOIN dw.dim_customer c ON fa.customer_id = c.customer_id;
-- ═══════════════════════════════════════════════════════════════════════════
-- MATERIALIZED VIEWS — pre-computed and physically stored. Use these for
-- aggregations that scan the FULL fact table and would otherwise be
-- recomputed on every dashboard click. Refreshed on a schedule (nightly),
-- not on every query — trading a little staleness for a lot of speed.
-- ═══════════════════════════════════════════════════════════════════════════
 
-- Monthly sales summary — scans all 54,469 sales rows to aggregate by month.
-- WHY materialized, not a view: every Power BI/Tableau dashboard opening
-- would otherwise re-scan and re-group 54K rows on every interaction.
CREATE MATERIALIZED VIEW dw.mv_monthly_sales_summary AS
SELECT
    dd.financial_year, dd.year,dd.month_num, dd.month_name,
    COUNT(*) AS total_transactions,
    SUM(fs.quantity) AS total_quantity,
    SUM(fs.gross_amount) AS gross_revenue,
    SUM(fs.discount) AS total_discount,
    SUM(fs.net_amount) AS net_revenue
FROM dw.fact_sales fs
JOIN dw.dim_date dd ON fs.date_key = dd.date_key
GROUP BY dd.financial_year, dd.year,dd.month_num,dd.month_name
ORDER BY dd.year, dd.month_num;
-- Receivables aging summary — scans all 2,879 accounts rows and groups by
-- aging bucket. This is exactly the KPI your accounts cleaning log
-- highlighted (400 overdue, 332 in the 90+ day bucket) — pre-computed here
-- so a Finance dashboard tile loads instantly instead of re-aggregating.
CREATE MATERIALIZED VIEW dw.mv_receivables_aging_summary AS
SELECT
    aging_bucket,
    COUNT(*) AS invoice_count,
    COUNT(DISTINCT customer_id) AS customers_affected,
    SUM(outstanding_balance) AS total_outstanding,
    ROUND(SUM(outstanding_balance) / SUM(SUM(outstanding_balance)) OVER () * 100, 2) AS pct_of_total_outstanding
FROM dw.fact_accounts
WHERE payment_status = 'OverDue'
GROUP BY aging_bucket;
 
-- Product-level inventory risk summary — scans all 7,512 inventory rows.
CREATE MATERIALIZED VIEW dw.mv_inventory_risk_summary AS
SELECT
    p.product_id, p.product_name, p.category, fi.shelf_life_days,
    COUNT(*) AS days_tracked,
    SUM(CASE WHEN fi.shelf_life_risk = 'At Risk' THEN 1 ELSE 0 END) AS days_at_risk,
    ROUND(100.0 * SUM(CASE WHEN fi.shelf_life_risk = 'At Risk' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_days_at_risk,
    SUM(CASE WHEN fi.stock_status = 'Stockout' THEN 1 ELSE 0 END) AS stockout_days
FROM dw.fact_inventory fi
JOIN dw.dim_product p ON fi.product_id = p.product_id
GROUP BY p.product_id, p.product_name, p.category, fi.shelf_life_days
ORDER BY pct_days_at_risk DESC;
-- ── Refresh procedure — the ADF "Stored Procedure Activity" that a nightly
-- Schedule Trigger would call right after run_full_warehouse_load() succeeds.
CREATE OR REPLACE PROCEDURE dw.refresh_materialized_views()
LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW dw.mv_monthly_sales_summary;
    REFRESH MATERIALIZED VIEW dw.mv_receivables_aging_summary;
    REFRESH MATERIALIZED VIEW dw.mv_inventory_risk_summary;
END;
$$;
 
CALL dw.refresh_materialized_views();
    select * from dw.mv_inventory_risk_summary;

 
------------------------------------------
--more advance concept
-- Add Unique Indexes for Zero-Downtime Refresh:-In a live production environment, running REFRESH MATERIALIZED VIEW without a unique index
--  places an exclusive read lock on the view, temporarily blocking Power BI users while the data refreshes.
-- To enable CONCURRENTLY (zero-downtime background refresh), create a unique index on each Materialized View:
-- 1. Create Unique Indexes
create unique index if not exists idx_mv__sales_month
on dw.mv_monthly_sales_summary(financial_year,year,month_name,month_num);

create unique index if not exists idx_mv_rec_aging
on dw.mv_receivables_aging_summary(aging_bucket);

create unique index if not exists idx_mv_inv_risk
on dw.mv_inventory_risk_summary(product_id);
-- 2. Update the Procedure to Refresh Concurrently
create or replace procedure dw.refresh_materialized_views()
language plpgsql as $$
begin 
    refresh materialized view concurrently dw.mv_monthly_sales_summary;
    refresh materialized view concurrently dw.mv_receivables_aging_summary;
    refresh materialized view concurrently dw.mv_inventory_risk_summary;
end;
$$;
call dw.refresh_materialized_views();
select * from dw.mv_monthly_sales_summary;
select * from dw.mv_receivables_aging_summary;
select * from dw.mv_inventory_risk_summary;


-- views
select * from dw.vw_sales_detail;
select * from dw.vw_accounts_detail;
