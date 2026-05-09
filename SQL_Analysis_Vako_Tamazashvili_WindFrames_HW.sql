-- Task 1

SELECT 
    t.country_region,
    t.calendar_year,
    t.channel_desc,
    t.amount_sold,
    
    ROUND(
        100 * t.amount_sold
        / SUM(t.amount_sold) OVER (
            PARTITION BY t.country_region, t.calendar_year
        ),
        2
    ) AS "% BY CHANNELS",

    ROUND(
        LAG(
            100 * t.amount_sold
            / SUM(t.amount_sold) OVER (
                PARTITION BY t.country_region, t.calendar_year
            )
        ) OVER (
            PARTITION BY t.country_region, t.channel_desc
            ORDER BY t.calendar_year
        ),
        2
    ) AS "% PREVIOUS PERIOD",

    ROUND(
        (
            100 * t.amount_sold
            / SUM(t.amount_sold) OVER (
                PARTITION BY t.country_region, t.calendar_year
            )
        )
        -
        LAG(
            100 * t.amount_sold
            / SUM(t.amount_sold) OVER (
                PARTITION BY t.country_region, t.calendar_year
            )
        ) OVER (
            PARTITION BY t.country_region, t.channel_desc
            ORDER BY t.calendar_year
        ),
        2
    ) AS "% DIFF"

FROM (
    SELECT
        co.country_region,
        ti.calendar_year,
        ch.channel_desc,
        SUM(s.amount_sold) AS amount_sold
    FROM sales s
    JOIN customers cu
        ON s.cust_id = cu.cust_id
    JOIN countries co
        ON cu.country_id = co.country_id
    JOIN times ti
        ON s.time_id = ti.time_id
    JOIN channels ch
        ON s.channel_id = ch.channel_id
    WHERE ti.calendar_year BETWEEN 1999 AND 2001
      AND co.country_region IN ('Americas', 'Asia', 'Europe')
    GROUP BY
        co.country_region,
        ti.calendar_year,
        ch.channel_desc
) t

ORDER BY
    t.country_region,
    t.calendar_year,
    t.channel_desc;

-- Task 2

WITH daily_sales AS (
    SELECT
        t.calendar_week_number,
        t.time_id,
        t.day_name,
        t.calendar_date,
        SUM(s.amount_sold) AS amount_sold
    FROM sales s
    JOIN times t
        ON s.time_id = t.time_id
    WHERE t.calendar_year = 1999
      AND t.calendar_week_number IN (49, 50, 51)
    GROUP BY
        t.calendar_week_number,
        t.time_id,
        t.day_name,
        t.calendar_date
)

SELECT
    calendar_week_number,
    calendar_date,
    day_name,
    amount_sold,

    SUM(amount_sold) OVER (
        PARTITION BY calendar_week_number
        ORDER BY calendar_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cum_sum,

    ROUND(
        AVG(amount_sold) OVER (
            ORDER BY calendar_date
            RANGE BETWEEN INTERVAL '2 day' PRECEDING
                  AND INTERVAL '2 day' FOLLOWING
        ),
        2
    ) AS centered_3_day_avg

FROM daily_sales
ORDER BY calendar_date;

-- Task 3.1 Rows frame

SELECT
    t.calendar_date,
    SUM(s.amount_sold) AS daily_sales,

    SUM(SUM(s.amount_sold)) OVER (
        ORDER BY t.calendar_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_3_day_sum

FROM sales s
JOIN times t
    ON s.time_id = t.time_id
GROUP BY t.calendar_date
ORDER BY t.calendar_date;

/* why rows? rows counts physical rows relative to the current row. here we need exactly current day
and previous 2 rows(days) this makes rows ideal for rolling totals or moving averages based
on a fixed number of records.

Task 3.2 Range frame  */

SELECT
    t.calendar_date,
    SUM(s.amount_sold) AS daily_sales,

    AVG(SUM(s.amount_sold)) OVER (
        ORDER BY t.calendar_date
        RANGE BETWEEN INTERVAL '3 day' PRECEDING
                  AND CURRENT ROW
    ) AS avg_last_3_days

FROM sales s
JOIN times t
    ON s.time_id = t.time_id
GROUP BY t.calendar_date
ORDER BY t.calendar_date;

/* Why range? Range works with value intervals rather than physical rows. this Frame includes
all rows within 3 calendar days before the current date. Useful when dates may be missing and 
calculations should follow actual time intervals rather than row counts. 

Task 3.3 Groups frame */

SELECT
    channel_id,
    amount_sold,

    SUM(amount_sold) OVER (
        ORDER BY amount_sold
        GROUPS BETWEEN 1 PRECEDING AND CURRENT ROW
    ) AS grouped_running_total

FROM sales
ORDER BY amount_sold;

/* Why Groups? Groups processes peer groups instead of individual rows. rows having the same
amount_sold value are treated as one group. This is iseful when duplicate order by values
should be handled together instead of separately, ensuring fair aggregation across tied values. */


