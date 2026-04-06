-- ═══════════════════════════════════════════════════════════════════════════
-- FILE    : kpi_production.sql
-- PROJECT : MSRB SONS DAIRY — Production KPI Queries
-- AUTHOR  : Pradeep Kumarselect * from fact_production limit 1;
-- ═══════════════════════════════════════════════════════════════════════════
-- ── KPI 1: Monthly Production Efficiency ────────────────────────────────────
alter table fact_production
rename column "raw_milk_used_L" to raw_milk_used_l;
select 
	year,
	month,
	month_name,
	quarter,
	financial_year,
	sum(planned_qty) as total_planned,
	sum(actual_qty) as total_actual,
	sum(wastage_qty)  as total_wastage,
	round(sum(raw_milk_used_l)::numeric,2) as raw_milk_used_l,
	round((sum(actual_qty) * 100.0
			/nullif(sum(planned_qty),0)
			)::numeric,2)||'%'   as overall_efficiency_pct,
	round(
		(sum(wastage_qty)*100.0
		/nullif(sum(actual_qty),0)
		)::numeric,2
	)||'%'			as overall_wastage_pct
from fact_production
group by year,
	month,
	month_name,
	quarter,
	financial_year
order by year,month;

-- ── KPI 2: Efficiency by Product Category ────────────────────────────────────
--Q.which category has highest/lowest efficiency?
select * from fact_production limit 5;
alter table fact_production
rename column "wastage_rate_%" to wastage_rate_pct;
with category as(select 
	year,
	category,
	sum(planned_qty) as total_planned,
	sum(actual_qty) as total_actual,
	sum(wastage_qty) as total_wastage,
	round((sum(actual_qty)*100.0 / nullif(sum(planned_qty),0))::numeric,2)||'%' as efficiency_pct,
	round((sum(wastage_qty)*100.0 / nullif(sum(actual_qty),0))::numeric,2)||'%' as wastage_pct,
	round(sum(raw_milk_used_l)::numeric,2) as total_raw_milk_used_l,
	round(
			(sum(net_produced_qty)
			/nullif(sum(raw_milk_used_l),0)*100)::numeric,2
	)||'%'    as yield_pct
from fact_production
group by year,category
order by year,efficiency_pct desc
)
select
	category,
	max(case when year=2023 then yield_pct end) as year_23,
	max(case when year=2024 then yield_pct end) as year_24,
	max(case when year=2025 then yield_pct end) as year_25
from category
group by category;

-- ── KPI 3: Efficiency Band Distribution ──────────────────────────────────────
--how many production runs fall in each band (Poor/Fair/Good)
select 
	efficiency_band,
	count(*) as production_runs,
	round(
		(count(*)*100.0
			/sum(count(*)) over ()
			)::numeric,2
		)||'%'   as pct_of_runs
from fact_production
where efficiency_band is not null
group by efficiency_band
order by 2 desc;

-- ── KPI 4: Shift-wise Performance ────────────────────────────────────────────
--Q.Morning vs Evening — which shift produces more efficiently?
select 
	shift,
	count(*) as production_runs,
	round((sum(actual_qty)*100.0 / nullif(sum(planned_qty),0))::numeric,2)||'%' as avg_efficiency_pct,
	round((sum(wastage_qty)*100.0 / nullif(sum(actual_qty),0))::numeric,2)||'%' as avg_wastage_pct,
	sum(actual_qty) as total_produced,
	round(sum(actual_qty)*100.0 / sum(sum(actual_qty)) over(), 2)||'%' as production_share_pct
from fact_production
group by shift
order by avg_efficiency_pct desc;
--On which day the production hold only in evening not in morning.
SELECT *
FROM fact_production
WHERE date IN (
    SELECT date
    FROM fact_production
    GROUP BY date
    HAVING 
        COUNT(*) FILTER (WHERE shift = 'Morning') = 0
        AND
        COUNT(*) FILTER (WHERE shift = 'Evening') > 0
)
ORDER BY date;

-- ── KPI 5: Monthly Raw Milk Utilization ──────────────────────────────────────
--Q.total raw milk used vs net produced — yield efficiency trend
with utilization as(select
	year,
	month,
	month_name,
	round(sum(raw_milk_used_l)::numeric,2) as total_raw_milk_used_L,
	round(sum(net_produced_qty)::numeric,2) as net_produced,
	round((
		sum(net_produced_qty)
		/nullif(sum(raw_milk_used_l),0)
		)::numeric *100,2
	)  as yield_efficiency_pct
from fact_production
group by year,
		 month,
		 month_name
order by year,month)
select month,month_name,
	max(case when year=2023 then yield_efficiency_pct end) as year_23,
	max(case when year=2024 then yield_efficiency_pct end) as year_24,
	max(case when year=2025 then yield_efficiency_pct end) as year_25
from utilization
group by month,month_name
order by month;
	