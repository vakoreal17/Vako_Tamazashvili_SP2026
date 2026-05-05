-- Task 1

CREATE ROLE rentaluser WITH LOGIN PASSWORD 'rentalpassword';

GRANT CONNECT ON DATABASE dvdrental TO rentaluser;

SET ROLE rentaluser;

SELECT * FROM customer;

-- This provides an error as rentaluser doesnt have access to select yet.

GRANT SELECT ON TABLE customer TO rentaluser;

SET ROLE rentaluser;

SELECT * FROM customer;

-- Now it works properly.

CREATE ROLE rental;
GRANT rental TO rentaluser;
GRANT SELECT, INSERT, UPDATE ON TABLE rental TO rental;

SET ROLE rentaluser;

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (NOW(), 1, 1, NOW(), 1);

-- this works

UPDATE rental
SET return_date = NOW()
WHERE rental_id = 1;

-- update works as well

REVOKE INSERT ON TABLE rental FROM rental;

SET ROLE rentaluser;

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (NOW(), 1, 1, NOW(), 1);

-- now we get an error as we revoked insert permissions.

SELECT c.first_name, c.last_name, c.customer_id
FROM customer c
JOIN rental r ON c.customer_id = r.customer_id
JOIN payment p ON c.customer_id = p.customer_id
LIMIT 1;

-- Task 2. RLS.

select customer_id, first_name, last_name
from customer
limit 1;

create role client_mary_smith LOGIN password 'password';

grant connect on database dvd_rental to client_mary_smith;
grant usage on schema public to client_mary_smith;

grant select on rental, payment to client_mary_smith;

-- now lets enable rls

alter table rental enable row level security;
alter table payment enable row level security;

-- creating rls policies.

create policy rental_policy
on rental
for select
to client_mary_smith
using (customer_id = 1);

create policy payment_policy
on payment
for select
to client_mary_smith
using (customer_id = 1);

-- Allowed access

set role client_mary_smith;

select * 
from rental; 

-- only rows where customer id = 1 are displayed

select *
from payment;

-- only that customer's payments are displayed

-- now lets try to force access to another customer

select * 
from rental
where customer_id = 2;

-- 0 rows returned, proving rls is working.

/* Row-level security ensures that users can only access rows that meet defined conditions.
in this case, the policy resticts acces so that user can view only mary smith records. 