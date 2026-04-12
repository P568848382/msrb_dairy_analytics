# Executive Performance Dashboard Report

**Project:** MSRB SONS DAIRY Business Analytics  
**Dashboard:** Executive Overview  
**Date:** April 12, 2026  
**Live Link:** [Tableau Public - MSRB Executive Dashboard](https://public.tableau.com/views/msrbsexecutivedashboard/Dashboard1?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

---

## Executive Overview

![MSRB Executive Dashboard](../dashboards/screenshots/Executive%20Dashboard.png)

The Executive Dashboard provides a high-level cross-functional view of MSRB SONS DAIRY, aggregating data from Sales, Production, Inventory, and Finance. It is designed to help leadership monitor organizational performance and identify critical risks.

---

## Core KPIs

| Metric | Current Value | Status | Analysis |
|--------|---------------|--------|----------|
| **Total Revenue** | **₹ 92M** | ✅ | Strong top-line performance across 2 financial years. |
| **Total Invoices** | **54,469** | ✅ | Indicates a healthy, high-frequency transaction volume. |
| **MoM Growth** | **22.0%** | ✅ | Excellent month-over-month sales momentum. |
| **Product Efficiency**| **93.54%** | ⚠️ | Slightly below the **95.0%** organizational target. |
| **Stock Out Rate** | **0.35%** | ✅ | Overall availability is high, though specific SKUs face issues. |
| **Collection Efficiency**| **89.59%** | ⚠️ | Below the 95% target, indicating cash flow lag. |

---

## Functional Deep-Dives

### 1. Revenue & Category Analysis
- **Ghee** remains the powerhouse, contributing **30.8% (₹ 28M)** of total revenue.
- **Milk Packet (18.9%)** and **Butter (15.5%)** are the next major contributors.
- The **Monthly Revenue Trend** shows that FY 2024-25 is maintaining a higher floor than FY 2023-24, despite seasonal fluctuations.

### 2. Operational Efficiency (Production vs Target)
- Production is consistently hitting between **93.4% and 93.7%** efficiency. 
- While stable, there is a consistent **~1.5% gap** to the 95% target, which represents missed revenue potential and wasted overhead.

### 3. Inventory Stock Status
- While the overall Stock Out Rate is low, **Curd 400g** has suffered **10 Stockout Days**.
- **Ghee 500ml (6 days)** and **Paneer 200g (4 days)** also show supply chain gaps.
- *For a detailed breakdown of how we measure these days, see the [Stockout Analysis Guide](stockout_analysis_guide.md).*

---

## 🚨 Critical Business Finding: Receivables Aging Crisis

The most significant risk identified in this dashboard is the **Accounts Receivable Aging**.

- **90+ Days Overdue:** **₹ 8,024K (₹ 80.2 Lakhs)**
- **Concentration:** This single bucket represents **83.5%** of all outstanding balances.
- **Risk:** Most of this ₹ 8M is at high risk of becoming bad debt, as collections have stalled for over 3 months.

---

## Strategic Recommendations

1.  **Urgent Debt Recovery:** Launch a legal/formal recovery process for all accounts in the 90+ days bucket.
2.  **Credit Policy Tightening:** Stop further credit sales to customers already in the 61-90 or 90+ day buckets.
3.  **Production Optimization:** Investigate the bottleneck preventing the morning shift from reaching 95% efficiency.
4.  **Buffer Stock for Curd 400g:** Increase safety stock levels for Curd 400g to eliminate the frequent stockouts (10 days).
