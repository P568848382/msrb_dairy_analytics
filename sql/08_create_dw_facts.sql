-- ═══════════════════════════════════════════════════════════════════════════
-- FILE   : 08_create_dw_facts.sql
-- LAYER  : 3 (part B) — Data Warehouse, Fact Tables
-- RUNS ON: msrb_automation_dw, schema = dw
-- ═══════════════════════════════════════════════════════════════════════════

-- ── FACT_SALES ───────────────────────────────────────────────────────────
-- Grain (the single most important design decision for any fact table —
-- "what does ONE ROW represent?"): one row = one sale_id = one line item
-- on one invoice. Every measure column (quantity, net_amount, etc.) is
-- only meaningful at THIS grain — never mix grains in one fact table.
drop table if exists dw.fact_sales CASCADE;
drop TABLE if EXISTS dw.fact_inventory CASCADE;
DROP TABLE IF EXISTS dw.fact_production CASCADE;
DROP TABLE IF EXISTS dw.fact_accounts CASCADE;
CREATE TABLE dw.fact_sales (
    sale_id            VARCHAR(15) PRIMARY KEY,
    date_key           INT REFERENCES dw.dim_date(date_key),
    customer_id        VARCHAR(10) REFERENCES dw.dim_customer(customer_id),
    product_id         VARCHAR(10) REFERENCES dw.dim_product(product_id),
    route_id           VARCHAR(5)  REFERENCES dw.dim_route(route_id),
    quantity           NUMERIC(10,2),
    unit_price         NUMERIC(8,2),
    gross_amount       NUMERIC(12,2),
    discount           NUMERIC(10,2),
    net_amount         NUMERIC(12,2),
    payment_mode       VARCHAR(20),
    invoice_number     VARCHAR(20),
    day_of_week        VARCHAR(12),
    is_weekend         BOOLEAN,
    financial_year     VARCHAR(10),
    revenue_band       VARCHAR(15),
    data_quality_flag  VARCHAR(30)
);

-- ── FACT_PRODUCTION ──────────────────────────────────────────────────────
-- Grain: one row = one production_id = one batch, one shift, one category,
-- on one day. Note there's no customer/product/route here — production
-- doesn't relate to customers, it relates to date + category + shift.
CREATE TABLE dw.fact_production (
    production_id           VARCHAR(15) PRIMARY KEY,
    date_key                 INT REFERENCES dw.dim_date(date_key),
    category                 VARCHAR(30),
    shift                     VARCHAR(10),
    batch_number              VARCHAR(30),
    planned_qty               NUMERIC(10,2),
    actual_qty                NUMERIC(10,2),
    wastage_qty                NUMERIC(10,2),
    net_produced_qty           NUMERIC(10,2),
    raw_milk_used_l             NUMERIC(10,2),
    production_efficiency_pct    NUMERIC(6,2),
    wastage_rate_pct              NUMERIC(6,2),
    day_of_week                    VARCHAR(12),
    financial_year                  VARCHAR(10),
    efficiency_band                  VARCHAR(30),
    data_quality_flag                 VARCHAR(30)
);

-- ── FACT_INVENTORY ───────────────────────────────────────────────────────
-- Grain: one row = one inventory_id = one product's stock snapshot on one day.
CREATE TABLE dw.fact_inventory (
    inventory_id       VARCHAR(15) PRIMARY KEY,
    date_key           INT REFERENCES dw.dim_date(date_key),
    product_id         VARCHAR(10) REFERENCES dw.dim_product(product_id),
    opening_stock      NUMERIC(10,2),
    received_qty       NUMERIC(10,2),
    dispatched_qty     NUMERIC(10,2),
    closing_stock      NUMERIC(10,2),
    reorder_level      NUMERIC(10,2),
    stock_status       VARCHAR(20),
    day_of_week        VARCHAR(12),
    financial_year     VARCHAR(10),
    shelf_life_days    NUMERIC(6,2),
    days_of_stock      NUMERIC(8,2),
    shelf_life_risk    VARCHAR(10)
);

-- ── FACT_ACCOUNTS ────────────────────────────────────────────────────────
-- Grain: one row = one transaction_id = one invoice.
-- Note due_date/payment_date are kept as their OWN date columns, not
-- joined to dim_date — because an invoice has THREE meaningful dates
-- (invoice, due, payment), and joining all three to one shared dim_date
-- would need three separate joins/aliases. For this fact table we keep
-- invoice date as the "primary" date_key join and leave due/payment as
-- plain DATE columns — a legitimate, common warehouse pattern called a
-- "role-playing dimension" problem; the full textbook fix (3 date-key
-- columns, each joined to its own alias of dim_date) is more than this
-- fact table's actual reporting needs require.
CREATE TABLE dw.fact_accounts (
    transaction_id           VARCHAR(15) PRIMARY KEY,
    date_key                  INT REFERENCES dw.dim_date(date_key),  -- invoice_date
    customer_id                VARCHAR(10) REFERENCES dw.dim_customer(customer_id),
    invoice_number               VARCHAR(20),
    due_date                       DATE,
    payment_date                     DATE,
    invoice_amount                     NUMERIC(12,2),
    amount_paid                          NUMERIC(12,2),
    outstanding_balance                    NUMERIC(12,2),
    days_to_payment                          NUMERIC(6,2),
    payment_status                             VARCHAR(20),
    credit_days                                  NUMERIC(6,2),
    financial_year                                 VARCHAR(10),
    days_overdue                                     NUMERIC(6,2),
    aging_bucket                                       VARCHAR(20),
    collection_efficiency_pct                            NUMERIC(6,2)
);

-- ── Verification ─────────────────────────────────────────────────────────
SELECT table_name FROM information_schema.tables WHERE table_schema = 'dw' ORDER BY table_name;