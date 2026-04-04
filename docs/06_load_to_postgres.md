# Documentation: 06_load_to_postgres.py

## Overview
`06_load_to_postgres.py` serves as the **Data Warehousing & Load Layer** (Layer 3) of the MSRB SONS Dairy Product Pvt. Ltd. Analytics Pipeline. Its responsibility is to traverse the finalized `cleaned` directory, read all verified and transformed CSV data entities (`sales`, `production`, `inventory`, `accounts`), and seamlessly batch-upload them into the newly established PostgreSQL Star Schema data warehouse (`msrb_dairy_dw`).

By programmatically applying schema validation, column type overriding, automatic bulk insertion in chunks, and post-load index creation, this script formally moves the operational datasets from the file-based system directly to the production relational database to empower high-speed Tableau or Power BI dashboard reporting.

## Step-by-Step Data Upload Process

1. **Step 1: Database Initialization**: Leverages `SQLAlchemy` and `psycopg2` to formulate a rapid, pooled connection to the local PostgreSQL database using parameterized credentials. Tests the pipeline actively via test queries (`SELECT 1`).
2. **Step 2: Table & File Mapping**: Maps specific staging components (`fact_sales_cleaned.csv`, `fact_accounts_cleaned.csv`, etc.) cleanly to their physical SQL tables (`fact_sales`, `fact_accounts`).
3. **Step 3: Temporal Coercion (Parse Dates)**: As flat CSVs naturally lose distinct Date metadata, this script pre-parses and restores crucial timeline columns into exact `DateTime` representations prior to the SQL translation to enforce type boundaries inside PostgreSQL.
4. **Step 4: Batch Loading & Optimization**: Rather than singular `INSERT` statements which run notoriously slow, data is strategically sliced into batches (`chunk_size=5000`). It utilizes `.to_sql()`'s `'replace'` operator combined with `'multi'` indexing methods to rapidly reconstruct the data in the Postgres target structure.
5. **Step 5: Post-Load Integrity Verification**: Enforces rigorous audit testing. After bulk load, the script triggers a physical `SELECT COUNT(*)` query inside Postgres and compares those exact row counts against the originating dataframe size to ensure entirely zero data loss happened over the pipeline wire.
6. **Step 6: Query Performance Indexing**: Knowing that the Business Intelligence (BI) layer queries will heavily group data by entities, it actively creates `B-Tree Indexes` against the most frequently targeted dimensions (e.g., `date`, `product_id`, `customer_id`, `payment_status`). This aggressively scales down visualization wait times.

---

## Complete Collaborative Data Flow

Below is the **Master Architectural Flow** covering the complete 3-layer data journey — from rough inbound CSVs scattered through ingest rules, passing independent modular cleaning structures, and finally arriving together in the central PostgreSQL engine.

```mermaid
flowchart TD
    %% Base Datasets Layer
    subgraph RawLayer ["🗂️ Raw Layer (/data/raw)"]
        A1[fact_sales.csv]
        A2[fact_production.csv]
        A3[fact_inventory.csv]
        A4[fact_accounts.csv]
    end

    %% Structural Check Layer
    I{"01_ingest.py<br/>Schema & Setup Validation"}

    %% Validated State
    subgraph MemoryLayer ["Working Memory / Quality Pass"]
        B1((Sales Validated))
        B2((Production Validated))
        B3((Inventory Validated))
        B4((Accounts Validated))
    end

    %% Transformation Processing
    subgraph CleanLayer ["🧹 Cleaning Operations (/etl/)"]
        C1["02_clean_sales.py<br/>(Cleaned)"]
        C2["03_clean_production.py<br/>(Cleaned)"]
        C3["04_clean_inventory.py<br/>(Cleaned)"]
        C4["05_clean_accounts.py<br/>(Cleaned)"]
    end

    %% Final Target Storage
    subgraph StagingLayer ["📦 Staging Layer (/data/cleaned)"]
        D1[(sales_cleaned.csv)]
        D2[(prod_cleaned.csv)]
        D3[(inv_cleaned.csv)]
        D4[(accounts_cleaned.csv)]
    end

    %% SQL Generation & Indexing
    subgraph DBLayer ["🖥️ Data Warehousing (/sql/ & 06_load)"]
        S1["schema_create.sql<br/>(DDL Schema Construction)"]
        S2{"06_load_to_postgres.py<br/>(Bulk Load & Indexing)"}
        E[("PostgreSQL RDBMS<br/>(msrb_dairy_dw)")]
    end

    %% BI Dashboard
    F["📊 Tableau / Power BI <br/> Reporting Core"]

    %% Flow logic
    A1 -.-> I
    A2 -.-> I
    A3 -.-> I
    A4 -.-> I

    I -.-> B1
    I -.-> B2
    I -.-> B3
    I -.-> B4

    B1 -.-> C1
    B2 -.-> C2
    B3 -.-> C3
    B4 -.-> C4

    C1 ==>|Fixes & Flags| D1
    C2 ==>|Yield Optimizations| D2
    C3 ==>|Calculates DSO & Stock| D3
    C4 ==>|Ledger Integrity| D4

    D1 ==> S2
    D2 ==> S2
    D3 ==> S2
    D4 ==> S2

    S1 -.-|Builds Tables| E
    S2 ==>|SQLAlchemy Fast-Load| E
    S2 -.->|Adds B-Tree Indexes| E
    E ==>|Real-time Querying| F

    classDef source fill:#f8f9fa,stroke:#dae0e5;
    classDef valid fill:#d4edda,stroke:#28a745,color:#155724;
    classDef process fill:#e2e3e5,stroke:#383d41;
    classDef targetProcess fill:#007bff,stroke:#0056b3,color:#fff;
    classDef coreDB fill:#17a2b8,stroke:#117a8b,color:#fff;
    classDef dashboard fill:#ffc107,stroke:#d39e00,color:#000;

    class A1,A2,A3,A4 source;
    class B1,B2,B3,B4 valid;
    class C1,C2,C3,C4 process;
    class D1,D2,D3,D4 process;
    class S2 targetProcess;
    class E coreDB;
    class F dashboard;
```
