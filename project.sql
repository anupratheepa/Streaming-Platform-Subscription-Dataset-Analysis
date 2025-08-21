--1.How have Mavenflix subscriptions trended over time--

select 
    to_char(created_date, 'yyyy-mm') as month,
    count(customer_id) as subscriptions_started
from subscriptiondata
group by to_char(created_date, 'yyyy-mm')
order by month;


--2.What percentage of customers have subscribed for 5 months or more?--
select
    round(
        (count(
            case 
                when months_between(
                        nvl(to_date(canceled_date, 'yyyy-mm-dd hh24:mi:ss'), sysdate),
                        created_date
                    ) >= 5 
                then 1 
            end
        ) / count(*)) * 100,
        2
    ) as pct_customers_Subsc
from subscriptiondata;


--3.What month has the highest subscriber retention, the lowest retention?--

with monthly_subs as (
    select 
        to_char(created_date, 'yyyy-mm') as month,
        count(*) as started
    from subscriptiondata
    group by to_char(created_date, 'yyyy-mm')
),
monthly_retained as (
    select 
        to_char(created_date, 'yyyy-mm') as month,
        count(*) as retained
    from subscriptiondata
    where canceled_date is null
          or to_date(canceled_date, 'yyyy-mm-dd hh24:mi:ss') > created_date
    group by to_char(created_date, 'yyyy-mm')
)
select 
    m.month,
    round((r.retained/m.started)*100, 2) as retention_rate
from monthly_subs m
join monthly_retained r on m.month = r.month
order by retention_rate desc;


--4. What percentage of cancellations occur within the first month of joining?--
--Couting customers who cancelled the subscription within 30 days--
with first_month_of_cancellations as(
    select count(*) as cancelled_within_first_month
    from subscriptiondata
    where canceled_date is not null or
    canceled_date <=created_date+interval '30' day
    ),
--count total customers--
total_customer as (
    select 
    count(*) as total_subscribed
    from subscriptiondata
    )
--compute cancellation percentage--

select Round ((a.cancelled_within_first_month/b.total_subscribed)*100.00,2) as ptg_cancellation
from first_month_of_cancellations a, total_customer b;


--5.What percentage of customers have re-subscribed after canceling once?--

-- Counting customers who re-subscribed
with resubscribed_customers as (
    select distinct a1.customer_id
    from subscriptiondata a1
    join subscriptiondata a2
    on a1.customer_id = a2.customer_id
    and a2.created_date > a1.canceled_date
    where a1.canceled_date is not null
),
-- Total distinct Customers count
Customer_total as (
    select count(distinct customer_id) as total_cust
    from subscriptiondata
)
select
    round(
        ( (select count(distinct customer_id) From resubscribed_customers) * 100.0
          / (select total_cust From Customer_total) )
    , 2) as resubscribed_ptg
from dual;

--6. Average Subscription Duration--

select 
    customer_id,
    round(
        avg(
            months_between(nvl(canceled_date, sysdate), created_date)
        ), 2
    ) as avg_sub_duration_months
from subscriptiondata
group by customer_id;

--7.Customer Tenure Segmentation--
select 
    case 
        when months_between(nvl(canceled_date, sysdate), created_date) < 3 
            then 'short_term_customer'
        when months_between(nvl(canceled_date, sysdate), created_date) between 3 and 6 
            then 'medium_term_customer'
        else 'long_term_customer'
    end as customer_tenure_segment,
    count(distinct customer_id) as customer_count
from subscriptiondata
group by 
    case 
        when months_between(nvl(canceled_date, sysdate), created_date) < 3 
            then 'short_term_customer'
        when months_between(nvl(canceled_date, sysdate), created_date) between 3 and 6 
            then 'medium_term_customer'
        else 'long_term_customer'
    end
order by count(distinct customer_id) desc;

--8. Top 50 Paid Customers Segmented by Subscription Tenure--
select * from (
    select customer_id, subscription_cost,
        case 
        when months_between(nvl(canceled_date, sysdate), created_date) < 3 
            then 'short_term_customer'
        when months_between(nvl(canceled_date, sysdate), created_date) between 3 and 6 
            then 'medium_term_customer'
        else 'long_term_customer'
    end as customer_tenure_segment
    from subscriptiondata
    where was_subscription_paid = 'No'
    order by customer_tenure_segment desc
) where rownum<=50;



--9.months or seasons where sign-ups spike or cancellations increase--
--Monthly Sign-ups Trend--
select 
    to_char(created_date, 'yyyy-mm') as month,
    count(customer_id) as signups
from subscriptiondata
group by to_char(created_date, 'yyyy-mm')
order by month;
--Monthly Cancellations Trend--
select 
    to_char(to_date(canceled_date, 'yyyy-mm-dd'), 'yyyy-mm') as month,
    count(customer_id) as cancellations
from subscriptiondata
where canceled_date is not null
group by to_char(to_date(canceled_date, 'yyyy-mm-dd'), 'yyyy-mm')
order by month;
-- Season-wise sign-ups and cancellations
with seasonal_signups as (
    select 
        case 
            when extract(month from created_date) in (12,1,2) then 'Winter'
            when extract(month from created_date) in (3,4,5) then 'Spring'
            when extract(month from created_date) in (6,7,8) then 'Summer'
            else 'Autumn'
        end as season,
        count(customer_id) as signups
    from subscriptiondata
    group by 
        case 
            when extract(month from created_date) in (12,1,2) then 'Winter'
            when extract(month from created_date) in (3,4,5) then 'Spring'
            when extract(month from created_date) in (6,7,8) then 'Summer'
            else 'Autumn'
        end
),
seasonal_cancellations as (
    select 
        case 
            when to_number(substr(canceled_date,6,2)) in (12,1,2) then 'Winter'
            when to_number(substr(canceled_date,6,2)) in (3,4,5) then 'Spring'
            when to_number(substr(canceled_date,6,2)) in (6,7,8) then 'Summer'
            else 'Autumn'
        end as season,
        count(customer_id) as cancellations
    from subscriptiondata
    where canceled_date is not null
    group by 
        case 
            when to_number(substr(canceled_date,6,2)) in (12,1,2) then 'Winter'
            when to_number(substr(canceled_date,6,2)) in (3,4,5) then 'Spring'
            when to_number(substr(canceled_date,6,2)) in (6,7,8) then 'Summer'
            else 'Autumn'
        end
)
select 
    s.season,
    s.signups,
    nvl(c.cancellations,0) as cancellations
from seasonal_signups s
left join seasonal_cancellations c
on s.season = c.season
order by signups desc;


--10. Lost Revenue Analysis

select 
    sum(sub.SUBSCRIPTION_COST) as total_lost_revenue,
    round(
        (sum(sub.SUBSCRIPTION_COST) / sum(case when was_subscription_paid='Yes' then sub.SUBSCRIPTION_COST else 0 end)) * 100, 
        2
    ) as lost_revenue_percentage
from subscriptiondata sub
where sub.canceled_date is not null;





