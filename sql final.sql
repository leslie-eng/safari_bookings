set search_path to safari_connect;

select * from safari_connect.v_clean_trips;

-- ===============================================================================================================================
/*1. ROUTE ANALYSIS
* a) Which routes earn the most?
* b) Which are most popular?
* c) Which is most efficient per seat sold?
* 
* Specific route codes with KES figures. A clear top route and a clear underperformer.
*/

-- 1a) Which routes earn the most?

select 
	route_code, 
	route_from,
	route_to,
	sum(total_fare) as total_revenue
from safari_connect.v_clean_trips
group by route_code, route_from, route_to
order by total_revenue desc;

-- including the seats booked
select 
	route_code, 
	sum(seats_booked) as total_seats_booked, 
	sum(total_fare) as total_revenue
from safari_connect.v_clean_trips
group by route_code
order by total_revenue desc;

-- 1b) Which are most popular?
-- what defines a popular route? no. of seats booked per route? or rating? i doubt. bookings per route?

select 
	route_code,
	route_from,
	route_to,
	sum(seats_booked) as total_seats
from safari_connect.v_clean_trips
group by route_code, route_from, route_to
order by total_seats desc;


select
vct.route_code ,
vct.route_from , vct.route_to ,
sum(vct.seats_booked) as seats_booked,
round(sum(vct.total_fare),2) as total_revenue,
round(avg(vct.trip_rating ),2) as avg_rating
from v_clean_trips vct
group by vct.route_from ,vct.route_to , vct.route_code
order by total_revenue desc ;


-- 1c) Which is most efficient per seat sold?
-- which route makes the most money on average from each seat it sells?
-- revenue/seats

select
	route_code,
	route_from,
	route_to,
	sum(seats_booked) as seats_sold,
	sum(total_fare) as total_revenue,
	round((sum(total_fare) / sum(seats_booked)), 2) as revenue_per_seat
from safari_connect.v_clean_trips
group by route_code, route_from, route_to
order by revenue_per_seat desc;

-- ==========================================================================================================
/* 2.Driver Performance 
 * 2a) Who are the best drivers?
 * Named drivers with revenue and rating figures. A promotion recommendation with data behind it.
 * 2b) Does driver rating affect passenger satisfaction?
 * 
 * Specific route codes with KES figures. A clear top route and a clear underperformer.
 */

-- 2a)Who are the best drivers?
-- used driver_rating
select 
	driver_name, 
	sum(fare_per_seat) as total_revenue,
	avg(driver_rating) as avg_driver_rating,
	row_number() over(order by sum(fare_per_seat) desc)
from safari_connect.v_clean_trips
group by driver_name
order by avg_driver_rating desc;

-- 2b)Does driver rating affect passenger satisfaction?
-- Driver rating doesn't affect passenger satisfaction
select 
	driver_name, 
	sum(fare_per_seat) as total_revenue,
	avg(driver_rating) as avg_driver_rating,
	round(avg(trip_rating), 2) as avg_trip_rating
from safari_connect.v_clean_trips
group by driver_name
order by avg_trip_rating desc;

-- 2B driver ranking - overall + by vehicle type
WITH driver_totals AS (
    SELECT
        driver_name,
        vehicle_type,
        COUNT(*)             AS total_trips,
        SUM(total_fare)    AS total_revenue,
        ROUND(AVG(trip_rating),2) AS avg_passenger_rating
    FROM v_clean_trips
    GROUP BY driver_name, vehicle_type
)
SELECT
    driver_name, vehicle_type, total_trips, total_revenue, avg_passenger_rating,
    RANK() OVER (ORDER BY total_revenue DESC)                        AS overall_rank,
    RANK() OVER (PARTITION BY vehicle_type ORDER BY total_revenue DESC) AS vehicle_rank
FROM driver_totals
ORDER BY overall_rank;

