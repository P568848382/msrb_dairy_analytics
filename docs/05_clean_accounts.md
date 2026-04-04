# Documentation: 05_clean_accounts.py

## Overview
`05_clean_accounts.py` acts as the **Accounts & Finance Data Cleaning Layer** of the MSRB SONS Dairy Product Pvt. Ltd. Analytics Pipeline. Its primary job is to process raw financial data (`fact_accounts.csv`) and apply strict financial integrity checks, mathematical balance resolutions, aging evaluation, and collection efficiency logic to convert it into a fully trusted dataset (`fact_accounts_cleaned.csv`).

By rigorously enforcing invoice balance equations, capping payment amounts against balances, and accurately categorizing outstanding debts, this script ensures the downstream financial reporting accurately reflects the company's real-world cash flow, outstanding obligations, and account aging risks.

## Step-by-Step Data Processing

1. **Step 1: Strip Whitespaces**: Automatically targets all text columns and eliminates leading or trailing spaces to avoid hidden categorical duplication.
2. **Step 2: Date Validation**: Converts critical date columns (`invoice_date`, `due_date`, `payment_date`) into standard datetimes. Unparseable dates are removed. Rows missing an `invoice_date` are explicitly dropped, while null `payment_date` values are intentionally retained (representing unpaid invoices). Finally, the dataset is scoped mathematically to ensure all invoices fall strictly within `DATE_START` and `DATE_END`.
3. **Step 3: Cast Numeric Columns**: Crucial monetary fields (`invoice_amount`, `amount_paid`, `outstanding_balance`, `credit_days`) are coerced into numeric types. Missing `invoice_amount` rows are discarded entirely, as they represent invalid ledger entries.
4. **Step 4: Invoice Balance Equation**: Enforces the immutable financial rule:
   `outstanding_balance = invoice_amount - amount_paid`
   If the recorded outstanding balance deviates from the mathematical truth due to manual entry errors, the algorithm recalculates and corrects the `outstanding_balance` cleanly. It also aggressively caps `amount_paid` so that it cannot exceed the source `invoice_amount`.
5. **Step 5: Cap Received Amounts**: Acts as a secondary validation where any incoming payment is capped by the currently registered `outstanding_balance`, ensuring payment logic behaves flawlessly over multiple iterations of invoice adjustments. 
6. **Step 6: Remove Duplicates**: Uses the `transaction_id` specifically to locate and remove explicitly duplicated financial transactions from being counted multiple times.
7. **Step 7: Recalculate Payment Status**: Dynamically determines the classification of all transactions:
   - **Paid**: Balance is zero and paid on or before the due date.
   - **Paid Late**: Balance is zero but paid after the due date.
   - **OverDue**: Balance remains strictly greater than zero.
8. **Step 8: Derived Columns (Aging,days_overdue, collection_efficiency & financial_year)**: Calculates and appends vital cash flow features:
   - **Financial Year**: Generates the exact Indian financial year based on `invoice_date` (April marking the start of a new FY).
   - **Days Overdue**: Tallies exactly how overdue unpaid items are compared to the analysis execution date.
   - **Aging Bucket**: Classifies the `OverDue` invoices into standardized aging brackets: `1-30 Days`, `31-60 Days`, `61-90 Days`, and `90+ Days`.
   - **Collection Efficiency**: Mathematically derives the collected proportion of an invoice's total scale logic `(amount_paid / invoice_amount) * 100`.
  

---

## Data Flow Diagram

The following architectural flow maps out the lifecycle of the accounts and finance dataset specifically, displaying its interactions with ingest boundaries across the analytical layers.

```mermaid
flowchart TD
    %% Base Datasets Layer
    subgraph RawLayer ["Raw Layer /data/raw"]
        A1[fact_sales.csv]
        A2[fact_production.csv]
        A3[fact_inventory.csv]
        A4[fact_accounts.csv]
    end

    %% Structural Check Layer
    I{"01_ingest.py<br/>Schema & Structural<br/>Validation"}

    %% Validated State
    subgraph MemoryLayer ["Working Memory Space"]
        B1((Sales Validated))
        B2((Production Validated))
        B3((Inventory Validated))
        B4((Accounts Validated))
    end

    %% Transformation Processing
    C1["02_clean_sales.py<br/>(Completed)"]
    C2["03_clean_production.py<br/>(Completed)"]
    C3["04_clean_inventory.py<br/>(Completed)"]
    C4["05_clean_accounts.py<br/>(Active)"]

    %% Final Target Storage
    subgraph StagingLayer ["Cleaned Staging Layer /data/cleaned"]
        D1[(fact_sales_cleaned.csv)]
        D2[(fact_prod_cleaned.csv)]
        D3[(fact_inv_cleaned.csv)]
        D4[(fact_accounts_cleaned.csv)]
    end

    %% Final DB
    E[("PostgreSQL <br/> RDBMS Core")]
    F["Tableau / BI Dashboard Layer"]

    %% Linking Nodes
    A1 -.-> I
    A2 -.-> I
    A3 -.-> I
    A4 ==>|Primary Focus| I

    I -.->|Structure Pass| B1
    I -.->|Structure Pass| B2
    I -.->|Structure Pass| B3
    I ==>|Structure Pass| B4

    B1 -.-> C1
    B2 -.-> C2
    B3 -.-> C3
    B4 ==> C4

    C1 -.->|Apply Rules & Flags| D1
    C2 -.->|Process Yields & Efficiency| D2
    C3 -.->|Fix Stock Outliers| D3
    C4 ==>|Validate Invoice Balances & DSO| D4

    D1 -.-> E
    D2 -.-> E
    D3 -.-> E
    D4 ==> E
    
    E --> F

    classDef source fill:#f8f9fa,stroke:#dae0e5;
    classDef valid fill:#d4edda,stroke:#28a745,color:#155724;
    classDef process fill:#e2e3e5,stroke:#383d41;
    classDef activeProcess fill:#ffeeba,stroke:#ffc107,color:#856404;
    classDef file fill:#cce5ff,stroke:#b8daff,color:#004085;

    class A1,A2,A3 source;
    class A4 activeProcess;
    class B1,B2,B3 valid;
    class B4 activeProcess;
    class C1,C2,C3 process;
    class C4 activeProcess;
    class D1,D2,D3 file;
    class D4 activeProcess;
```
