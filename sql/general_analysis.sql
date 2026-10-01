--Order to cash funnel
WITH funnel_base as(
    SELECT  
    transaction_id,
    invoice_amount,
    outstanding_balance,
    1 as stage_1_billed,-- Stage 1: Invoice Issued
    CASE WHEN amount_paid>0  THEN 1 ELSE 0 END as stage_2_collected,-- Stage 2: Any cash collected at all
    CASE when outstanding_balance=0 THEN 1 ELSE 0 END as stage_3_fully_paid,-- Stage 3: Fully paid (no outstanding balance)
    CASE WHEN payment_status='Paid' then 1 ELSE 0 END as stage_4_on_time,-- Stage 4: Paid fully and strictly on time
    days_to_payment -- Velocity metric
from dw.fact_accounts
)
SELECT
    --Stage volumes
    SUM(stage_1_billed)as volume_s1_billed,
    sum(stage_2_collected) as volume_s2_collected,
    sum(stage_3_fully_paid) as volume_s3_fully_paid,
    sum(stage_4_on_time)as volume_s4_on_time,
    --stage tot stage conversion
        round(sum(stage_2_collected)::NUMERIC/nullif(sum(stage_1_billed),0)*100,2) as conv_pct_s1_to_s2,
        round(sum(stage_3_fully_paid)::NUMERIC/nullif(sum(stage_2_collected),0)*100,2) as conv_pct_s2_to_s3,
    round(sum(stage_4_on_time)::NUMERIC/nullif(sum(stage_3_fully_paid),0)*100,2) as conv_pct_s3_to_s4,
    --overall conversion
    round(sum(stage_4_on_time)::NUMERIC/nullif(sum(stage_1_billed),0)*100,2) as overall_conv_pct_s1_to_s4,
    -- DROP-OFF RATE (Friction from Stage 3 to 4 - Late Payments)
    100.0 - round(sum(stage_4_on_time)::NUMERIC/nullif(sum(stage_3_fully_paid),0)*100,2) as drop_off_late_pct,
    --REVENUE LEAKAGE (Total cash trapped in OverDue status)
    sum(outstanding_balance) as revenue_leakage
from funnel_base;

--CAC(Customer Acquisition Cost)vs LTV(Lifetime Value)
-- As we do not have maketing spend data, we will use the discount as a proxy for CAC and the sum(net_amount) as customer revenue as a proxy for LTV
WITH customer_metrics as(
    SELECT
    dc.customer_id,
    dc.customer_name,
    count(distinct fs.invoice_number) as total_orders,
    sum(fs.discount) as total_discount_spent,--CAC proxy
    sum(fs.net_amount) as total_revenue_generated--LTV proxy
from dw.fact_sales fs
join dw.dim_customer dc on fs.customer_id = dc.customer_id
group by dc.customer_id,dc.customer_name
)
SELECT
    customer_id,
    customer_name,
    round(total_revenue_generated,2) as actual_ltv,
    -- Estimating CAC: Total Discounts + a hypothetical fixed ₹5,000 sales onboarding cost
    round(total_discount_spent+5000,2) as estimated_cac,
    --LTV:CAC Ratio
    round(total_revenue_generated/nullif((total_discount_spent+5000),0)::NUMERIC,2) as ltv_to_cac_ratio,
    --Health Check: LTV:CAC ratio > 3 is considered healthy, <1 is unhealthy, 1-3 is moderate
    case 
        when round(total_revenue_generated/nullif((total_discount_spent+5000),0)::NUMERIC,2) > 3 then 'Healthy'
        when round(total_revenue_generated/nullif((total_discount_spent+5000),0)::NUMERIC,2) < 1 then 'Loss Making'
        when round(total_revenue_generated/nullif((total_discount_spent+5000),0)::NUMERIC,2) between 1 and 3 then 'Need Optimisation'
    end as health_check
from customer_metrics
order by ltv_to_cac_ratio desc;

--Monthly Churn Rate

-- Step 1: Get a distinct list of every customer who bought in each month
with monthly_customers AS(
    SELECT
    distinct
    dd.year,
    dd.month_num,
    fs.customer_id
from fact_sales fs
join dim_date dd ON dd.date_key = fs.date_key
order by year,month_num
)
-- Step 2: Compare Month 1 buyers against Month 2 buyers
SELECT
    m1.year,
    m1.month_num,
    count(distinct m1.customer_id) as active_customers,
    count(distinct case when m2.customer_id is null then m1.customer_id end ) as churned_customers  -- If the left join finds a NULL in m2, the customer churned
from monthly_customers m1
left join monthly_customers m2
on m1.customer_id=m2.customer_id
and (
        (m2.year=m1.year and m2.month_num=m1.month_num+1) 
        OR 
        (m2.year=m1.year+1 and m2.month_num=1 and m1.month_num=12)
    )-- Match exactly to the following month (handling December to January rollover)
group by m1.year,m1.month_num