-- 2c- Does driver rating predict passenger satisfaction
SELECT
    CASE
        WHEN driver_rating >= 4.5 THEN 'High-rated'
        ELSE 'Standard'
    END AS driver_group,
    round(AVG(trip_rating),2) AS avg_passenger_rating
FROM safari_connect.v_clean_trips vct
GROUP BY driver_group
ORDER BY avg_passenger_rating DESC;


-- ==========================================================================================================
/* Revenue Trends 
 * 3a) How is revenue changing month by month?
 * 
 * 
 * Month-over-month change with % growth. A trend direction - growing or declining?
 */

-- 3a) How is revenue changing month by month?
with monthly_revenue as (
	select
	travel_month,
	sum(total_fare) as total_revenue
	from safari_connect.v_clean_trips
	group by 1)
select
	travel_month,
	total_revenue,
	lag(total_revenue) over (order by travel_month) as prev_month_rev
from monthly_revenue
order by travel_month;


-- -- Month-over-month change with % growth. A trend direction - growing or declining?
with monthly_revenue as (
	select
	travel_month,
	sum(total_fare) as total_revenue
	from safari_connect.v_clean_trips
	group by 1)
select
	travel_month,
	total_revenue,
	lag(total_revenue) over (order by travel_month) as prev_month_revenue,
	round(100.0 * (total_revenue - lag(total_revenue) over (order by travel_month))
	/ lag(total_revenue) over (order by travel_month), 2) as mom_pct_change
from monthly_revenue
order by travel_month;

-- Month-over-month change with % growth. A trend direction - growing or declining?
-- with actual month on month revenue change
with monthly_revenue as (
	select
	travel_month,
	sum(total_fare) as total_revenue
	from safari_connect.v_clean_trips
	group by 1)
select
	travel_month,
	total_revenue,
	lag(total_revenue) over (order by travel_month) as prev_month_revenue,
	total_revenue - lag(total_revenue) over (order by travel_month) as mom_rev_change,
	round(100.0 * (total_revenue - lag(total_revenue) over (order by travel_month))
	/ lag(total_revenue) over (order by travel_month), 2) as mom_pct_change
from monthly_revenue
order by travel_month;


-- What are our best and worst months?
select travel_month, sum(total_fare) as mon_total_fare
from safari_connect.v_clean_trips
group by 1
order by mon_total_fare desc
limit 1;

-- max
select travel_month, sum(total_fare) as mon_total_fare
from safari_connect.v_clean_trips
group by 1
order by mon_total_fare desc
limit 1;

--min
select travel_month, sum(total_fare) as mon_total_fare
from safari_connect.v_clean_trips
group by 1
order by mon_total_fare
limit 1;

-- 3B - running total of revenue
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', departure_date) AS month,
        SUM(total_fare) AS monthly_revenue
    FROM safari_connect.v_clean_trips
    GROUP BY 1
)
SELECT
    month,
    monthly_revenue,
    SUM(monthly_revenue) OVER (
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM monthly_revenue
ORDER BY month;

-- 3C - Best and worst 3 months
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', departure_date) AS month,
        SUM(total_fare) AS revenue
    FROM safari_connect.v_clean_trips
    GROUP BY 1
),
ranked_revenue AS (
    SELECT
        month,
        revenue,
        RANK() OVER (ORDER BY revenue DESC) AS top_rank,
        RANK() OVER (ORDER BY revenue ASC) AS bottom_rank
    FROM monthly_revenue
)
SELECT
    month,
    revenue,
    CASE
        WHEN top_rank <= 3 THEN 'Top 3'
        WHEN bottom_rank <= 3 THEN 'Bottom 3'
    END AS revenue_group
FROM ranked_revenue
WHERE top_rank <= 3
   OR bottom_rank <= 3
ORDER BY revenue DESC;

