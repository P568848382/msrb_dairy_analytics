-- ══════════════════════════════════════════════════════════════════════════════
-- FILE    : kpi_inventory.sql
-- ══════════════════════════════════════════════════════════════════════════════
-- ── KPI 1: Current Stock Status (Latest Date) ────────────────────────────────
--which products are OK, Low, Critical, Stockout?
select 
	date,
	product_id,
	product_name,
	category,
	closing_stock,
	reorder_level,
	stock_status,
	shelf_life_risk,
	round(days_of_stock::numeric,1) as days_of_stock
from fact_inventory
where	date=(select max(date) from fact_inventory)
order by stock_status,category;

-- ── KPI 2: Stockout Frequency by Product ─────────────────────────────────────
--how many days did each product hit zero stock across 2 years?
with stockout_fre as(
select
	product_id,
	product_name,
	category,
	count(*) as total_days,
	sum(case when stock_status='Stockout' then 1 else 0 end) as stockout_days,
	sum(case when stock_status='Critical' then 1 else 0 end) as critical_days,
	round((
		sum(case when stock_status='Stockout' then 1 else 0 end)
		*100.0/count(*))::numeric,2
	)  as stockout_rate_pct
from fact_inventory
group by product_id,
	product_name,
	category
order by stockout_rate_pct desc
)
select * ,
	case 
		when stockout_days>=5 then 'High Risk'
		when stockout_days>=2 then 'Medium Risk'
		when stockout_days>=1 then 'Low Risk'
		else 'No Stockout'
	end as risk_category
from stockout_fre

select * from fact_inventory limit 1;
--- ── KPI 3: Monthly Stock Turnover ─────────────────────────────────────────────
--which months moved stock fastest?
with monthly_stock as(select 
	year,
	month,
	month_name,
	product_id,
	product_name,
	category,
	round((avg(opening_stock+closing_stock)/2)::numeric,2) as avg_inventory,
	sum(dispatched_qty) as total_dispatched,
	round(
	(sum(dispatched_qty)
		/nullif(avg((opening_stock+closing_stock)/2),0))::numeric,2
	)  as turnover_ratio
from fact_inventory
group by year,
	month,
	month_name,
	product_id,
	product_name,
	category
order by year,month,turnover_ratio desc)
select *,
	case 
		when turnover_ratio>=10 then 'Fast Moving'
		when turnover_ratio>=5 then 'Normal'
		when turnover_ratio>=1 then 'Slow Moving'
		else   						'Dead Stock Risk'
	end as movement_category
from monthly_stock;

-- ── KPI 4: Shelf Life Risk Summary ────────────────────────────────────────────
--how many records are At Risk vs Safe per category?
select 
	category,
	shelf_life_risk,
	count(*) as records,
	round(count(*)*1.0/(sum(count(*)) over( partition by category)),2) as pct
from fact_inventory
group  by category,
		  shelf_life_risk
order by  category,shelf_life_risk desc;

--── KPI 5: Days of stock remaining by product ────────────────────────────────────────────
-- how many days of supply left?
with current_stock as
(select
	product_id,
	product_name,
	category,
	closing_stock,
	reorder_level,
	stock_status,
	shelf_life_days
from fact_inventory
where date=(select max(date) from fact_inventory)
),
avg_dispatch as
(select
	product_id,
	round(avg(dispatched_qty)::numeric,2) as avg_daily_dispatch
from fact_inventory
group by product_id
)
select 
	cs.*,
	ad.avg_daily_dispatch,
	round((
		cs.closing_stock
		/nullif(ad.avg_daily_dispatch,0))::numeric,2
	)  as days_of_stock_remaining,
	case 
		when cs.closing_stock=0 then 'Stockout'
		when round((
		cs.closing_stock
		/nullif(ad.avg_daily_dispatch,0))::numeric,2
		) < 1   then 'Critical - Under 1 Day'
		when round((
		cs.closing_stock
		/nullif(ad.avg_daily_dispatch,0))::numeric,2
		) > cs.shelf_life_days  then 'At Risk - Expires Before Sold'
		else  'Safe - Sells Before Expiry'
	end as supply_risk
from current_stock cs
join avg_dispatch ad on cs.product_id= ad.product_id
order by days_of_stock_remaining desc;
