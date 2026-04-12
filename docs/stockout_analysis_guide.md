# Deep-Dive: Understanding "Stockout Days"

One of the most critical metrics in our Inventory Analysis is **Stockout Days**. This guide explains exactly how this number is calculated, from the physical warehouse to the final dashboard visual.

---

## 1. The Physical Root (Warehouse)
In your daily dairy operations, every morning an inventory count is taken. 
If the warehouse staff looks for **"Curd 400g"** and finds **0 units** available to dispatch to customers, that is physically a "Stockout."

In the business world, a stockout is a **lost revenue event**. Every day a product is out of stock, customers buy from a competitor instead.

---

## 2. The Data Root (Raw Input)
This physical event is recorded in our raw data file: `fact_inventory.csv`.
On any date where a product is unavailable, the record looks like this:

| Date | Product | Opening Stock | Received | Dispatched | Closing Stock |
|------|---------|---------------|----------|------------|---------------|
| 2024-05-12 | Curd 400g | 0 | 0 | 0 | **0** |

---

## 3. The ETL Root (Python Logic)
When we run our cleaning pipeline in `etl/04_clean_inventory.py`, the code scans every row of the inventory data. 

It applies this specific business logic:
```python
if closing_stock == 0:
    return 'Stockout'
```

The script then adds a new column called `stock_status` with the value `"Stockout"` for that specific product and that specific date.

---

## 4. The BI Root (Tableau Calculation)
On the Executive Dashboard, you see a number like **"10 Days"** for Curd 400g. 
Tableau reaches this number using a **Count Distinct (COUNTD)** calculation.

**The Formula:**
`COUNTD(IF [Stock Status] = "Stockout" THEN [Date] END)`

**Why Count Distinct?**
Because if there were multiple records for the same product on the same day (e.g., from different sub-batches), we only want to count that as **one day** of lost sales.

---

## 5. Summary: From Ground to Dashboard
1.  **Warehouse:** Inventory hits **0**.
2.  **Excel/CSV:** `closing_stock` is entered as **0**.
3.  **Python:** Flags that row as **'Stockout'**.
4.  **Tableau:** Counts how many **unique dates** have that flag.
5.  **Dashboard:** Displays **Total Stockout Days**.

**Business Interpretation:**  
If a product has 10 Stockout Days, it means for 10 separate 24-hour periods, MSRB Dairy was unable to fulfill any orders for that item, resulting in 10 days of lost revenue and potential customer dissatisfaction.
