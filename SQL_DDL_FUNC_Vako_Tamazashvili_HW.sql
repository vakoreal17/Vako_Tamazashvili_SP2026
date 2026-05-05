/* Task 1 View:
View: sales_revenue_by_category_qtr
Purpose: Shows total sales revenue grouped by film category for the current quarter and 
current year

Design decisions : 1. Current quarter: We use date_trunc ('quarter', current_date) -> gives 
first day of current quarter

2. Current year: extract(year from current_date)

3. filtering only current quarter data:
payment_date >= start_of_quarter
AND payment_date < start_of_next_quarter

4.Why only categories with sales appear: We use inner join + group by -> only categories
with matching payment records will appear

5. Zero-sales categories excluded: because inner join eliminates categories without matches.

6.Dynamic behaviour: current_date ensures this view automatically updates whjen quarter/year
changes.

7. Note about data: default dvd rental db may not contain current year data. To verify logic,
test queris below simulate behavior 
*/

CREATE OR REPLACE VIEW sales_revenue_by_category_qtr AS
SELECT 
    c.name AS category_name,
    SUM(p.amount) AS total_revenue
FROM category c
JOIN film_category fc ON c.category_id = fc.category_id
JOIN film f ON f.film_id = fc.film_id
JOIN inventory i ON i.film_id = f.film_id
JOIN rental r ON r.inventory_id = i.inventory_id
JOIN payment p ON p.rental_id = r.rental_id
WHERE 
    p.payment_date >= DATE_TRUNC('quarter', CURRENT_DATE)
    AND p.payment_date < DATE_TRUNC('quarter', CURRENT_DATE) + INTERVAL '3 months'
GROUP BY c.name
HAVING SUM(p.amount) > 0;

-- Test version for verification only, lets replace current_date with '2007-02-15'

SELECT 
    c.name,
    SUM(p.amount)
FROM category c
JOIN film_category fc ON c.category_id = fc.category_id
JOIN film f ON f.film_id = fc.film_id
JOIN inventory i ON i.film_id = f.film_id
JOIN rental r ON r.inventory_id = i.inventory_id
JOIN payment p ON p.rental_id = r.rental_id
WHERE 
    p.payment_date >= DATE_TRUNC('quarter', DATE '2007-02-15')
    AND p.payment_date < DATE_TRUNC('quarter', DATE '2007-02-15') + INTERVAL '3 months'
GROUP BY c.name;

-- valid test
SELECT *
FROM sales_revenue_by_category_qtr;

-- we expect only categories with sales here, revenue aggregated per category.


-- Edge case test

SELECT *
FROM sales_revenue_by_category_qtr
WHERE 1 = 0;

-- we expect empty result set here, however no error occurs. this safely should return 0 rows.

/* what happens in edge scenarios : 
1. Inccorect input parameters - not applicable (view has no parameters)
2. missing required data - for example we have no payment in current quarter. result - view returns
empty result. No crash, no null aggregation.
*/

-- Task 2 - Query language function

/* Purpose : returns total sales revenue grouped by category for the quarter and yer
derived from the input parameter.
Why parameter is needed: unlike the view(which uses current_date dynamically), this function
allows: analyzing historical quarters, testing specific periods, reusability in reports.
How quarter is determined: date_trunc('quarter', p_date) -> start of the quarter.
End of quarter: start_of_quarter + interval '3 months' 
How result is calculated: SUM(payment.amount) grouped by category
Why only categories with sales appear: inner join ensures only categories with matching payments
how zero-sales are excluded: having SUM(amount) > 0 removes zero/null totals.

Edge case handling: 1. invalid quarter(null or bad input): function does not allow raise
exception directly, we enforce validation using where p_date IS NOT NULL, if Null then it returns 
empty result(safe behavior)

2. No data exists: function returns empty set, no error occurs.
*/

CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr(p_date DATE)
RETURNS TABLE (
    category_name TEXT,
    total_revenue NUMERIC
)
LANGUAGE SQL
AS $$
    SELECT 
        c.name AS category_name,
        SUM(p.amount) AS total_revenue
    FROM category c
    JOIN film_category fc ON c.category_id = fc.category_id
    JOIN film f ON f.film_id = fc.film_id
    JOIN inventory i ON i.film_id = f.film_id
    JOIN rental r ON r.inventory_id = i.inventory_id
    JOIN payment p ON p.rental_id = r.rental_id
    WHERE 
        p_date IS NOT NULL
        AND p.payment_date >= DATE_TRUNC('quarter', p_date)
        AND p.payment_date < DATE_TRUNC('quarter', p_date) + INTERVAL '3 months'
    GROUP BY c.name
    HAVING SUM(p.amount) > 0;
$$;

-- valid input using known DVD dataset date
SELECT * 
FROM get_sales_revenue_by_category_qtr('2007-02-15');