--3D - Revenue by route per month (pivot)
SELECT
    DATE_TRUNC('month', departure_date) AS month,
    SUM(CASE
        WHEN route_code = 'RT001' THEN total_fare
        ELSE 0
    END) AS rt001_revenue,
    SUM(CASE
        WHEN route_code = 'RT002' THEN total_fare
        ELSE 0
    END) AS rt002_revenue,
    SUM(CASE
        WHEN route_code = 'RT003' THEN total_fare
        ELSE 0
    END) AS rt003_revenue
FROM safari_connect.v_clean_trips
GROUP BY 1
ORDER BY month;

-- question 4 passenger insights
-- 4A top passenger cities
select passenger_city, 
count(*) as total_bookings, 
sum(seats_booked) as total_seats,
sum(total_fare) as total_revenue,
avg(fare_per_seat) as  avg_fare
from safari_connect.v_clean_trips
group by 1
order by total_bookings desc 
limit 3;

-- 4B - Gender split and seat class preference
SELECT
    passenger_gender,
    -- Bookings
    SUM(CASE
        WHEN seat_class = 'Economy' THEN 1
        ELSE 0
    END) AS total_economy,
    SUM(CASE
        WHEN seat_class = 'Business' THEN 1
        ELSE 0
    END) AS total_business,
    -- Revenue
    SUM(CASE
        WHEN seat_class = 'Economy' THEN total_fare
        ELSE 0
    END) AS economy_revenue,
    SUM(CASE
        WHEN seat_class = 'Business' THEN total_fare
        ELSE 0
    END) AS business_revenue
FROM safari_connect.v_clean_trips
GROUP BY passenger_gender;


-- 4c - satisfaction breakdown (CTE)
WITH sat_counts AS (
    SELECT satisfaction, COUNT(*) AS cnt
    FROM v_clean_trips
    GROUP BY satisfaction
)
SELECT
    satisfaction,
    cnt,
    ROUND(cnt * 100.0 / SUM(cnt) OVER (), 1) AS pct
FROM sat_counts ORDER BY cnt DESC;

-- 4D passenger quarntiles by spend(NTILE)
WITH total_spend_per_passenger AS (
    SELECT
        passenger_name,
        SUM(total_fare) AS total_spent,
        NTILE(4) OVER (
            ORDER BY SUM(total_fare) ASC
        ) AS quartile
    FROM v_clean_trips
    GROUP BY passenger_name
)
SELECT
    passenger_name,
    total_spent,
    CASE
        WHEN quartile = 4 THEN 'Top Spender'
        ELSE quartile::TEXT
    END AS quartile
FROM total_spend_per_passenger
ORDER BY total_spent DESC;


-- question 5 Cancellations and Lost Revenue
-- 5A overall status breakdown
select booking_status, count(*) as total_booking
from safari_connect.bookings
group by 1;

