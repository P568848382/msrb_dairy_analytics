# Inventory Operations Performance Report

**Project:** MSRB SONS DAIRY Business Analytics  
**Dashboard:** Inventory Operations  
**Date:** April 15, 2026  
**Live Link:** [Tableau Public - MSRB Inventory Operations](https://public.tableau.com/views/MSRBInventoryOperations/Dashboard1?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

---

## Dashboard Overview

![MSRB Inventory Operations Dashboard](../dashboards/screenshots/MSRB%20inventory%20operations%20dashboard.png)

The Inventory Operations dashboard is designed for the supply chain manager to monitor warehouse health, minimize stockouts, and manage shelf-life risks. I structured it to provide both a real-time snapshot of current availability and a historical view of stock movement velocity. The visual hierarchy starts with critical KPIs at the top, followed by a product-wise risk breakdown, and concludes with predictive supply mapping and monthly turnover trends.

---

## Core KPIs

| Metric | Value | Business Context |
|--------|-------|------------------|
| **Total Tracking Days** | **7,512** | Cumulative daily stock records across all SKUs. |
| **Stockout Rate** | **0.35%** | Percentage of days where items were out of stock. |
| **Avg Turnover Ratio** | **8.4x** | Frequency of stock replacement (Higher = Better). |
| **Shelf Life Risk** | **2.1%** | Percentage of stock at risk of expiring before sale. |

---

## Technical Design Decisions

### 1. Database Optimization (PostgreSQL Views)
**Why did we create views in PostgreSQL instead of connecting raw tables?**

Inventory tracking involves processing 7,512 daily ledger entries. To ensure the dashboard remains performant, I created views like `vw_stockout_frequency` which pre-aggregates these thousands of rows into product-level metrics. For example, `vw_stock_supply_risk` joins the latest stock snapshot with historical dispatch averages to project the remaining supply. Moving these joins and aggregations to PostgreSQL ensures that Tableau only handles the final presentation layer, preventing lag during filter interactions.

### 2. High-Impact KPI Cards
Each KPI card is connected to a pre-computed view. I used calculated fields to determine the **Days of Stock Remaining** by dividing current `closing_stock` by the historical `avg_daily_dispatch`. This provides a predictive metric rather than just a static count. I also implemented color-coded status logic — specifically, the "Critical Stock Alert" card turns red automatically when any high-volume SKU drops below 1 day of supply, providing an immediate visual trigger for the warehouse team.

### 3. Stockout Frequency (Horizontal Bar Chart)
I used a horizontal bar chart to analyze which products face the highest availability risks. Horizontal placement allows for readable product names. I sorted the bars by `stockout_rate_pct` to bring the most problematic items to the top. The color encoding represents the **Risk Category** (High/Medium/Low), helping the manager distinguish between a one-off stockout and a recurring supply chain bottleneck.

### 4. Days of Supply Remaining (Predictive Distribution)
This chart maps every product into a risk category: *Stockout, Critical (<1 Day), At Risk (Expires before Sold),* or *Safe*. I used this distribution to move from "reactive" inventory management to "predictive" management. The most complex logic here is the expiry risk check, which compares the `days_of_stock_remaining` against the `shelf_life_days`. If the projected sales time exceeds the shelf life, the item is flagged as *At Risk*, even if current stock levels are high.

### 5. Monthly Turnover & Movement Analysis
- **Turnover Trend (Line Chart):** I used a monthly trend line to track the **Turnover Ratio**. This helps identify if inventory is becoming "sluggish" over time.
- **Movement Categorization:** Using the `vw_monthly_turnover` view, I categorized every SKU as *Fast Moving, Normal, Slow Moving,* or *Dead Stock*. This allows the manager to prioritize space for high-velocity items and plan clearance for slow-moving stock before expiry.

---

## Key Business Findings & Insights

1.  **Perishable Stockout Patterns:** **Curd 400g** and **Milk Bulk** show the highest stockout frequency. This is largely due to their short shelf life (2-3 days), where even minor production delays lead to immediate availability gaps.
2.  **Ghee Stability:** The Ghee and Butter categories maintain the healthiest stock levels and the highest turnover ratios, meaning they are both high-demand and low-risk from an operational perspective.
3.  **Expiry vs Sales Gap:** While overall stockout is low, approximately **2.1%** of inventory falls in the *At Risk - Expires Before Sold* category. This happens when slow-moving SKUs are overstocked during non-peak months.
4.  **Critical Thresholds:** The analysis reveals that "Milk Packets" often operate on less than 0.8 days of supply, meaning they require daily replenishment to avoid lost sales revenue.

---

## Recommendations

1.  **Automated 48-Hour Reorder Trigger:** Implement a reorder alert system for **Curd** and **Milk Bulk** SKUs whenever closing stock falls below 2 days of average daily dispatch.
2.  **Dynamic Safety Stock:** Adjust safety stock levels seasonally. The data shows that Nov–Jan requires 15% higher buffer levels compared to summer months to prevent peak-season stockouts.
3.  **Slow-Moving Clearance:** For products identified as *Slow Moving* or *At Risk*, introduce bundle offers or retailer incentives at the 50% shelf-life mark to accelerate turnover.
4.  **Production-Inventory Sync:** Ensure the production planned quantity is dynamically updated based on the "Days of Stock Remaining" metric to avoid overstocking low-velocity items.
