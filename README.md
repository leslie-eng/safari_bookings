## What happens to the data collected by a logistic company?
In Kenya we have a lot of data that is collected by logistics companies such as Easy Coach, North Rift and Super metro. I was curious about how they analyse their data and I had some suggestions that might improve their mode of operations. As a data analyst, I had to connect to their servers using a connection string and I managed to pull their data into a staging area where it can't alter the main database that is currently being read and written on by users. 
## What kind of data do we have?
I managed to create a staging area where the headers were completely transformed to text so that data cleaning could be done. 

```
create schema if not exists safari_connect;

create table if not exists safari_connect.booking_safari_staging(
booking_id text,
passenger_name text,
passenger_phone text,
passenger_gender text,
passenger_city text,
route_code text,
route_from text, 
route_to text,
vehicle_plate text,
vehicle_type text, 
driver_name text, 
driver_rating text, 
departure_date text,
departure_time text,
seat_class text,
seats_booked text,
fare_per_seat text,
total_fare text, 
payment_method text,
booking_status text,
trip_rating text);

set search_path to booking_safari_staging;
show search_path;
```
Once the data has been loaded, we can display it so that we study how dirty it is. 

![A sample of the dirty data](https://dev-to-uploads.s3.us-east-2.amazonaws.com/uploads/articles/hzd5wksn3xdtizr2l616.png)

## How do we clean this data?
We will begin from the passenger names and driver names. They have some capitalization issues and spaces in between. To sort this out, we use the following functions; initcap() to set the first letter of each word to capital and trim() to remove the leading and trailing spaces from a text string.

```
update safari_connect.safari_clean_staging
set passenger_name = trim(initcap(passenger_name))
where passenger_name is not null;
```
The expected outcome should look like this:

![Passenger names](https://dev-to-uploads.s3.us-east-2.amazonaws.com/uploads/articles/ewuvbnek2mnuqw09c869.png)

### We will normalize the phone numbers by using a case when, which will loop through the values and check to find any characters such as '-' and remove them globally. This is done using the regexp_replace() and like function. To remove the '+254' and append the '0', we use substring which extracts a specific portion of the text string based on a designated starting position and stopping position.

```
update safari_connect.safari_clean_staging
set passenger_phone = (case 
		when passenger_phone like '%-%' then regexp_replace(passenger_phone, '[^0-9]', '', 'g')
		WHEN passenger_phone LIKE '+254%' THEN '0' || SUBSTRING(passenger_phone, 5)
		when trim(passenger_phone) = '' then null
		else passenger_phone
	end)
where passenger_phone is not null;
```

We normalize the date formats, which will be crucial during the analysis of the data. The to_date() function is able to convert different date formats to a common one, 'YYYY-MM-DD'. Here is where the biggest challenge occurred since to_date() can't automatically convert a date string that is in this format : 'MM-DD-YYYY' or 'MM-DD-YY'. When a basic code is run to convert it an error occurs as seen below.

> The conversion of 2024-13-05 is out of range


To solve this issue, we have to check whether the text matches a date format pattern the any formats that have the month or date in the middle that are greater than or less than 12 can be categorized accordingly. A function called split_part is used to solve this issue.


```CASE
        -- DD/MM/YYYY
        WHEN departure_date ~ '^\d{2}/\d{2}/\d{4}$'
            THEN TO_DATE(departure_date, 'DD/MM/YYYY')
        -- YYYY-MM-DD
        WHEN departure_date ~ '^\d{4}-\d{2}-\d{2}$'
            THEN TO_DATE(departure_date, 'YYYY-MM-DD')
        -- DD-MM-YY
        WHEN departure_date ~ '^\d{2}-\d{2}-\d{2}$'
            THEN TO_DATE(departure_date, 'DD-MM-YY')
        -- MM-DD-YYYY where middle number is > 12
        WHEN departure_date ~ '^\d{2}-\d{2}-\d{4}$'
             AND SPLIT_PART(departure_date, '-', 2)::INT > 12
            THEN TO_DATE(departure_date, 'MM-DD-YYYY')
        -- DD-MM-YYYY where middle number is <= 12
        WHEN departure_date ~ '^\d{2}-\d{2}-\d{4}$'
             AND SPLIT_PART(departure_date, '-', 2)::INT <= 12
            THEN TO_DATE(departure_date, 'DD-MM-YYYY')
        ELSE NULL
    end)
```
We have to normalize the numeric columns by removing the currency in the prefix and removing the extra spaces.

```
-- normalize the fare per seat
update safari_connect.safari_clean_staging
set fare_per_seat = (regexp_replace(fare_per_seat , '[^0-9]', '', 'g')
)
where fare_per_seat is not null;
```
This process was repeated for other columns that had similar issues.

## How is the data analysed without a visual?
Once the data was transformed, a view is created to analyze the data. The data is converted to the most appropriate data type, then a simple filter of selecting the booking_status where passengers completed their trip.

```
CREATE OR REPLACE VIEW safari_connect.v_clean_trips AS
SELECT *,
    TO_CHAR(departure_date, 'YYYY-MM')    AS travel_month,
    TO_CHAR(departure_date, 'Month YYYY') AS month_label,
    TO_CHAR(departure_date, 'Day')        AS day_name,
    EXTRACT(Day FROM departure_date)    AS month_num,
    EXTRACT(DOW FROM departure_date)      AS day_of_week,
    (fare_per_seat * seats_booked)           AS calculated_fare,
    CASE
        WHEN trip_rating BETWEEN 4 AND 5 THEN 'Satisfied'
        WHEN trip_rating = 3 THEN 'Neutral'
        WHEN trip_rating BETWEEN 1 AND 2 THEN 'Unsatisfied'
        ELSE 'No Rating'
    END AS satisfaction
FROM safari_clean_staging
WHERE booking_status = 'Completed';

-- Test
SELECT * FROM v_clean_trips;
```
After the table is created, this is what we expect:

![v_clean_trips](https://dev-to-uploads.s3.us-east-2.amazonaws.com/uploads/articles/nm983um6dbg2p2x5elvb.png)

We can start to examine the cleaned data and some major questions that will give us a direction.
1a) which routes earn the most?

```select 
	route_code, 
	route_from,
	route_to,
	sum(total_fare) as total_revenue,
	rank() over(order by sum(total_fare) desc)
from safari_connect.v_clean_trips
group by route_code, route_from, route_to;
```
The expected result is shown below: 

![Routes that earn the most](https://dev-to-uploads.s3.us-east-2.amazonaws.com/uploads/articles/a24fpop8l80d0vhxbstu.png)

From the result, Nairobi to Mombasa is the route that earns the most revenue between the specified period by KES 51,600.

1b) Which is the most popular route? 
What defines a popular route? No of seats booked per route or rating? Our conclusion was that most seats booked is a popular option since it shows the amount of traffic and the highest rated route shows the amount of satisfaction.

```
select 
	route_code,
	route_from,
	route_to,
	sum(seats_booked) as total_seats
from safari_connect.v_clean_trips
group by route_code, route_from, route_to
order by total_seats desc;
```
The expected outcome is shown below:

![Most popular route](https://dev-to-uploads.s3.us-east-2.amazonaws.com/uploads/articles/bcgqchjw63wcakke6w42.png)

From the result shown, Nairobi to Thika route is the most popular with 62 seats booked.

The typical management wouldn't want to see the sql results, but would opt for a visualization using tools such as power BI or tableau.
 
![Power BI dashbaord](https://dev-to-uploads.s3.us-east-2.amazonaws.com/uploads/articles/9uvlz0uu65u29nz5crqp.png)

## Which insights can we learn from the dashboard shown below?
The dashboard is divided into different sections such as a barchart with the revenue for each route, KPIs, table with each route and the average rating and lastly a line chart with months showing the progression of revenue. 
1. The company has made KES 220,000 in revenue over a 6 month period.
2. The highest earning route is RT001, Nairobi to Mombasa
3. The total seats booked was 452.
4. The best performing vehicle type was the matatu, then bus and minibus followed.

The last bit that gives us more information is the drill down page that isolates a particular route and identifies key metrics such as driver with the highest revenue per route and driver with the highest rating. 

![Route Drill Through](https://dev-to-uploads.s3.us-east-2.amazonaws.com/uploads/articles/ud0h7nlpx818oovxy7oz.png)

## What recommendations are we providing?
1. Moses Kipchoge, the driver with the highest rating would get a promotion since he has been consistent with the quality of the work that he provides. 
2. Improve passenger experience since the average rating was 3.5. We need it to be at least 4.0
3. Optimize routes RT001, RT002 and RT004
4. Reduce the 12.1% cancellation.no-show rate by changing cancellation policies whereby you have 48 hours to cancel a ticket.
5. Introduce route level pricing and capacity management.
