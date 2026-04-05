-- ═══════════════════════════════════════════════════════════════════════════
-- FILE    : kpi_sales.sql
-- PROJECT : MSRB SONS DAIRY — Sales KPI Queries
-- AUTHOR  : Pradeep Kumar
-- ═══════════════════════════════════════════════════════════════════════════

-- ── KPI 1: Monthly Revenue Trend ────────────────────────────────────────────
--Business question: How much revenue did we earn each month, and what was the growth month over month?
select
	year,
	month,
	month_name,
	quarter,
	financial_year,
	count(distinct invoice_number) as total_invoices,
	count(distinct customer_id) as unique_customers,
	sum(quantity) as total_qty_sold,
	round(sum(gross_amount)::numeric,2) as gross_revenue,
	round(sum(discount)::numeric,2) as total_discount,
	round(sum(net_amount)::numeric,2) as total_revenue,
	round((sum(net_amount)/count(distinct invoice_number))::numeric,2) as avg_invoice_value,
	round((sum(discount)/nullif(sum(gross_amount),0)*100)::numeric,2) as discount_pct
from fact_sales
group by year,
		month,
		month_name,
		quarter,
		financial_year
order by year,month;

-- ── KPI 2: Revenue by Product Category ──────────────────────────────────────
--Business question: Which product categories drive the most revenue? What is each category's share of total revenue?
select category,
	   count(*)						 			as transactions,
	   sum(quantity) 				 			as total_qty,
	   round(sum(net_amount)::numeric,2) 	 	as net_revenue,
	   round((
        (sum(net_amount) * 100) 
        / sum(sum(net_amount)) over ()
		)::numeric,
        2
    		)									AS revenue_share_pct,
	   round(avg(unit_price)::numeric,2)					as avg_unit_price,
	   round(avg(discount / nullif(gross_amount,0))::numeric*100,2) as avg_dicount_pct	
from fact_sales
group by category
order by net_revenue desc;

-- ── KPI 3: Route Performance ─────────────────────────────────────────────────
--Business question: Which delivery routes generate the most revenue? How many customers does each route serve?
select 
	route_id,
	route_name,
	count(distinct customer_id) as customers_served,
	count(distinct invoice_number) as total_invoices,
	round(sum(net_amount)::numeric,2) as net_revenue,
	ROUND(SUM(net_amount)::numeric / NULLIF(COUNT(DISTINCT customer_id), 0), 2) AS revenue_per_customer,
	round(avg(net_amount)::numeric,2) as avg_invoice_value,
	round((
		sum(net_amount)*100.0
		/ sum(sum(net_amount)) over()
	)::numeric,2)					as revenue_share_pct
from fact_sales
group by route_id,route_name
order by net_revenue desc;


-- ── KPI 4: Top 20 Customers by Revenue ───────────────────────────────────────
--Business question: Who are our top 20 customers? When did they first buy from us? When did they last buy?
select 
	customer_id,
	customer_name,
	customer_type,
	route_name,
	count(distinct invoice_number) as total_invoices,
	
	round(sum(net_amount)::numeric,2) as lifetime_revenue,
	round(avg(net_amount)::numeric,2) as avg_invoice_value,
	min(date)::date as first_purchase,
	max(date)::date as last_purchase,
	count(distinct date) as active_days
from fact_sales
group by customer_id,
		 customer_name,
		 customer_type,
		 route_name
order by lifetime_revenue desc
limit 20;

-- ── KPI 5: Payment Mode Analysis ─────────────────────────────────────────────
--Business question: What percentage of our transactions are Cash vs Credit vs UPI vs Cheque? Does payment mode affect average order value?
select * from fact_sales limit 1;
select
	payment_mode,
	count(*) as transactions,
	round(sum(net_amount)::numeric,2) as total_revenue,
	round((count(*)*100.0 / sum(count(*))over())::numeric,2)||'%' as txn_share_pct,
	round(
	(sum(net_amount) * 100.0
	/ sum(sum(net_amount)) over ()
	)::numeric,2
	)||'%'						as revenue_share_pct,
	round(avg(net_amount)::numeric,2) as avg_transaction_value
from fact_sales
group by payment_mode
order by total_revenue desc;

-- ── KPI 6: Year-over-Year Revenue Comparison ─────────────────────────────────
with monthly as(
select
	month,
	month_name,
	financial_year,
	round(sum(net_amount)::numeric,2) as net_revenue
from fact_sales
group by month,month_name,financial_year
)
select
	m1.month,
	m1.month_name,
	m1.net_revenue  as revenue_2023_24,
	m2.net_revenue  as revenue_2024_25,
	round(m2.net_revenue - m1.net_revenue) as absolute_change,
	round(
		((m2.net_revenue - m1.net_revenue)
		/nullif(m1.net_revenue,0)*100
	)::numeric,2)||'%'        as yoy_growth_pct
from monthly m1
join monthly m2
on m1.month=m2.month and m1.financial_year='FY2023-24' and m2.financial_year='FY2024-25'
order by m1.month;

-- ── KPI 7: Customer Segmentation by Spend Band ───────────────────────────────
with customer_revenue as(
select
	customer_id,
	customer_name,
	customer_type,
	round(sum(net_amount)::numeric,2) as total_revenue
from fact_sales
group by customer_id,
	customer_name,
	customer_type
order by total_revenue desc
)
select
	case 
		when total_revenue >= 900000 then 'Platinum(>=9L)'
		when total_revenue >= 850000 then 'Gold(8.5L-9L)'
		when total_revenue >= 750000 then 'Silver(7.5L-8.5L)'
		when total_revenue >= 650000  then 'Bronze(6.5L-7.5L)'
		else 							  'Standard (<6L)'
	end as customer_segment,
	count(*) as customer_count,
	round(sum(total_revenue)::numeric,2) as segment_revenue,
	round(avg(total_revenue)::numeric,2) as avg_customer_revenue,
	round(
	(sum(total_revenue)*100.0
		/sum(sum(total_revenue))over()
		)::numeric,2)||'%' as revenue_share_pct
from customer_revenue
group by 1
order by segment_revenue desc;
				

	