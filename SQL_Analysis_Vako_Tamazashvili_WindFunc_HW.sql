/*
Task 1
Goal:
Create a sales report that:
1. Shows top 5 customers in each sales channel
2. Calculates customer sales amount
3. Calculates sales percentage within the same channel
4. Formats values properly
5. Sorts sales descending inside each channel

Important:
Window frames are NOT used, as requested.
*/

WITH customer_sales AS (

/*
First step:
Calculate total sales amount per customer per channel.

Why GROUP BY?
Because we need aggregated sales for each customer
inside each sales channel.
*/

    SELECT
        ch.channel_desc AS channel,
        c.cust_first_name || ' ' || c.cust_last_name AS customer_name,

        SUM(s.amount_sold) AS total_sales

    FROM sh.sales s
    JOIN sh.customers c
        ON s.cust_id = c.cust_id
    JOIN sh.channels ch
        ON s.channel_id = ch.channel_id

    GROUP BY
        ch.channel_desc,
        c.cust_first_name,
        c.cust_last_name
),

ranked_customers AS (
/*
Second step:
Rank customers inside each channel by sales amount.

Why ROW_NUMBER?
We need exactly top 5 customers per channel.
ROW_NUMBER guarantees unique ranking.

PARTITION BY channel:
Ranking restarts for every sales channel.
*/

    SELECT
        channel,
        customer_name,
        total_sales,

        ROW_NUMBER() OVER (
            PARTITION BY channel
            ORDER BY total_sales DESC
        ) AS sales_rank,
/*
Calculate percentage contribution.

SUM(total_sales) OVER (PARTITION BY channel)
gives total channel sales.

No window frame is used.
*/

        (total_sales * 100.0) /
        SUM(total_sales) OVER (PARTITION BY channel)
        AS sales_percentage

    FROM customer_sales
)

/*
Final result:
Keep only top 5 customers per channel.
*/

SELECT
    channel,
    customer_name,

/*
Format sales to 2 decimal places.
*/

    TO_CHAR(total_sales, 'FM9999999990.00') AS total_sales,

/*
Format percentage to 4 decimal places
and add % sign.
*/

    TO_CHAR(sales_percentage, 'FM999990.0000') || '%' AS sales_percentage

FROM ranked_customers

WHERE sales_rank <= 5

ORDER BY
    channel,
    sales_rank;

/*
Task 2:
Create a report that displays total sales for all products
in the Photo category in the Asian region for year 2000.

Requirements:
1. Use crosstab function
2. Calculate overall report total named YEAR_SUM
3. Display sales amounts with 2 decimal places
4. Sort results by YEAR_SUM descending
5. Add comments explaining the solution

Why crosstab?
The crosstab function is useful for transforming
row-based data into pivot-table style output.
*/

-- Enable tablefunc extension for crosstab
CREATE EXTENSION IF NOT EXISTS tablefunc;

WITH photo_sales AS (

    /*
    First step:
    Calculate total sales per product for year 2000.

    Why GROUP BY?
    Because we need aggregated sales
    for each product.
    */

    SELECT
        p.prod_name,
        t.calendar_year,
        SUM(s.amount_sold) AS total_sales

    FROM sh.sales s

    JOIN sh.products p
        ON s.prod_id = p.prod_id

    JOIN sh.customers c
        ON s.cust_id = c.cust_id

    JOIN sh.countries co
        ON c.country_id = co.country_id

    JOIN sh.times t
        ON s.time_id = t.time_id

    WHERE p.prod_category = 'Photo'
      AND co.country_region = 'Asia'
      AND t.calendar_year = 2000

    GROUP BY
        p.prod_name,
        t.calendar_year
),

pivot_report AS (

    /*
    Crosstab transforms rows into columns.

    Structure:
    row_name  -> product name
    category  -> calendar year
    value     -> sales amount

    Since only year 2000 is required,
    the result will contain one year column.
    */

    SELECT *
    FROM crosstab(
        $$
        SELECT
            prod_name,
            calendar_year,
            total_sales
        FROM photo_sales
        ORDER BY prod_name, calendar_year
        $$,

        $$
        SELECT 2000
        $$
    ) AS ct (
        prod_name TEXT,
        sales_2000 NUMERIC
    )
)

