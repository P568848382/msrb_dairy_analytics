# Accounts & Finance Performance Report

**Project:** MSRB SONS DAIRY Business Analytics  
**Dashboard:** Accounts & Finance  
**Date:** April 21, 2026  
**Live Link:** [Tableau Public - MSRB Accounts & Finance](https://public.tableau.com/views/msrbaccountsandfinancedashboard/AccountsFinance?:language=en-US&publish=yes&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

---

## Dashboard Overview

![MSRB Accounts & Finance Dashboard](../dashboards/screenshots/Accounts%20&%20Finance.png)

The Accounts & Finance dashboard provides a comprehensive view of the dairy's financial health, focusing on the end-to-end collections story. Designed for the finance manager, it tracks billing vs. collections, aging of receivables, and customer payment behavior. The layout is optimized to highlight high-risk segments (like chronic non-payers) and provide actionable insights for credit policy adjustments.

---

## Core KPIs

| Metric | Value | Business Context |
|--------|-------|------------------|
| **Total Billed** | **₹ 9.22 Cr** | Net revenue invoiced over 24 months. |
| **Total Collected** | **₹ 8.26 Cr** | Total payments recovered. |
| **Outstanding Balance** | **₹ 96 L** | Revenue currently sitting in receivables. |
| **Days Sales Outstanding (DSO)** | **3.15 Days** | Average time to collect payment (Industry Benchmark: 15-30 days). |
| **Collection Efficiency** | **89.59%** | Efficiency of debt recovery (Target: >95%). |

---

## Technical Design Decisions

### 1. Database Optimization (PostgreSQL Views)
**Why did we create views in PostgreSQL instead of connecting raw tables?**

Financial reporting requires complex calculations across multiple invoice cycles. I created views like `vw_receivables_aging` and `vw_dso_monthly` to pre-calculate these metrics at the database level. For example, the aging view handles the categorization of 2,800+ account records into specific time buckets. This ensures Tableau only has to render the final summaries, allowing for smooth interactions when filtering by customer type or financial year.

### 2. Five-Card Financial Summary
The KPI cards tell a sequential story: we billed ₹9.22Cr and collected ₹8.26Cr, leaving ₹96L outstanding. I used constant-value threshold logic in calculated fields to automate status signaling:
- **DSO (3.15 days):** Marked Green (<15 days).
- **Collection Efficiency (89.59%):** Marked Amber (Below 95% target).
- **Outstanding %:** Marked Amber if outstanding exceeds 15% of billing.

### 3. Billing vs. Collections Combo Chart
This chart uses **Measure Names/Measure Values** to place billing and collection bars on a shared axis for direct height comparison. The efficiency line uses a **dual axis** with an independent right scale. I added two reference lines to create visual zones:
- **Green Zone:** Above 90% (Target achieved).
- **Amber Zone:** 88-90% (Watch zone).
- **Red Zone:** Below 88% (Alert zone).
*Insight:* A clear inverse relationship is visible between billing spikes and collection efficiency during festive months.

### 4. Receivables Aging Analysis
I implemented a **manual sort** (or `sort_order` field) to ensure the 1-30 to 90+ days sequence remains robust. A **gradient red color scheme** is used to encode severity, following pre-attentive processing principles where the eye is drawn to the darkest elements (the 90+ day bucket) first. This immediately highlights that our receivables problem is concentrated in the oldest bucket, representing 83.53% of all overdue amounts.

### 5. Advanced Trend & Segment Analysis
- **DSO Three-Zone Background:** Instead of simple reference lines, I used dual-axis area marks with low opacity to create colored background zones. This allows the viewer to instantly classify data points (Green/Amber/Red) without reading numbers.
- **Highlight Table (Customer Payments):** Uses pale background washes to maintain text readability while highlighting risk. I filtered to the Top 20 customers by outstanding amount to ensure the information is actionable. Alert icons are implemented using **Unicode emojis** in calculated fields to avoid external image dependencies.
- **Customer Type Dual-Panel:** Side-by-side comparison of efficiency vs. days to pay reveals the complete payment profile. This helps distinguish between high-volume/slow-payment segments (Hotels) and low-volume/cash segments (Direct Consumers).

---

## Key Business Findings & Insights

1.  **DSO vs. Collection Paradox:** Our DSO of **3.15 days** is excellent compared to industry norms (15-30 days). However, our collection efficiency is only **89.59%**.
2.  **Chronic Non-Payers:** The resolution of this paradox is found in the aging chart: **83.53%** of all overdue amounts are in the 90+ days bucket. This reveals we don't have "slow" payers; we have "chronic non-payers" who continue accumulating invoices without settlement.
3.  **Customer-Level Concentration:** 111 customers hold an average of 3+ overdue invoices each, specifically in the **Hotel/Restaurant** segment (83.74% efficiency).
4.  **Cash Segment Strength:** Direct Consumers operate with 93.89% efficiency and 0 days to pay, confirming a healthy cash-on-delivery foundation for that segment.

---

## Strategic Recommendations

1.  **Mandatory Settlement Rule:** Require high-risk segments (specifically Hotels) to settle all outstanding balances before receiving new deliveries. This stops the accumulation of chronic debt.
2.  **Automated Credit Enforcement:** Implement a hard credit limit where any customer with an invoice in the 90+ day bucket is automatically moved to Cash-On-Delivery (COD) terms.
3.  **Festive Season Collection Drive:** Intensify collection follow-ups during November and December (months with highest billing spikes) to prevent the dip in collection efficiency.
4.  **Advance Payment Policy:** For new Hotel/Restaurant invoices above a defined threshold, require a 25-50% advance payment until the customer establishes a 12-month clean payment history.
