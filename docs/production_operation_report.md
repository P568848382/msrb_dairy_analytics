# Production & Operations Performance Report

**Project:** MSRB SONS DAIRY Business Analytics  
**Dashboard:** Production & Operations  
**Date:** April 13, 2026  
**Live Link:** [Tableau Public - MSRB Production Dashboard](https://public.tableau.com/shared/NBH9N4P4F?:display_count=n&:origin=viz_share_link)

---

## Dashboard Overview

![MSRB Production and Operations Dashboard](../dashboards/screenshots/MSRB%20PRODUCTION%20AND%20OPERATIONS%20DASHBOARD.png)

The Production & Operations dashboard is designed for the plant manager who needs to answer three questions every morning: are we hitting our efficiency target, which products are causing problems, and is our raw milk being utilized optimally? I structured it in a visual hierarchy — KPI cards at top for immediate status, the monthly trend line for temporal context, the category breakdown to identify which product is underperforming, and the raw milk utilization chart at the bottom to understand input-output efficiency.

---

## Core KPIs

| Metric | Value | Business Context |
|--------|-------|------------------|
| **Total Production Runs** | **4,382** | Total number of batches processed over 24 months. |
| **Avg Efficiency** | **93.54%** | Overall plant efficiency (Target: 95%). |
| **Wastage Rate** | **2.14%** | Raw material conversion loss (Threshold: <3%). |
| **Yield Efficiency** | **14.8%** | Average raw-to-finish conversion ratio across all categories. |

---

## Technical Design Decisions

### 1. Database Optimization (PostgreSQL Views)
**"Why did you create views in PostgreSQL instead of connecting raw tables?"**

Each view pre-aggregates data to the grain Tableau actually needs. For example, `vw_shift_performance` reduces 4,382 production rows to 2 rows — one per shift. Tableau renders these instantly. If I connected `fact_production` directly for the shift comparison chart, Tableau would aggregate 4,382 rows live on every filter interaction. Views move computation to PostgreSQL where it is optimized, and Tableau only handles presentation. This is the same principle as a semantic layer in enterprise BI — the database does the math, the visualization tool does the display.

### 2. High-Impact KPI Cards
Each KPI card is a separate Tableau sheet connected to a pre-aggregated PostgreSQL view. I used calculated fields for two reasons — first, to compute the correct weighted efficiency using `SUM(actual)/SUM(planned)` rather than averaging pre-computed percentages, which would give incorrect results when months have different production volumes. Second, I created conditional color logic so the card changes color automatically based on business thresholds — green above target, amber within acceptable range, red below. The **Efficiency vs Target Gap** card shows the absolute distance from the 95% target, giving the plant manager an immediate quantified answer to *"how far are we from where we need to be?"* rather than making them calculate it mentally.

### 3. Dual Axis Trend Analysis
I used a dual-axis chart with synchronized independent scales — efficiency percentage on the left axis ranging 85 to 100, and wastage rate on the right axis ranging 0 to 5. I deliberately did not synchronize the scales because these are different metrics with different ranges. Synchronizing would compress the wastage area to near zero making it invisible. The dual axis design lets the plant manager see both metrics simultaneously and observe their inverse relationship — months where the efficiency line dips below 90% typically show the wastage area expanding upward. The 95% reference line is a constant value reference line from Tableau's analytics pane, not a data field — it stays fixed regardless of which financial year or category filter is applied.

### 4. Bar Chart & Heatmap Design
- **Horizontal Bars:** I used a horizontal bar chart rather than vertical because category names are multi-word labels — horizontal placement gives enough space for readable labels. I fixed the X-axis range at 88 to 100 rather than 0 to 100 deliberately. Starting at 0 would make all bars look almost equal in length since all categories are between 92-94%. Starting at 88 makes the differences visible — Cream at 92.16% versus Milk Bulk at 93.71% represents a meaningful gap.
- **YoY Yield Heatmap:** I chose a heatmap over a grouped bar chart for the YoY yield comparison because it communicates two dimensions simultaneously — category and year — with color encoding the metric value. The heatmap makes it instantly clear that yield has been stable year-over-year — which is an important business finding: yield efficiency is not improving.

### 5. Advanced Distributions
- **Donut Chart:** I used a donut chart because the donut hole provides space to display the total count — 4,382 production runs — which gives context to the percentages. The donut is built using Tableau's dual-axis technique — two overlapping pie charts. The key insight is that zero runs fall in the "Critical" band (below 85%), meaning all production operates within a safe range, but also that something is capping performance below the 95% target.
- **Shift Comparison:** This uses a vertically stacked dual-chart layout because efficiency % and wastage rate operate on incompatible scales (93% vs 2%). The finding is that Evening shift outperforms Morning on production share by 2.74% — translating to approximately 58,000 additional units produced over 2 years.
- **Raw Milk Utilization (Area + Line):** This chart uses a dual-axis area-plus-line combination where both axes are synchronized because both measures — raw milk input and net produced output — are in the same unit (litres). The vertical gap between the blue area and the green line is visually proportional to the actual conversion loss.

---

## Key Business Findings & Insights

1.  **Cream Category Underperformance:** The Cream category consistently underperforms at 92.16% efficiency while consuming raw milk at a 16.4% yield rate. Improving Cream production could simultaneously improve overall plant efficiency and reduce raw milk waste.
2.  **Evening Shift Superiority:** The Evening shift produces significantly higher volume (approx. 58k extra units over 2 years) compared to the Morning shift with better efficiency metrics.
3.  **Target Consistency:** The most important technical decision was using a 95% reference line as a constant benchmark across multiple charts. This creates visual consistency so the plant manager can immediately see the gap between actual and target regardless of which chart they are looking at.
4.  **Yield Stability:** Yield efficiency has been stagnant year-over-year across all 7 categories, suggesting that while the process is stable, there haven't been any successful yield improvement initiatives in the last 24 months.

---

## Recommendations

1.  **Morning Shift Audit:** Investigate why the morning shift lags behind evening performance. Check equipment warmup times and raw material availability at the start of the day.
2.  **Cream Production Review:** The Cream category is the primary drag on efficiency. Conduct a deep-dive into the separator and aging processes to identify why efficiency sits at 92% vs the 95% target.
3.  **Yield Optimization Project:** Since yield has not improved in 2 years, launch a pilot project for Ghee and Butter (the high-volume yield categories) to optimize the concentration process.