SELECT
    prod_name,

    /*
    Display sales amount with 2 decimal places
    */

    TO_CHAR(sales_2000, 'FM9999999990.00') AS sales_2000,

    /*
    YEAR_SUM represents the overall total
    for the report row.

    Since only one year exists in this report,
    YEAR_SUM equals sales_2000.
    */

    TO_CHAR(sales_2000, 'FM9999999990.00') AS YEAR_SUM

FROM pivot_report

/*
Sort results by YEAR_SUM descending
*/

ORDER BY sales_2000 DESC;

/*
Task 3
Goal:
Create a sales report for customers who ranked
in the TOP 300 based on total sales
for years 1998, 1999, and 2001.

Requirements:
1. Retrieve customers ranked in top 300 sales
2. Separate calculations for each sales channel
3. Include only purchases made in the specified channel
4. Display sales with 2 decimal places
5. Add comments explaining the solution

Important:
No window frames are used.
*/

WITH yearly_customer_sales AS (

    /*
    First step:
    Calculate total sales for each customer
    per year and per sales channel.

    Why GROUP BY?
    Because we need aggregated customer sales
    for every year and channel separately.
    */

    SELECT
        t.calendar_year,
        ch.channel_desc AS sales_channel,

        c.cust_id,
        c.cust_first_name || ' ' || c.cust_last_name
            AS customer_name,

        SUM(s.amount_sold) AS total_sales

    FROM sh.sales s

    JOIN sh.customers c
        ON s.cust_id = c.cust_id

    JOIN sh.channels ch
        ON s.channel_id = ch.channel_id

    JOIN sh.times t
        ON s.time_id = t.time_id

    WHERE t.calendar_year IN (1998, 1999, 2001)

    GROUP BY
        t.calendar_year,
        ch.channel_desc,
        c.cust_id,
        c.cust_first_name,
        c.cust_last_name
),

ranked_customers AS (

    /*
    Second step:
    Rank customers inside each year
    and each sales channel separately.

    Why PARTITION BY year and channel?
    Because the task requires separate
    calculations for every sales channel
    and every year.

    Why ROW_NUMBER?
    To return exactly top 300 customers.
    */

    SELECT
        calendar_year,
        sales_channel,
        customer_name,
        total_sales,

        ROW_NUMBER() OVER (
            PARTITION BY calendar_year, sales_channel
            ORDER BY total_sales DESC
        ) AS sales_rank

    FROM yearly_customer_sales
)

SELECT
    calendar_year,
    sales_channel,
    customer_name,

    /*
    Display total sales with 2 decimal places
    */

    TO_CHAR(total_sales, 'FM9999999990.00')
        AS total_sales

FROM ranked_customers

/*
    Keep only top 300 customers
*/

WHERE sales_rank <= 300

ORDER BY
    calendar_year,
    sales_channel,
    sales_rank;

/*
Task 4
Goal:
Create a sales report for:
- January 2000
- February 2000
- March 2000

Requirements:
1. Include only Europe and Americas regions
2. Display results by months
3. Display results by product category
4. Sort product categories alphabetically
5. Add comments explaining the solution
*/

SELECT

    /*
    Extract month name for report display
    */

    TO_CHAR(t.time_id, 'Month') AS sales_month,

    /*
    Product category required by task
    */

    p.prod_category,

    /*
    Calculate total sales amount
    */

    TO_CHAR(
        SUM(s.amount_sold),
        'FM9999999990.00'
    ) AS total_sales

FROM sh.sales s

JOIN sh.times t
    ON s.time_id = t.time_id

JOIN sh.customers c
    ON s.cust_id = c.cust_id

JOIN sh.countries co
    ON c.country_id = co.country_id

JOIN sh.products p
    ON s.prod_id = p.prod_id

WHERE
    /*
    Filter only required months
    */

    t.calendar_year = 2000
    AND t.calendar_month_number IN (1, 2, 3)

    /*
    Filter only Europe and Americas regions
    */

    AND co.country_region IN ('Europe', 'Americas')

GROUP BY
    TO_CHAR(t.time_id, 'Month'),
    t.calendar_month_number,
    p.prod_category


ORDER BY
    t.calendar_month_number,
    p.prod_category;