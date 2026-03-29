-- Task 1   Three favourite films.

BEGIN;

INSERT INTO public.film (
    title, description, release_year, language_id,
    rental_rate, rental_duration, length, rating, last_update
)
SELECT
    v.title,
    v.description,
    v.release_year,
    l.language_id,
    v.rental_rate,
    v.rental_duration,
    v.length,
    v.rating,
    v.last_update
FROM (
    VALUES
    ('Inception', 'A mind-bending thriller', 2010, 4.99, 7, 148, 'PG-13'::mpaa_rating, current_date),
    ('The Dark Knight', 'Batman vs Joker', 2008, 9.99, 14, 152, 'PG-13'::mpaa_rating, current_date),
    ('Interstellar', 'Space exploration and time', 2014, 19.99, 21, 169, 'PG-13'::mpaa_rating, current_date)
) AS v(title, description, release_year, rental_rate, rental_duration, length, rating, last_update)
JOIN public.language l ON l.name = 'English'
WHERE NOT EXISTS (
    SELECT 1 FROM public.film f WHERE f.title = v.title
)
RETURNING film_id, title;

COMMIT;


BEGIN;


INSERT INTO public.actor (first_name, last_name, last_update)
SELECT *
FROM (
    VALUES
    ('LEONARDO', 'DICAPRIO', current_date),
    ('CHRISTIAN', 'BALE', current_date),
    ('MATTHEW', 'MCCONAUGHEY', current_date),
    ('ANNE', 'HATHAWAY', current_date),
    ('HEATH', 'LEDGER', current_date),
    ('JOSEPH', 'GORDON-LEVITT', current_date)
) AS v(first_name, last_name, last_update)
WHERE NOT EXISTS (
    SELECT 1 FROM public.actor a
    WHERE a.first_name = v.first_name
      AND a.last_name = v.last_name
)
RETURNING actor_id;

COMMIT;

-- we ensure uniqueness using actor full name also set last_update to current_date as per assignment

BEGIN;

INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, current_date
FROM public.actor a
JOIN public.film f
    ON f.title IN ('Inception', 'The Dark Knight', 'Interstellar')
WHERE a.last_name IN ('DICAPRIO','BALE','MCCONAUGHEY','HATHAWAY','LEDGER','GORDON-LEVITT')
AND NOT EXISTS (
    SELECT 1 FROM public.film_actor fa
    WHERE fa.actor_id = a.actor_id AND fa.film_id = f.film_id
)
RETURNING *;

COMMIT;

-- Adding films to the inventory

BEGIN;

INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT f.film_id, s.store_id, current_date
FROM public.film f
CROSS JOIN public.store s
WHERE f.title IN ('Inception','The Dark Knight','Interstellar')
AND NOT EXISTS (
    SELECT 1 FROM public.inventory i
    WHERE i.film_id = f.film_id
)
RETURNING inventory_id;

COMMIT;


BEGIN;

/* Customer selected dynamically >=43 rentals and address reused so no modification to shared table.*/

UPDATE public.customer c
SET first_name = 'Vako',
    last_name = 'Tamazashvili',
    email = 'vako@example.com',
    address_id = (
        SELECT address_id FROM public.address LIMIT 1
    ),
    last_update = current_date
WHERE c.customer_id = (
    SELECT customer_id
    FROM public.rental
    GROUP BY customer_id
    HAVING COUNT(*) >= 43
    LIMIT 1
)
RETURNING *;

COMMIT;


/* to maintain safety only records linnked to specific customer are deleted. Select used before Delete to verify 
affected rows */

BEGIN;

SELECT *
FROM public.payment
WHERE customer_id = (
    SELECT customer_id
    FROM public.customer
    WHERE first_name = 'Vako' AND last_name = 'Tamazashvili'
);

SELECT *
FROM public.rental
WHERE customer_id = (
    SELECT customer_id
    FROM public.customer
    WHERE first_name = 'Vako' AND last_name = 'Tamazashvili'
);