-- 5B - Canellation rate by route
SELECT
    route_code,
    route_from || ' → ' || route_to                           AS route,
    COUNT(*)                                                              AS total,
    SUM(CASE WHEN booking_status = 'Completed' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
    SUM(CASE WHEN booking_status = 'No Show'  THEN 1 ELSE 0 END) AS no_show,
    ROUND(SUM(CASE WHEN booking_status IN ('Cancelled','No Show')
             THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS cancel_rate_pct
FROM safari_connect.bookings
GROUP BY route_code, route_from, route_to
ORDER BY cancel_rate_pct DESC;

-- Revenue lost from cancellations and no-shows
select booking_status, sum(total_fare)
from safari_connect.bookings
where booking_status = 'Cancelled'
group by 1;

-- question 6 - operational patterns
-- 6A revenue by day of week
SELECT
    EXTRACT(DOW FROM departure_date)          AS day_num,
    TO_CHAR(departure_date, 'Day')            AS day_name,
    COUNT(*)                                  AS total_bookings,
    SUM(total_fare)                         AS total_revenue,
    ROUND(AVG(total_fare), 2)          AS avg_booking_value
FROM safari_connect.v_clean_trips
GROUP BY EXTRACT(DOW FROM departure_date), TO_CHAR(departure_date, 'Day')
ORDER BY day_num;

-- 6B - busiest depature times
select departure_time, 
sum(seats_booked) as total_seats,
row_number() over(order by sum(seats_booked) desc)
from v_clean_trips vct
group by 1;

-- 6c seat utilisation by vehicle type
with avg_seat_vehicle_type as (
select vehicle_type, 
AVG(seats_booked) as avg_seats 
from safari_connect.bookings
group by 1)
select vehicle_type, round(avg_seats, 1),
case 
	when avg_seats > 3 then 'High Load'
	when avg_seats between 2 and 3 then 'Medium Load'
	when avg_seats < 2 then 'Low Load'
end as seat_rating
from avg_seat_vehicle_type;



select * from v_clean_trips vct;
-- View 1: Route performance
CREATE OR REPLACE VIEW v_route_performance AS
-- paste your 1A query here
select 
	route_code, 
	route_from,
	route_to,
	sum(total_fare) as total_revenue
from safari_connect.v_clean_trips
group by route_code, route_from, route_to
order by total_revenue desc;


-- View 2: Driver performance
CREATE OR REPLACE VIEW v_driver_performance AS
-- paste your 2A query here
select 
	driver_name, 
	sum(fare_per_seat) as total_revenue,
	avg(driver_rating) as avg_driver_rating,
	row_number() over(order by sum(fare_per_seat) desc)
from safari_connect.v_clean_trips
group by driver_name
order by avg_driver_rating desc;


-- View 3: Monthly revenue trend
CREATE OR REPLACE VIEW v_monthly_revenue AS
-- paste your 3A query (the CTE) here
with monthly_revenue as (
	select
	travel_month,
	sum(total_fare) as total_revenue
	from safari_connect.v_clean_trips
	group by 1)
select
	travel_month,
	total_revenue,
	lag(total_revenue) over (order by travel_month) as prev_month_rev
from monthly_revenue
order by travel_month;


-- View 4: Cancellation analysis
CREATE OR REPLACE VIEW v_cancellation_analysis AS
-- paste your 5B query here
SELECT
    route_code,
    route_from || ' → ' || route_to                           AS route,
    COUNT(*)                                                              AS total,
    SUM(CASE WHEN booking_status = 'Completed' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
    SUM(CASE WHEN booking_status = 'No Show'  THEN 1 ELSE 0 END) AS no_show,
    ROUND(SUM(CASE WHEN booking_status IN ('Cancelled','No Show')
             THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS cancel_rate_pct
FROM safari_connect.bookings
GROUP BY route_code, route_from, route_to
ORDER BY cancel_rate_pct DESC;


-- View 5: Passenger city insights
CREATE OR REPLACE VIEW v_passenger_insights AS
-- paste your 4A query here
select passenger_city, 
count(*) as total_bookings,
sum(seats_booked) as total_seats,
sum(total_fare) as total_revenue,
avg(total_fare) as avg_fare
from safari_connect.v_clean_trips
group by 1
order by total_bookings desc
limit 3;

-- Add Indexes
CREATE INDEX idx_bookings_depdate     ON bookings (departure_date);
CREATE INDEX idx_bookings_route       ON bookings (route_code);
CREATE INDEX idx_bookings_driver      ON bookings (driver_name);
CREATE INDEX idx_bookings_status      ON bookings (booking_status);
CREATE INDEX idx_bookings_payment     ON bookings (payment_method);
CREATE INDEX idx_bookings_vehicle     ON bookings (vehicle_type);
CREATE INDEX idx_bookings_passcity    ON bookings (passenger_city);

SELECT tablename, indexname FROM pg_indexes
WHERE schemaname = 'safari_connect';


select * from safari_connect.v_clean_trips;
select * from safari_connect.bookings;