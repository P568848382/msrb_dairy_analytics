
--07 create datawarehouse(dw) dimensions · SQL
-- ═══════════════════════════════════════════════════════════════════════════
-- FILE   : 07_create_dw_dimensions.sql
-- LAYER  : 3 (part B) — Data Warehouse, Dimension Tables
-- RUNS ON: msrb_automation_dw, schema = dw
-- ═══════════════════════════════════════════════════════════════════════════
 
-- WHY a date dimension exists at all, instead of just using the raw date
-- column on every fact table: every BI tool needs to slice by "month name",
-- "quarter", "financial year", "is weekend" etc. Computing these with a
-- function every time a report runs is wasteful and inconsistent — build
-- the calendar ONCE, as data, and join to it.
-- date_key is an INT in YYYYMMDD form (e.g. 20230401) — a deliberate,
-- readable surrogate key convention very common in real warehouses,
-- because it sorts correctly AND is human-readable in ad-hoc queries.
CREATE TABLE dw.dim_date (
    date_key       INT PRIMARY KEY,
    full_date      DATE UNIQUE NOT NULL,
    day_of_week    VARCHAR(12),
    day_num        INT,
    month_num      INT,
    month_name     VARCHAR(12),
    quarter        VARCHAR(4),
    year           INT,
    financial_year VARCHAR(10),
    is_weekend     BOOLEAN,
    season         VARCHAR(10)
);
 
-- Populate it by generating every date across your business's actual range
-- (2023-04-01 to 2025-03-31, per your DATE_START/DATE_END constants) plus
-- a small buffer forward, so new daily data always has a matching date_key
-- waiting for it — you don't want to regenerate this table every day.
INSERT INTO dw.dim_date (date_key, full_date, day_of_week, day_num, month_num,
                          month_name, quarter, year, financial_year, is_weekend,season)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    d,
    TO_CHAR(d, 'FMDay'),
    EXTRACT(DAY FROM d)::INT,
    EXTRACT(MONTH FROM d)::INT,
    TO_CHAR(d, 'FMMonth'),
    'Q' || EXTRACT(QUARTER FROM d)::INT,
    EXTRACT(YEAR FROM d)::INT,
    CASE WHEN EXTRACT(MONTH FROM d) >= 4
         THEN 'FY' || EXTRACT(YEAR FROM d)::INT || '-' || RIGHT((EXTRACT(YEAR FROM d)::INT + 1)::TEXT, 2)
         ELSE 'FY' || (EXTRACT(YEAR FROM d)::INT - 1) || '-' || RIGHT(EXTRACT(YEAR FROM d)::TEXT, 2)
    END,
    EXTRACT(ISODOW FROM d) IN (6, 7),
    CASE
        WHEN EXTRACT(MONTH FROM d) IN (3,4,5)   THEN 'Summer'
        WHEN EXTRACT(MONTH FROM d) IN (6,7,8,9) THEN 'Monsoon'
        WHEN EXTRACT(MONTH FROM d) IN (10,11)   THEN 'Autumn'
        ELSE 'Winter'
    END     as season
FROM generate_series('2023-04-01'::date, '2025-12-31'::date, '1 day') d;
-- NOTE: extending to 2025-12-31 (beyond your data's 2025-03-31 end) means
-- when your team's daily entries push past March, dim_date already has
-- matching rows — no date-dimension maintenance needed for months.
 
-- ── DIM_CUSTOMER ─────────────────────────────────────────────────────────
-- Pulled as DISTINCT from staging.fact_sales, because customer master data
-- isn't a separate ERP export in your project — it's embedded in every
-- sales row. This is common when a company doesn't have a dedicated
-- CRM/master-data system feeding a clean customer list separately.
drop TABLE if EXISTS dw.dim_customer;
drop TABLE if EXISTS dw.dim_product;
drop table if EXISTS dw.dim_route;
CREATE TABLE dw.dim_customer (
    customer_id    VARCHAR(10) PRIMARY KEY,
    customer_name  VARCHAR(80),
    customer_type  VARCHAR(30)
);
 
INSERT INTO dw.dim_customer (customer_id, customer_name, customer_type)
SELECT DISTINCT customer_id, customer_name, customer_type
FROM staging.fact_sales;
 
-- ── DIM_PRODUCT ──────────────────────────────────────────────────────────
CREATE TABLE dw.dim_product (
    product_id     VARCHAR(10) PRIMARY KEY,
    product_name   VARCHAR(60),
    category       VARCHAR(30),
    unit           VARCHAR(15)
);
 
INSERT INTO dw.dim_product (product_id, product_name, category, unit)
SELECT DISTINCT product_id, product_name, category, unit
FROM staging.fact_sales;
 
-- ── DIM_ROUTE ────────────────────────────────────────────────────────────
CREATE TABLE dw.dim_route (
    route_id       VARCHAR(5) PRIMARY KEY,
    route_name     VARCHAR(60)
);
 
INSERT INTO dw.dim_route (route_id, route_name)
SELECT DISTINCT route_id, route_name
FROM staging.fact_sales;
 
-- ── Verification: row counts ────────────────────────────────────────────
SELECT 'dim_date' AS table_name, COUNT(*) FROM dw.dim_date
UNION ALL SELECT 'dim_customer', COUNT(*) FROM dw.dim_customer
UNION ALL SELECT 'dim_product', COUNT(*) FROM dw.dim_product
UNION ALL SELECT 'dim_route', COUNT(*) FROM dw.dim_route;
