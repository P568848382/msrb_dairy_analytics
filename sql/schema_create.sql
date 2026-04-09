-- ═══════════════════════════════════════════════════════════════════════════
-- FILE    : schema_create.sql
-- PROJECT : MSRB SONS DAIRY PRODUCT PVT. LTD. — Data Warehouse
-- AUTHOR  : Pradeep Kumar
-- PURPOSE : Creates the full star schema in PostgreSQL
--           Run this ONCE before running 06_load_to_postgres.py
-- ═══════════════════════════════════════════════════════════════════════════

-- Step 0: Create database (run this in psql or pgAdmin as superuser)
-- CREATE DATABASE msrb_dairy_dw;
-- \c msrb_dairy_dw

-- ───────────────────────────────────────────────────────────────────────────
-- DROP EXISTING TABLES (safe re-run)
-- ───────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS fact_accounts   CASCADE;
DROP TABLE IF EXISTS fact_inventory  CASCADE;
DROP TABLE IF EXISTS fact_production CASCADE;
DROP TABLE IF EXISTS fact_sales      CASCADE;
DROP TABLE IF EXISTS dim_date        CASCADE;
DROP TABLE IF EXISTS dim_customer    CASCADE;
DROP TABLE IF EXISTS dim_product     CASCADE;
DROP TABLE IF EXISTS dim_route       CASCADE;

-- ═══════════════════════════════════════════════════════════════════════════
-- DIMENSION TABLES
-- ═══════════════════════════════════════════════════════════════════════════

-- ── dim_date ────────────────────────────────────────────────────────────────
CREATE TABLE dim_date (
    date_key        DATE        PRIMARY KEY,
    day_of_week     VARCHAR(12),
    day_number      SMALLINT,
    week_number     SMALLINT,
    month_number    SMALLINT,
    month_name      VARCHAR(12),
    quarter         VARCHAR(4),
    year            SMALLINT,
    financial_year  VARCHAR(10),   -- e.g. FY2023-24
    is_weekend      BOOLEAN,
    is_month_end    BOOLEAN,
    season          VARCHAR(10)    -- Summer / Monsoon / Winter / Spring
);

-- Populate dim_date for April 2023 – March 2025
INSERT INTO dim_date
SELECT
    d::DATE                                                          AS date_key,
    TO_CHAR(d, 'Day')                                               AS day_of_week,
    EXTRACT(DOW  FROM d)::SMALLINT                                  AS day_number,
    EXTRACT(WEEK FROM d)::SMALLINT                                  AS week_number,
    EXTRACT(MONTH FROM d)::SMALLINT                                 AS month_number,
    TO_CHAR(d, 'Month')                                             AS month_name,
    'Q' || CEIL(EXTRACT(MONTH FROM d)/3.0)::TEXT                   AS quarter,
    EXTRACT(YEAR FROM d)::SMALLINT                                  AS year,
    CASE WHEN EXTRACT(MONTH FROM d) >= 4
         THEN 'FY' || EXTRACT(YEAR FROM d)::TEXT || '-'
              || RIGHT(CAST(EXTRACT(YEAR FROM d) + 1 AS TEXT), 2)
         ELSE 'FY' || (EXTRACT(YEAR FROM d) - 1)::TEXT || '-'
              || RIGHT(CAST(EXTRACT(YEAR FROM d) AS TEXT), 2)
    END                                                             AS financial_year,
    EXTRACT(DOW FROM d) IN (0, 6)                                  AS is_weekend,
    d = DATE_TRUNC('month', d) + INTERVAL '1 month' - INTERVAL '1 day' AS is_month_end,
    CASE
        WHEN EXTRACT(MONTH FROM d) IN (3,4,5)   THEN 'Summer'
        WHEN EXTRACT(MONTH FROM d) IN (6,7,8,9) THEN 'Monsoon'
        WHEN EXTRACT(MONTH FROM d) IN (10,11)   THEN 'Autumn'
        ELSE 'Winter'
    END                                                             AS season
FROM GENERATE_SERIES('2023-04-01'::DATE, '2025-03-31'::DATE, '1 day') d;