DELETE FROM public.payment
WHERE customer_id = (
    SELECT customer_id
    FROM public.customer
    WHERE first_name = 'Vako' AND last_name = 'Tamazashvili'
)
RETURNING *;

DELETE FROM public.rental
WHERE customer_id = (
    SELECT customer_id
    FROM public.customer
    WHERE first_name = 'Vako' AND last_name = 'Tamazashvili'
)
RETURNING *;

COMMIT;

-- Rental creation

BEGIN;

INSERT INTO public.rental (
    rental_date, inventory_id, customer_id, staff_id, last_update
)
SELECT current_date, i.inventory_id, c.customer_id, 1, current_date
FROM public.inventory i
JOIN public.film f ON f.film_id = i.film_id
JOIN public.customer c ON c.first_name = 'Vako'
WHERE f.title IN ('Inception','The Dark Knight','Interstellar')
RETURNING rental_id;

-- Payment creation

INSERT INTO public.payment (
    customer_id, staff_id, rental_id, amount, payment_date
)
SELECT r.customer_id, r.staff_id, r.rental_id, 4.99, current_date
FROM public.rental r
JOIN public.customer c ON r.customer_id = c.customer_id
WHERE c.first_name = 'Vako'
RETURNING payment_id;

COMMIT;

/* Data uniqueness is ensured using Where not exists clauses, before inserting new records in to tables such as film and actor
 the script checks whether a record with the same natural identifier already exists, this prevents duplicate records. 
 Additionally no hardcoded IDs are used, which avoids conflicts with existing primary keys.
 
 Relationships between tables are established using foreign keys. for example the relationship between films and actors is
 created through the film_actor table, which links actor_id and film_id.
 

 Each subtask is executed in a separate transaction, if one transaction fails only that part is rolled back.
 Insert into and select ensures reusability and avoids hardcoded IDs. if a transaction fails before COMMIT all changes made
 within that transaction are rolled back automatically by the database, which prevents partial updates and keeps the 
 database consistent
 
 Rollback is possible for any uncommited transaction, and if we do it, only changes within the current transaction
 are undone. previously commited data remains unaffected.
 
 Referential integrity is preserved by interting parent recods (film, actor) before child records (film_actor, inventory, 
 rental, payment). Using valid foriegn keys retrieved via select statements. Deleting dependent records (payment, rental) in 
 correct order.
 */


-- Task 2  delete and truncate

-- i tracked total_bytes to measure disk space consumption as it represents the total size of the table.

-- after the first operations Table occupies 602415104 bytes.

-- after delete - Table size remains almost the same, even though 1/3 of rows are removed - 602611712 Bytes, it took 16 seconds

-- "public.table_to_delete": found 18 removable, 6666667 nonremovable row versions in 73536 pages, after vacuum full
-- table size siginificantly recreases because storage is phyisically reclaimed. -- > 401580032 Bytes

-- Truncate took 1.08 seconds, and the table size is reduced to 8192 Bytes, near zero.

/* Delete vs truncate. Delete is slow because it removes row one by one, Truncate does it all at once so its much faster.
 Delete does not free disk space immediately, truncate frees it instantly.
 Delete is fully transactional (row-level operation), Truncate is minimally logged and behaves like a DDL operation
 Delete can be rolled back, Truncate can be rolled back but not in all databases, it can be rolled back in postgresql.
 
 */

/* Explanations
 Delete does not physically remove rows from the disk but marks rows 'dead tuples' and they still occupy space until its
 cleaned by Vacuum
 Vacuum rewrites entire table into a new file and it removes dead tuples which results in freeing up the disk space.
 Truncate does not scan any rows whatsoever, it instantly removes all rows which results in much faster performance.
 To summarize it, delete is slower and requires vacuum, it is suitable for selective row removal. Truncate is very fast
 and frees up space immediately, suitable for removing all rows.
 Vacuum full is expensive operation but neccessary to recalim the disk space.
 */

