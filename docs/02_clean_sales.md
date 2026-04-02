# Documentation: 02_clean_sales.py

## Overview
`02_clean_sales.py` acts as the **Data Cleaning Layer** of the MSRB SONS Dairy Product Pvt. Ltd. Analytics Pipeline. Its primary job is to take raw, messy data (`fact_sales.csv`) and apply strict standardization, formatting, and mathematical rules to convert it into a fully validated and trusted dataset (`fact_sales_cleaned.csv`). 

By ensuring bad data is flagged early instead of moving forward, it prevents broken dashboards and inaccurate analytics down the line.

## Step-by-Step Data Processing

1. **Step 1: Strip Whitespaces**: Finds all text columns (`product_name`, `customer_name`, etc.) and eliminates extra leading or trailing spaces.
2. **Step 2: Date Validation**: Converts the `date` column into standard datetimes. Bad formats are replaced with NaNs and dropped. It also removes out-of-range dates using the predefined boundaries `DATE_START` and `DATE_END`.
3. **Step 3: Categorical Standardization**: Forces text into standard formats (like `.title()` casing), and uses specific reference values (`VALID_CATEGORIES`, `VALID_PAYMENT_MODES`, etc.) to check validity. Invalid text gets flagged.
4. **Step 4: Numeric Validation**: Casts essential columns into numeric data types, dropping unrecoverable missing ones. Crucially, it finds specific negative numbers and flags them as `NEGATIVE_...` so they can be recovered later, rather than deleting those rows outright.
5. **Step 5: Business Rule Validations**:
   - **Rule 1**: Validates that `gross_amount == quantity * unit_price`, allowing a gentle 1% tolerance for systemic rounding mismatches. 
   - **Rule 2**: Validates that `net_amount == gross_amount - discount`.
   - **Rule 3**: Checks if the applied discount exceeds 20% of the gross sale. If it does, a flag is added for manager review.
   - **Rule 4**: Ensures the net amount is never zero or negative (`net_amount <= 0`).
6. **Step 6: Remove Duplicates**: Uses the transaction identifier (`sale_id`) to find duplicate rows, explicitly dropping all but the first occurrence.
7. **Step 7: Derived Columns**: Calculates and appends new features that are vital for analytics:
   - `day_of_week` & `is_weekend` identifiers.
   - `financial_year` using standard April-March business logic.
   - `revenue_band` buckets (e.g., '<500', '10K+') using the built-in properties of `pd.cut`.
8. **Step 8: Output**: Intermediary helper columns (like temporary math columns) are cleanly jettisoned, and a comprehensive data summary profile is output into the logs. The final DataFrame exports to the `data/cleaned/` directory.

---

## Log of Your Recent Modifications
*The following list tracks the modifications you implemented in this file to strengthen the pipeline logic:*

1. **Custom Logging Setup Added**: 
   - Replaced generic logging logic with precise configuration of `FileHandler` and `StreamHandler`.
   - Added UTF-8 encoding checks (`encoding='utf-8'`) to stop emojis from becoming garbled symbols (`?`).
   - Automatically injects the timestamp directly into the log output filename (e.g., `clean_sales_20260402_152426.log`).
2. **Detailed Date Warnings**:
   - Improved the Date Validation logging (Step 2) to output the physical size range of dropped, invalid dates via `out_of_range['date'].min()`.
   - Inserted a reminder line to determine if `DATE_END` bounds require extension.
3. **Robust String Application**:
   - Extended the `.str.strip()` command across additional textual variables such as `product_name` and `customer_name`.
   - Standardized spelling via `.str.title()` application to `route_name`.
4. **Enhanced Business Rules**: 
   - Commented the overarching logic describing why Rule 1 (100 packets * ₹54 vs ₹5,000 typed gross) checks the data.
   - Guarded error processing to avoid code crashes by inserting `.replace(0, np.nan)` safely preventing division by zero attempts.
   - Documented Rule 3 (if salesman discount > 20%, require manager review flag).
   - **Introduced Rule 4**: Constructed a check filtering for negative or invalid net outputs `net_amount <= 0` dropping the flag `ZERO_OR_NEGATIVE_NET`.
5. **Exact Deduplications**: 
   - Overhauled the `df.duplicated` command to securely maintain only one instance of duplicates by forcing `keep='first'`.

---

## Data Flow Diagram

The following architectural flow maps out the entire ingestion through cleaning cycle, displaying the relationship between the `01_ingest.py`, `02_clean_sales.py`, plus the forthcoming pipeline scripts.

```mermaid
flowchart TD
    %% Base Datasets Layer
    subgraph RawLayer [Raw Layer "/data/raw"]
        A1[fact_sales.csv]
        A2[fact_production.csv]
        A3[fact_inventory.csv]
        A4[fact_accounts.csv]
    end

    %% Structural Check Layer
    I{01_ingest.py\nSchema & Structural\nValidation}

    %% Validated State
    subgraph MemoryLayer [Working Memory Space]
        B1((Sales Validated))
        B2((Production Validated))
        B3((Inventory Validated))
        B4((Accounts Validated))
    end

    %% Transformation Processing
    C1[02_clean_sales.py]
    C2[02_clean_production.py\n*Upcoming*]
    C3[02_clean_inventory.py\n*Upcoming*]
    C4[02_clean_accounts.py\n*Upcoming*]

    %% Final Target Storage
    subgraph StagingLayer [Cleaned Staging Layer "/data/cleaned"]
        D1[(fact_sales_cleaned.csv)]
        D2[(fact_prod_cleaned.csv)]
        D3[(fact_inv_cleaned.csv)]
        D4[(fact_acc_cleaned.csv)]
    end

    %% Final DB
    E[(PostgreSQL \n RDBMS Core)]
    F[Tableau / BI Dashboard Layer]

    %% Linking Nodes
    A1 --> I
    A2 --> I
    A3 --> I
    A4 --> I

    I -->|Structure Pass| B1
    I -->|Structure Pass| B2
    I -->|Structure Pass| B3
    I -->|Structure Pass| B4

    B1 --> C1
    B2 --> C2
    B3 --> C3
    B4 --> C4

    C1 -- Apply Rules & Flags --> D1
    C2 -- Standardize & Link --> D2
    C3 -- Fix Stock Outliers --> D3
    C4 -- Validate Totals --> D4

    D1 --> E
    D2 --> E
    D3 --> E
    D4 --> E
    
    E --> F

    classDef source fill:#f8f9fa,stroke:#dae0e5;
    classDef valid fill:#d4edda,stroke:#28a745,color:#155724;
    classDef process fill:#e2e3e5,stroke:#383d41;
    classDef file fill:#cce5ff,stroke:#b8daff,color:#004085;

    class A1,A2,A3,A4 source;
    class B1,B2,B3,B4 valid;
    class C1,C2,C3,C4 process;
    class D1,D2,D3,D4 file;
```