-- ── dim_product ─────────────────────────────────────────────────────────────
CREATE TABLE dim_product (
    product_id      VARCHAR(10)  PRIMARY KEY,
    product_name    VARCHAR(60)  NOT NULL,
    category        VARCHAR(30)  NOT NULL,
    unit            VARCHAR(15),
    standard_price  NUMERIC(8,2),
    cost_price      NUMERIC(8,2),
    shelf_life_days SMALLINT,
    is_active       BOOLEAN      DEFAULT TRUE
);

INSERT INTO dim_product VALUES
    ('P01', 'Milk Bulk 1L',     'Milk Bulk',   'Litre',   42.00, 38.00,   2, TRUE),
    ('P02', 'Milk Packet 500ml','Milk Packet', 'Packet',  24.00, 21.00,   3, TRUE),
    ('P03', 'Milk Packet 200ml','Milk Packet', 'Packet',  11.00,  9.50,   3, TRUE),
    ('P04', 'Paneer 200g',      'Paneer',      'Piece',   70.00, 58.00,   7, TRUE),
    ('P05', 'Paneer 500g',      'Paneer',      'Piece',  165.00,138.00,   7, TRUE),
    ('P06', 'Curd 400g',        'Curd',        'Piece',   36.00, 29.00,   5, TRUE),
    ('P07', 'Curd 1kg',         'Curd',        'Piece',   82.00, 68.00,   5, TRUE),
    ('P08', 'Ghee 500ml',       'Ghee',        'Piece',  310.00,265.00, 180, TRUE),
    ('P09', 'Ghee 1L',          'Ghee',        'Piece',  595.00,510.00, 180, TRUE),
    ('P10', 'Butter 100g',      'Butter',      'Piece',   58.00, 48.00,  90, TRUE),
    ('P11', 'Butter 500g',      'Butter',      'Piece',  265.00,220.00,  90, TRUE),
    ('P12', 'Cream 200ml',      'Cream',       'Piece',   75.00, 62.00,  10, TRUE);

-- ── dim_route ────────────────────────────────────────────────────────────────
CREATE TABLE dim_route (
    route_id        VARCHAR(5)   PRIMARY KEY,
    route_name      VARCHAR(60)  NOT NULL,
    area            VARCHAR(40),
    city            VARCHAR(30)  DEFAULT 'Rohtak',
    state           VARCHAR(20)  DEFAULT 'Haryana',
    is_active       BOOLEAN      DEFAULT TRUE
);

INSERT INTO dim_route VALUES
    ('R01','Sector-7 Route',       'Sector-7',        'Rohtak','Haryana',TRUE),
    ('R02','Civil Lines Route',    'Civil Lines',      'Rohtak','Haryana',TRUE),
    ('R03','Model Town Route',     'Model Town',       'Rohtak','Haryana',TRUE),
    ('R04','Sadar Bazar Route',    'Sadar Bazar',      'Rohtak','Haryana',TRUE),
    ('R05','Railway Colony Route', 'Railway Colony',   'Rohtak','Haryana',TRUE),
    ('R06','Industrial Area Route','Industrial Area',  'Rohtak','Haryana',TRUE),
    ('R07','Old City Route',       'Old City',         'Rohtak','Haryana',TRUE),
    ('R08','Bypass Road Route',    'Bypass Road',      'Rohtak','Haryana',TRUE);

-- ── dim_customer ─────────────────────────────────────────────────────────────
CREATE TABLE dim_customer (
    customer_id     VARCHAR(10)  PRIMARY KEY,
    customer_name   VARCHAR(80)  NOT NULL,
    customer_type   VARCHAR(30),
    route_id        VARCHAR(5)   REFERENCES dim_route(route_id),
    city            VARCHAR(30),
    state           VARCHAR(20),
    credit_days     SMALLINT,
    credit_limit    NUMERIC(10,2),
    is_active       BOOLEAN      DEFAULT TRUE
);

