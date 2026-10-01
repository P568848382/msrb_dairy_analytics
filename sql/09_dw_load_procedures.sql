-- ═══════════════════════════════════════════════════════════════════════════
-- FILE   : 09_dw_load_procedures.sql
-- LAYER  : 3 (part B) — Data Warehouse, Load Procedures
-- RUNS ON: msrb_automation_dw
-- ═══════════════════════════════════════════════════════════════════════════
-- Each procedure does the SAME 3 things, for a different source:
--   1. Cast staging's TEXT columns into their real types (date, numeric, etc.)
--   2. Compute date_key by formatting the date as YYYYMMDD, to join dim_date
--   3. INSERT ... ON CONFLICT (upsert) into the dw fact table
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE PROCEDURE dw.load_fact_sales()
LANGUAGE plpgsql as $$
BEGIN
    INSERT INTO dw.fact_sales(
        sale_id,date_key,customer_id,product_id,route_id,
        quantity,unit_price,gross_amount,discount,net_amount,
        payment_mode,invoice_number,day_of_week,is_weekend,
        financial_year,revenue_band,data_quality_flag
    )
SELECT  
    s.sale_id,
    TO_CHAR(s.date::date, 'YYYYMMDD')::INT,
    s.customer_id, s.product_id, s.route_id,
    s.quantity, s.unit_price, s.gross_amount, s.discount, s.net_amount,
    s.payment_mode, s.invoice_number, s.day_of_week, s.is_weekend::boolean,
    s.financial_year, s.revenue_band, s.data_quality_flag
FROM   staging.fact_sales s
ON CONFLICT(sale_id) DO UPDATE SET 
    quantity    =   EXCLUDED.quantity,
    net_amount  =   EXCLUDED.net_amount,
    data_quality_flag   =   EXCLUDED.data_quality_flag;
RAISE NOTICE    'dw.fatct_sales:  % total rows after upsert',(SELECT COUNT(*) FROM dw.fact_sales);
END;
$$;

CREATE OR REPLACE PROCEDURE dw.load_fact_production()
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO dw.fact_production (
        production_id, date_key, category, shift, batch_number,
        planned_qty, actual_qty, wastage_qty, net_produced_qty, raw_milk_used_l,
        production_efficiency_pct, wastage_rate_pct, day_of_week, financial_year,
        efficiency_band, data_quality_flag
    )
    SELECT
        s.production_id,
        TO_CHAR(s.date::date, 'YYYYMMDD')::INT,
        s.category, s.shift, s.batch_number,
        s.planned_qty, s.actual_qty, s.wastage_qty, s.net_produced_qty, s."raw_milk_used_L",
        s."production_efficiency_%", s."wastage_rate_%", s.day_of_week, s.financial_year,
        s.efficiency_band, s.data_quality_flag
    FROM staging.fact_production s
    ON CONFLICT (production_id) DO UPDATE SET
        actual_qty = EXCLUDED.actual_qty,
        production_efficiency_pct = EXCLUDED.production_efficiency_pct,
        data_quality_flag = EXCLUDED.data_quality_flag;
 
    RAISE NOTICE 'dw.fact_production: % total rows after upsert', (SELECT COUNT(*) FROM dw.fact_production);
END;
$$;
 
CREATE OR REPLACE PROCEDURE dw.load_fact_inventory()
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO dw.fact_inventory (
        inventory_id, date_key, product_id, opening_stock, received_qty,
        dispatched_qty, closing_stock, reorder_level, stock_status,
        day_of_week, financial_year, shelf_life_days, days_of_stock, shelf_life_risk
    )
    SELECT
        s.inventory_id,
        TO_CHAR(s.date::date, 'YYYYMMDD')::INT,
        s.product_id, s.opening_stock, s.received_qty,
        s.dispatched_qty, s.closing_stock, s.reorder_level, s.stock_status,
        s.day_of_week, s.financial_year, s.shelf_life_days, s.days_of_stock, s.shelf_life_risk
    FROM staging.fact_inventory s
    ON CONFLICT (inventory_id) DO UPDATE SET
        closing_stock = EXCLUDED.closing_stock,
        stock_status = EXCLUDED.stock_status,
        shelf_life_risk = EXCLUDED.shelf_life_risk;
 
    RAISE NOTICE 'dw.fact_inventory: % total rows after upsert', (SELECT COUNT(*) FROM dw.fact_inventory);
END;
$$;
 
CREATE OR REPLACE PROCEDURE dw.load_fact_accounts()
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO dw.fact_accounts (
        transaction_id, date_key, customer_id, invoice_number, due_date, payment_date,
        invoice_amount, amount_paid, outstanding_balance, days_to_payment,
        payment_status, credit_days, financial_year, days_overdue,
        aging_bucket, collection_efficiency_pct
    )
    SELECT
        s.transaction_id,
        TO_CHAR(s.invoice_date::date, 'YYYYMMDD')::INT,
        s.customer_id, s.invoice_number,
        NULLIF(s.due_date,'')::date, NULLIF(s.payment_date,'')::date,
        s.invoice_amount, s.amount_paid, s.outstanding_balance, s.days_to_payment,
        s.payment_status, s.credit_days, s.financial_year, s.days_overdue,
        s.aging_bucket, s."collection_efficiency_%"
    FROM staging.fact_accounts s
    ON CONFLICT (transaction_id) DO UPDATE SET
        outstanding_balance = EXCLUDED.outstanding_balance,
        payment_status = EXCLUDED.payment_status,
        aging_bucket = EXCLUDED.aging_bucket;
 
    RAISE NOTICE 'dw.fact_accounts: % total rows after upsert', (SELECT COUNT(*) FROM dw.fact_accounts);
END;
$$;
 
-- ── MASTER PROCEDURE ─────────────────────────────────────────────────────
-- This single call is what an ADF "Stored Procedure Activity" node would
-- invoke as one step, right after the staging Copy Data Activity succeeds.
CREATE OR REPLACE PROCEDURE dw.run_full_warehouse_load()
LANGUAGE plpgsql AS $$
BEGIN
    CALL dw.load_fact_sales();
    CALL dw.load_fact_production();
    CALL dw.load_fact_inventory();
    CALL dw.load_fact_accounts();
END;
$$;
 
CALL dw.run_full_warehouse_load();
 
-- ── Verification ─────────────────────────────────────────────────────────
SELECT 'stg_fact_sales' AS table_name, COUNT(*) as total_rows FROM staging.fact_sales
UNION ALL SELECT 'stg_fact_production', COUNT(*) FROM staging.fact_production
UNION ALL SELECT 'stg_fact_inventory', COUNT(*) FROM staging.fact_inventory
UNION ALL SELECT 'stg_fact_accounts', COUNT(*) FROM staging.fact_accounts
UNION ALL SELECT 'fact_sales' ,COUNT(*)  FROM dw.fact_sales
UNION ALL SELECT 'fact_production', COUNT(*) FROM dw.fact_production
UNION ALL SELECT 'fact_inventory', COUNT(*) FROM dw.fact_inventory
UNION ALL SELECT 'fact_accounts', COUNT(*) FROM dw.fact_accounts
UNION ALL SELECT 'dim_date',COUNT(*) FROM dw.dim_date
UNION ALL SELECT 'dim_product',COUNT(*) FROM dw.dim_product
UNION ALL SELECT 'dim_customer',COUNT(*) FROM dw.dim_customer
UNION ALL SELECT 'dim_route', COUNT(*) FROM dw.dim_route;
