-- ═════════════════════════════════════════════════════════════════════════
-- FILE    : staging.sql
-- PROJECT : MSRB SONS DAIRY PRODUCT PVT. LTD. — Data Warehouse
-- AUTHOR  : Pradeep Kumar
-- PURPOSE : the NEW layer sitting between cleaning and the star-schema warehouse
--           Run this to after running 06_load_to_postgres.py to confirm the data
-- ═══════════════════════════════════════════════════════════════════════════
select count(*) as total_rows from staging.fact_sales
UNION all
select count(*) from staging.fact_inventory
UNION all 
select count(*) from staging.fact_production
UNION all 
select count(*) from staging.fact_accounts;