INSERT INTO dim_customer VALUES
    ('C001', 'Rekha Jain',          'Retailer',         'R05', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C002', 'Jignesh Patel',       'Hotel/Restaurant', 'R02', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C003', 'Vikas Tiwari',        'Hotel/Restaurant', 'R03', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C004', 'Harish Mishra',       'Wholesaler',       'R04', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C005', 'Ajay Mehta',          'Retailer',         'R07', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C006', 'Rajesh Mittal',       'Retailer',         'R04', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C007', 'Lokesh Trivedi',      'Hotel/Restaurant', 'R01', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C008', 'Ashok Nair',          'Retailer',         'R01', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C009', 'Rakesh Agarwal',      'Institutional',    'R07', 'Rohtak', 'Haryana', 45, 300000.00, TRUE),
    ('C010', 'Yogesh Goyal',        'Retailer',         'R04', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C011', 'Dinesh Yadav',        'Direct Consumer',  'R06', 'Rohtak', 'Haryana',  0,  25000.00, TRUE),
    ('C012', 'Manoj Iyer',          'Retailer',         'R08', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C013', 'Girish Thakur',       'Retailer',         'R08', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C014', 'Deepak Dubey',        'Retailer',         'R03', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C015', 'Nitesh Kumar',        'Retailer',         'R05', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C016', 'Umesh Chauhan',       'Hotel/Restaurant', 'R07', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C017', 'Kapil Joshi',         'Institutional',    'R07', 'Rohtak', 'Haryana', 45, 300000.00, TRUE),
    ('C018', 'Mohit Shukla',        'Retailer',         'R03', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C019', 'Kamlesh Shah',        'Wholesaler',       'R02', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C020', 'Pramod Pandey',       'Hotel/Restaurant', 'R02', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C021', 'Paresh Saxena',       'Retailer',         'R03', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C022', 'Pooja Gupta',         'Hotel/Restaurant', 'R07', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C023', 'Meena Srivastava',    'Wholesaler',       'R07', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C024', 'Santosh Singh',       'Retailer',         'R08', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C025', 'Amit Garg',           'Wholesaler',       'R01', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C026', 'Ramesh Bansal',       'Hotel/Restaurant', 'R02', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C027', 'Neha Rajput',         'Hotel/Restaurant', 'R05', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C028', 'Kavita Verma',        'Hotel/Restaurant', 'R06', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C029', 'Lalit Rao',           'Retailer',         'R07', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C030', 'Sunil Sharma',        'Retailer',         'R01', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C031', 'Bhavesh Jain',        'Direct Consumer',  'R05', 'Rohtak', 'Haryana',  0,  25000.00, TRUE),
    ('C032', 'Sumit Patel',         'Direct Consumer',  'R03', 'Rohtak', 'Haryana',  0,  25000.00, TRUE),
    ('C033', 'Mahesh Tiwari',       'Wholesaler',       'R02', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C034', 'Mukesh Mishra',       'Institutional',    'R05', 'Rohtak', 'Haryana', 45, 300000.00, TRUE),
    ('C035', 'Ganesh Mehta',        'Institutional',    'R04', 'Rohtak', 'Haryana', 45, 300000.00, TRUE),
    ('C036', 'Alpesh Mittal',       'Retailer',         'R03', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C037', 'Naresh Trivedi',      'Wholesaler',       'R01', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C038', 'Sanjay Nair',         'Wholesaler',       'R08', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C039', 'Anil Agarwal',        'Retailer',         'R06', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C040', 'Sunita Goyal',        'Institutional',    'R05', 'Rohtak', 'Haryana', 45, 300000.00, TRUE),
    ('C041', 'Anita Yadav',         'Retailer',         'R04', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C042', 'Suresh Iyer',         'Institutional',    'R02', 'Rohtak', 'Haryana', 45, 300000.00, TRUE),
    ('C043', 'Vijay Thakur',        'Retailer',         'R08', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C044', 'Rohit Dubey',         'Institutional',    'R03', 'Rohtak', 'Haryana', 45, 300000.00, TRUE),
    ('C045', 'Priya Kumar',         'Retailer',         'R08', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C046', 'Rekha Chauhan',       'Direct Consumer',  'R03', 'Rohtak', 'Haryana',  0,  25000.00, TRUE),
    ('C047', 'Jignesh Joshi',       'Retailer',         'R07', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C048', 'Vikas Shukla',        'Direct Consumer',  'R04', 'Rohtak', 'Haryana',  0,  25000.00, TRUE),
    ('C049', 'Harish Shah',         'Hotel/Restaurant', 'R07', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C050', 'Ajay Pandey',         'Direct Consumer',  'R06', 'Rohtak', 'Haryana',  0,  25000.00, TRUE),
    ('C051', 'Rajesh Saxena',       'Wholesaler',       'R08', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C052', 'Lokesh Gupta',        'Retailer',         'R04', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C053', 'Ashok Srivastava',    'Retailer',         'R01', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C054', 'Rakesh Singh',        'Wholesaler',       'R04', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C055', 'Yogesh Garg',         'Wholesaler',       'R01', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C056', 'Dinesh Bansal',       'Retailer',         'R01', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C057', 'Manoj Rajput',        'Retailer',         'R01', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C058', 'Girish Verma',        'Institutional',    'R02', 'Rohtak', 'Haryana', 45, 300000.00, TRUE),
    ('C059', 'Deepak Rao',          'Wholesaler',       'R05', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C060', 'Nitesh Sharma',       'Hotel/Restaurant', 'R04', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C061', 'Umesh Jain',          'Wholesaler',       'R08', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C062', 'Kapil Patel',         'Retailer',         'R08', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C063', 'Mohit Tiwari',        'Institutional',    'R04', 'Rohtak', 'Haryana', 45, 300000.00, TRUE),
    ('C064', 'Kamlesh Mishra',      'Retailer',         'R07', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C065', 'Pramod Mehta',        'Retailer',         'R07', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C066', 'Paresh Mittal',       'Wholesaler',       'R01', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C067', 'Pooja Trivedi',       'Hotel/Restaurant', 'R02', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C068', 'Meena Nair',          'Retailer',         'R06', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C069', 'Santosh Agarwal',     'Institutional',    'R02', 'Rohtak', 'Haryana', 45, 300000.00, TRUE),
    ('C070', 'Amit Goyal',          'Retailer',         'R04', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C071', 'Ramesh Yadav',        'Wholesaler',       'R03', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C072', 'Neha Iyer',           'Wholesaler',       'R05', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C073', 'Kavita Thakur',       'Wholesaler',       'R02', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C074', 'Lalit Dubey',         'Wholesaler',       'R02', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C075', 'Sunil Kumar',         'Retailer',         'R01', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C076', 'Bhavesh Chauhan',     'Direct Consumer',  'R04', 'Rohtak', 'Haryana',  0,  25000.00, TRUE),
    ('C077', 'Sumit Joshi',         'Retailer',         'R08', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C078', 'Mahesh Shukla',       'Wholesaler',       'R07', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C079', 'Mukesh Shah',         'Direct Consumer',  'R03', 'Rohtak', 'Haryana',  0,  25000.00, TRUE),
    ('C080', 'Ganesh Pandey',       'Retailer',         'R07', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C081', 'Alpesh Saxena',       'Retailer',         'R08', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C082', 'Naresh Gupta',        'Retailer',         'R08', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C083', 'Sanjay Srivastava',   'Retailer',         'R05', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C084', 'Anil Singh',          'Retailer',         'R01', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C085', 'Sunita Garg',         'Wholesaler',       'R01', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C086', 'Anita Bansal',        'Hotel/Restaurant', 'R01', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C087', 'Suresh Rajput',       'Retailer',         'R08', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C088', 'Vijay Verma',         'Wholesaler',       'R03', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C089', 'Rohit Rao',           'Retailer',         'R02', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C090', 'Priya Sharma',        'Institutional',    'R02', 'Rohtak', 'Haryana', 45, 300000.00, TRUE),
    ('C091', 'Rekha Jain',          'Wholesaler',       'R04', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C092', 'Jignesh Patel',       'Wholesaler',       'R04', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C093', 'Vikas Tiwari',        'Wholesaler',       'R01', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C094', 'Harish Mishra',       'Hotel/Restaurant', 'R07', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C095', 'Ajay Mehta',          'Hotel/Restaurant', 'R06', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C096', 'Rajesh Mittal',       'Direct Consumer',  'R04', 'Rohtak', 'Haryana',  0,  25000.00, TRUE),
    ('C097', 'Lokesh Trivedi',      'Hotel/Restaurant', 'R06', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C098', 'Ashok Nair',          'Retailer',         'R07', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C099', 'Rakesh Agarwal',      'Retailer',         'R05', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C100', 'Yogesh Goyal',        'Wholesaler',       'R02', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C101', 'Dinesh Yadav',        'Retailer',         'R02', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C102', 'Manoj Iyer',          'Retailer',         'R04', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C103', 'Girish Thakur',       'Wholesaler',       'R03', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C104', 'Deepak Dubey',        'Direct Consumer',  'R02', 'Rohtak', 'Haryana',  0,  25000.00, TRUE),
    ('C105', 'Nitesh Kumar',        'Institutional',    'R06', 'Rohtak', 'Haryana', 45, 300000.00, TRUE),
    ('C106', 'Umesh Chauhan',       'Retailer',         'R08', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C107', 'Kapil Joshi',         'Institutional',    'R05', 'Rohtak', 'Haryana', 45, 300000.00, TRUE),
    ('C108', 'Mohit Shukla',        'Hotel/Restaurant', 'R01', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C109', 'Kamlesh Shah',        'Hotel/Restaurant', 'R05', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C110', 'Pramod Pandey',       'Direct Consumer',  'R02', 'Rohtak', 'Haryana',  0,  25000.00, TRUE),
    ('C111', 'Paresh Saxena',       'Direct Consumer',  'R03', 'Rohtak', 'Haryana',  0,  25000.00, TRUE),
    ('C112', 'Pooja Gupta',         'Retailer',         'R02', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C113', 'Meena Srivastava',    'Hotel/Restaurant', 'R03', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C114', 'Santosh Singh',       'Retailer',         'R04', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C115', 'Amit Garg',           'Hotel/Restaurant', 'R04', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C116', 'Ramesh Bansal',       'Hotel/Restaurant', 'R05', 'Rohtak', 'Haryana', 15, 150000.00, TRUE),
    ('C117', 'Neha Rajput',         'Wholesaler',       'R05', 'Rohtak', 'Haryana', 30, 200000.00, TRUE),
    ('C118', 'Kavita Verma',        'Direct Consumer',  'R01', 'Rohtak', 'Haryana',  0,  25000.00, TRUE),
    ('C119', 'Lalit Rao',           'Retailer',         'R07', 'Rohtak', 'Haryana', 15,  75000.00, TRUE),
    ('C120', 'Sunil Sharma',        'Institutional',    'R01', 'Rohtak', 'Haryana', 45, 300000.00, TRUE);

-- ═══════════════════════════════════════════════════════════════════════════
-- FACT TABLES
-- ═══════════════════════════════════════════════════════════════════════════

-- ── fact_sales ───────────────────────────────────────────────────────────────
CREATE TABLE fact_sales (
    sale_id             VARCHAR(15)  PRIMARY KEY,
    date                DATE         NOT NULL,
    year                SMALLINT,
    month               SMALLINT,
    month_name          VARCHAR(12),
    quarter             VARCHAR(4),
    financial_year      VARCHAR(10),
    customer_id         VARCHAR(10),
    customer_name       VARCHAR(80),
    customer_type       VARCHAR(30),
    route_id            VARCHAR(5),
    route_name          VARCHAR(60),
    product_id          VARCHAR(10),
    product_name        VARCHAR(60),
    category            VARCHAR(30),
    unit                VARCHAR(15),
    quantity            NUMERIC(10,2),
    unit_price          NUMERIC(8,2),
    gross_amount        NUMERIC(12,2),
    discount            NUMERIC(10,2),
    net_amount          NUMERIC(12,2),
    payment_mode        VARCHAR(20),
    invoice_number      VARCHAR(20),
    day_of_week         VARCHAR(12),
    is_weekend          BOOLEAN,
    revenue_band        VARCHAR(15),
    data_quality_flag   VARCHAR(30)  DEFAULT 'OK'
);

-- ── fact_production ──────────────────────────────────────────────────────────
CREATE TABLE fact_production (
    production_id               VARCHAR(15)  PRIMARY KEY,
    date                        DATE         NOT NULL,
    year                        SMALLINT,
    month                       SMALLINT,
    month_name                  VARCHAR(12),
    quarter                     VARCHAR(4),
    financial_year              VARCHAR(10),
    category                    VARCHAR(30),
    planned_qty                 NUMERIC(10,2),
    actual_qty                  NUMERIC(10,2),
    wastage_qty                 NUMERIC(10,2),
    net_produced_qty            NUMERIC(10,2),
    raw_milk_used_l             NUMERIC(12,2),
    production_efficiency_pct   NUMERIC(6,2),
    wastage_rate_pct            NUMERIC(6,2),
    shift                       VARCHAR(15),
    batch_number                VARCHAR(30),
    day_of_week                 VARCHAR(12),
    efficiency_band             VARCHAR(25),
    data_quality_flag           VARCHAR(30)  DEFAULT 'OK'
);

-- ── fact_inventory ───────────────────────────────────────────────────────────
CREATE TABLE fact_inventory (
    inventory_id        VARCHAR(15)  PRIMARY KEY,
    date                DATE         NOT NULL,
    year                SMALLINT,
    month               SMALLINT,
    month_name          VARCHAR(12),
    quarter             VARCHAR(4),
    financial_year      VARCHAR(10),
    product_id          VARCHAR(10),
    product_name        VARCHAR(60),
    category            VARCHAR(30),
    opening_stock       NUMERIC(10,2),
    received_qty        NUMERIC(10,2),
    dispatched_qty      NUMERIC(10,2),
    closing_stock       NUMERIC(10,2),
    reorder_level       NUMERIC(8,2),
    stock_status        VARCHAR(15),
    day_of_week         VARCHAR(12),
    shelf_life_days     SMALLINT,
    days_of_stock       NUMERIC(8,1),
    shelf_life_risk     VARCHAR(10)
);

-- ── fact_accounts ────────────────────────────────────────────────────────────
CREATE TABLE fact_accounts (
    transaction_id          VARCHAR(15)  PRIMARY KEY,
    invoice_date            DATE         NOT NULL,
    year                    SMALLINT,
    month                   SMALLINT,
    month_name              VARCHAR(12),
    quarter                 VARCHAR(4),
    financial_year          VARCHAR(10),
    customer_id             VARCHAR(10),
    customer_name           VARCHAR(80),
    customer_type           VARCHAR(30),
    invoice_number          VARCHAR(20),
    due_date                DATE,
    invoice_amount          NUMERIC(12,2),
    amount_paid             NUMERIC(12,2),
    outstanding_balance     NUMERIC(12,2),
    payment_date            DATE,
    days_to_payment         NUMERIC(6,1),
    payment_status          VARCHAR(20),
    credit_days             SMALLINT,
    days_overdue            NUMERIC(6,0),
    aging_bucket            VARCHAR(20),
    collection_efficiency_pct NUMERIC(6,2)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR PERFORMANCE
-- ═══════════════════════════════════════════════════════════════════════════
CREATE INDEX idx_sales_date         ON fact_sales(date);
CREATE INDEX idx_sales_customer     ON fact_sales(customer_id);
CREATE INDEX idx_sales_product      ON fact_sales(product_id);
CREATE INDEX idx_sales_route        ON fact_sales(route_id);
CREATE INDEX idx_sales_category     ON fact_sales(category);
CREATE INDEX idx_sales_month_year   ON fact_sales(year, month);

CREATE INDEX idx_prod_date          ON fact_production(date);
CREATE INDEX idx_prod_category      ON fact_production(category);
CREATE INDEX idx_prod_month_year    ON fact_production(year, month);

CREATE INDEX idx_inv_date           ON fact_inventory(date);
CREATE INDEX idx_inv_product        ON fact_inventory(product_id);
CREATE INDEX idx_inv_status         ON fact_inventory(stock_status);

CREATE INDEX idx_acc_customer       ON fact_accounts(customer_id);
CREATE INDEX idx_acc_status         ON fact_accounts(payment_status);
CREATE INDEX idx_acc_invoice_date   ON fact_accounts(invoice_date);
CREATE INDEX idx_acc_aging          ON fact_accounts(aging_bucket);

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION QUERY
-- ═══════════════════════════════════════════════════════════════════════════
SELECT 'dim_date'        AS table_name, COUNT(*) AS rows FROM dim_date     UNION ALL
SELECT 'dim_product',                   COUNT(*)         FROM dim_product  UNION ALL
SELECT 'dim_route',                     COUNT(*)         FROM dim_route    UNION ALL
SELECT 'fact_sales',                    COUNT(*)         FROM fact_sales   UNION ALL
SELECT 'fact_production',               COUNT(*)         FROM fact_production UNION ALL
SELECT 'fact_inventory',                COUNT(*)         FROM fact_inventory  UNION ALL
SELECT 'fact_accounts',                 COUNT(*)         FROM fact_accounts   UNION ALL
SELECT 'dim_customer',                  COUNT(*)         FROM dim_customer
ORDER BY 1;