-- Expected result: returns categories with revenue, aggregated totals per category

-- Edge / invalid input
SELECT * 
FROM get_sales_revenue_by_category_qtr(NULL);

-- expected result : returns only empty result set. p_date IS NOT NULL prevents execution of
-- invalid logic, no crash.

-- if invalid quarter is passed, it also returns empty result
SELECT * 
FROM get_sales_revenue_by_category_qtr(NULL);

-- if no data exists

SELECT * 
FROM get_sales_revenue_by_category_qtr('2030-01-01');

-- returns 0 rows. inner join removes non-matching categories.

-- Task 3 - Procedure Language Function

/* Purpose : returns the most popular films for each gives country.
how most popular is defined : Based on total rental count (number of rentals per film) this
reflects actual user engagement not just price
how result is calculated : 1.Join customer -> address -> city-> country  to identify
customers country. 
2. join rental -> inventory -> film
3.count rentals per film per country
4. rank films per country using dense_rank()

How ties are handled : using dense_rank(), if multiple films have the same highest rental count 
ALL are returned (rank = 1)

what happens if country has no data: function raises exception: 'no data found for country: X'

Why array parameter: it allows querying multiple countries in one call, more efficient and reusable

validation: Checks null or empty array, checks if countries exist in db.
*/


CREATE OR REPLACE FUNCTION core.most_popular_films_by_countries(p_countries TEXT[])
RETURNS TABLE (
    country TEXT,
    film TEXT,
    rating TEXT,
    language TEXT,
    length INT,
    release_year INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_country TEXT;
BEGIN
	
-- validation : null or empty input

IF p_countries IS NULL OR array_length(p_countries, 1) IS NULL THEN
        RAISE EXCEPTION 'Input country array cannot be NULL or empty';
    END IF;

	FOREACH v_country IN ARRAY p_countries LOOP
        IF NOT EXISTS (
            SELECT 1 FROM country WHERE country = v_country
        ) THEN
            RAISE EXCEPTION 'Country "%" does not exist', v_country;
        END IF;
    END LOOP;
	
-- main query

RETURN QUERY
    WITH ranked_films AS (
        SELECT 
            co.country,
            f.title,
            f.rating,
            l.name AS language,
            f.length,
            f.release_year,
            COUNT(r.rental_id) AS rental_count,
            DENSE_RANK() OVER (
                PARTITION BY co.country
                ORDER BY COUNT(r.rental_id) DESC
            ) AS rank
        FROM country co
        JOIN city ci ON ci.country_id = co.country_id
        JOIN address a ON a.city_id = ci.city_id
        JOIN customer cu ON cu.address_id = a.address_id
        JOIN rental r ON r.customer_id = cu.customer_id
        JOIN inventory i ON i.inventory_id = r.inventory_id
        JOIN film f ON f.film_id = i.film_id
        JOIN language l ON l.language_id = f.language_id
        WHERE co.country = ANY(p_countries)
        GROUP BY 
            co.country, f.title, f.rating, l.name, f.length, f.release_year
    )
    SELECT 
        country,
        title AS film,
        rating,
        language,
        length,
        release_year
    FROM ranked_films
    WHERE rank = 1;

-- check: no data case

IF NOT FOUND THEN
        RAISE EXCEPTION 'No rental data found for given countries';
    END IF;

END;
$$;

-- Test queries, valid input

SELECT * 
FROM core.most_popular_films_by_countries(
    ARRAY['Afghanistan','Brazil','United States']
);

-- expected result : one or more films per country, only top-ranked films (rank = 1), includes 
-- ties if same rental count.

-- edge case 1: non-existing country.
SELECT * 
FROM core.most_popular_films_by_countries(
    ARRAY['Narnia']
);

-- result - error: country 'Narnia' does not exist in the database.

-- Edge case 2: country with no rentals

SELECT * 
FROM core.most_popular_films_by_countries(
    ARRAY['Greenland']
);

-- Result - error: no rental data found for given countries.(exception)

-- Task 4

/* Purpose: returns films matching title pattern that are currently in stock along with rental 
details.

how pattern matching works: ILIKE is used(case-insensitive), '%' wildcard matches any sequence 
of characters
Case sensitivity: ILIKE ensures 'LOVE' = 'love' = 'Love'
Performance: filtering by title happens first(CTE). Reduces rows before joins. Potential
bottleneck: ILIKE '%pattern%' (can be improved with pg_trgm index) 

Multiple matches returns all matching rentals, no matches raises exception.
*/


CREATE OR REPLACE FUNCTION core.films_in_stock_by_title(p_title_pattern TEXT)
RETURNS TABLE (
    row_num BIGINT,
    film_title TEXT,
    language TEXT,
    customer_name TEXT,
    rental_date TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
	
-- validation
	
	IF p_title_pattern IS NULL OR TRIM(p_title_pattern) = '' THEN
        RAISE EXCEPTION 'Title pattern cannot be NULL or empty';
    END IF;
	
-- main query

RETURN QUERY
    WITH filtered_films AS (
        SELECT f.film_id, f.title, f.language_id
        FROM film f
        WHERE f.title ILIKE p_title_pattern
    ),
    available_inventory AS (
        -- Only inventory that is NOT currently rented
        SELECT i.inventory_id, i.film_id
        FROM inventory i
        LEFT JOIN rental r 
            ON r.inventory_id = i.inventory_id
            AND r.return_date IS NULL
        WHERE r.rental_id IS NULL
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY f.title) + 99 AS row_num,  -- starts from 100
        f.title AS film_title,
        l.name AS language,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        r.rental_date
    FROM filtered_films f
    JOIN language l ON l.language_id = f.language_id
    JOIN available_inventory ai ON ai.film_id = f.film_id
    LEFT JOIN rental r ON r.inventory_id = ai.inventory_id
    LEFT JOIN customer c ON c.customer_id = r.customer_id;
	IF NOT FOUND THEN
        RAISE EXCEPTION 'No films found matching pattern: %', p_title_pattern;
    END IF;

END;
$$;
-- no match check.

-- Test queries, Valid 

SELECT * 
FROM core.films_in_stock_by_title('%love%');

-- returns films containing 'love', includes language, customer, rental date.

SELECT * 
FROM core.films_in_stock_by_title('%zzzz%');

-- returns error: no films found matching pattern

SELECT * 
FROM core.films_in_stock_by_title('');
-- returns error as well: Title pattern cannot be null or empty


/* Clarification: films in stock means not currently rented, but output includes customer_name, 
rental_date. these come from past rentals not current stock.
How this solution handles it: inventory must be available now(not actively rented) but we still
show historical rental ifno(if exists) 

Behaviour explanation. ILIKE '%love%' matches-> 'love story', 'my lovely film', 'endless LOVE'.

fully case-insensitive via ILIKE

Multiple matches: All rows returned, numbered using: Row_number() + 99

no matches - raises exception prevents silent empty result
*/

-- Task 5

/* purpose: inserts a new movie into the film table with: Auto-generated film_id, default
rental_rate = 4.99, rental_duration = 3, replacement cost = 19.99.

How unique id is generated: Uses serial/sequence behind film.film_id.
Default insert lets postgreSQL auto-generate unique ID

How duplicates are prevented: Checks if film title already exists (case insensitive), and uses
lower(title) comparison

what happens if movie exists: raises exception 'movie already exists'

language validation: looks up language_id from language table, if not found it raises exception.

what happens if insertion fails: Transaction automatically rolls back, exception is raised 
with error message

how consistency is preserved: atomic transaction(function execution) either full insert succeeds
or fails entirely.
*/


CREATE OR REPLACE FUNCTION core.new_movie(
    p_title TEXT,
    p_release_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
    p_language_name TEXT DEFAULT 'Klingon'
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_language_id INT;
BEGIN

-- validation: title
	IF p_title IS NULL OR TRIM(p_title) = '' THEN
        RAISE EXCEPTION 'Movie title cannot be NULL or empty';
    END IF;
-- duplicate check
	 IF EXISTS (            
        SELECT 1 FROM film               
        WHERE LOWER(title) = LOWER(p_title)
    ) THEN
        RAISE EXCEPTION 'Movie "%" already exists', p_title;
    END IF;
-- language validation
	SELECT language_id
    INTO v_language_id
    FROM language
    WHERE LOWER(name) = LOWER(p_language_name);

    IF v_language_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist', p_language_name;
    END IF;
    
-- insert movie
    INSERT INTO film (
        title,
        release_year,
        language_id,
        rental_duration,
        rental_rate,
        replacement_cost,
        last_update
    )
    VALUES (
        p_title,
        p_release_year,
        v_language_id,
        3,
        4.99,
        19.99,
        CURRENT_TIMESTAMP
    );

END;
$$;

-- test queries, valid

SELECT core.new_movie('My New Film');

-- expected result: movie inserted successfully with defaults applied, release_year = current year,
-- language = Klingon, rental_rate = 4.99

-- Edge case 1
SELECT core.new_movie('My New Film');

-- result : movie 'my new film' already exists
-- also prevents 'My New Film', 'my new film', 'MY NEW FILM', because of LOWER(title).

-- edge case 2
SELECT core.new_movie('Another Film', 2024, 'Elvish');

-- result: error- language 'Elvish' does not exist

-- edge case 3
SELECT core.new_movie(NULL);
-- result error - movie title cannot be null or empty.




