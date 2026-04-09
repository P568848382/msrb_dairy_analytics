-- ══════════════════════════════════════════════════════════════════════════════
-- FILE    : kpi_accounts.sql
-- ══════════════════════════════════════════════════════════════════════════════
select * from fact_accounts;
-- ── KPI 1: Monthly Billing vs Collections ─────────────────────────────────────
select 
	year,
	month,
	month_name,
	quarter,
	financial_year,
	count(distinct customer_id) as customer_billed,
	round(sum(invoice_amount)::numeric,2) as total_billed,
	round(sum(amount_paid)::numeric,2)    as total_collected,
	round(sum(outstanding_balance)::numeric,2) as total_outstanding,
	round((
		sum(amount_paid)*100.0
		/nullif(sum(invoice_amount),0))::numeric,2
	)||'%'     as collection_efficiency_pct
from fact_accounts
group by year,
	month,
	month_name,
	quarter,
	financial_year
order by year,month;	

-- ── KPI 2: Receivables Aging Summary ─────────────────────────────────────────
select
	aging_bucket,
	count(*)    as invoices,
	count(distinct customer_id)  as customers,
	round(sum(outstanding_balance)::numeric,2) as outstanding_amount,
	round(
	(sum(outstanding_balance)*100.0
	/nullif(sum(sum(outstanding_balance)) over(),0))::numeric,2
	)    as pct_of_total
from fact_accounts
where payment_status='OverDue'
group by aging_bucket
order by case aging_bucket
			  when '1-30 Days' then 1
			  when '31-60 Days' then 2
			  when '61-90 Days' then 3
			  when '90+ Days' then 4
			  else 5
			  end;
-- ── KPI 3: Customer Payment Behaviour ─────────────────────────────────────────
select
	customer_id,
	customer_name,
	customer_type,
	count(*) as total_invoices,
	round(sum(invoice_amount)::numeric,2) as total_billed,
	round(sum(amount_paid)::numeric,2) as total_paid,
	round(sum(outstanding_balance)::numeric,2) as outstanding_amount,
	round(avg(days_to_payment)::numeric,2) as avg_days_to_pay,
	sum(case when payment_status='Paid' then 1 else 0 end) as on_time_payment_count,
	sum(case when payment_status='Paid Late' then 1 else 0 end) as paid_late_payment_count,
	sum(case when payment_status='OverDue' then 1 else 0 end) as overdue_payment_count,
	round(
		(sum(amount_paid)*100.0
		/nullif(sum(invoice_amount),0))::numeric,2
	)||'%'  as collection_efficieny_pct
from fact_accounts
group by customer_id,
	     customer_name,
	     customer_type
order by outstanding_amount desc;

-- ── KPI 4: Days Sales Outstanding (DSO) by Month ─────────────────────────────
select
	year,
	month,
	month_name,
	round((sum(outstanding_balance)*30.0
			/nullif(sum(invoice_amount),0)
			)::numeric,2)  as dso_days
from fact_accounts
group by year,
	month,
	month_name
order by year,month;

-- ── KPI 5: Customer Type Collection Efficiency ────────────────────────────────
select
	customer_type,
	count(distinct customer_id) as customers,
	count(*) as invoices,
	round(sum(invoice_amount)::numeric,2) as total_billed,
	round(sum(amount_paid)::numeric,2) as total_collected,
	round(sum(outstanding_balance)::numeric,2) as outstanding_amount,
	round(
		(sum(amount_paid)*100.0
			/ nullif(sum(invoice_amount),0))::numeric,2
	)||'%'  as collection_efficiency_pct,
	round(avg(case when payment_status!='OverDue' then days_to_payment end)::numeric,2) as avg_days_to_pay
from fact_accounts
group by customer_type
order by collection_efficiency_pct desc;


			