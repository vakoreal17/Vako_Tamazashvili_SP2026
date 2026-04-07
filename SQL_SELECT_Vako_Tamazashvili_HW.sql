/* Task 1.1
Conditions: Must be 'Animation', release year between 2017 and 2019, rating > 1, sorted by title.
*/

/* Assumptions and business logic:
Assumptions: Animation movies can be identified in category.name column. We need to link films and categories, so we use film_category
as a bridge between them. 'rate more than 1' means rental rate > 1, release year can be identified in film table
Business logic: filter films by category, release year and rental rate,
then return sorted list.
	
 */

-- Solution 1 - CTE
with animation_films as (
select  
	f.title, 
	f.release_year, 
	f.rental_rate
from public.film f
inner join public.film_category fc on f.film_id = fc.film_id
inner join public.category c on fc.category_id = c.category_id
where 
	c.name = 'Animation' 
	and f.release_year between 2017 AND 2019 
	and f.rental_rate > 1
)
select *
from  animation_films
order by  title asc ;

/* Used inner join here because we only wanted films categorised as 'Animation' so we didnt need anything else, hence 
 inner join is used. if we used Left join films without category would still appear and their category would be null, but
 since we have filter where c.name = 'Animation' left join would behave like inner join.
 */

-- Solution 2 - subquery

select   
	sub.title,
	sub.release_year,
	sub.rental_rate
from  (select   
	f.title, 
	f.release_year, 
	f.rental_rate
from  public.film f
inner join public.film_category fc on f.film_id = fc.film_id
inner join public.category c on fc.category_id = c.category_id
where 
	c.name = 'Animation' 
	and f.release_year between 2017 and 2019 
	and f.rental_rate > 1) as sub
order by sub.title asc;

-- Solution 3 - Join
select  
	f.title, 
	f.release_year, 
	f.rental_rate
from public.film f
inner join public.film_category fc on f.film_id = fc.film_id
inner join public.category c on fc.category_id = c.category_id
where 
	c.name = 'Animation' 
	and f.release_year between 2017 and 2019 
	and f.rental_rate > 1
order by f.title asc;


select *
from category


/*Choice: I think using Join solution is the best here because its clean, simple and very readable. it is easier for SQL as well
because it uses the least amount of resources from these 3 solutions. 
*/

/* Task 1.2   Calculate the revenue earned by each rental store after March 2017 (from April onward)
 Conditions: Use transactions after march 2017	
 			Revenue = sum(payment.amount)
 			Need to include store address as one column (address + address 2)
 			output columns : full_address, revenue
*/

/* Assumptions and business logic:
 	Assumptions: We need to pay attention to 'after march 2017' -> from '2017-04-01'
 need to connect payment to a rental, then to inventory and to a store
 Address is formed like: address || ' ' || address2, we should use coalesce function as well to avoid null results
 	Business logic: Join payment -> rental > inventory > store > address
 	filter payments after March 2017
 	Aggregate revenue per store, group by address
 */

-- Solution 1: CTE
with store_revenue as (
    select 
        s.store_id,
        a.address,
        a.address2,
        SUM(p.amount) as revenue
    from public.payment p
    inner join public.rental r 
        on p.rental_id = r.rental_id
    inner join public.inventory i 
        on r.inventory_id = i.inventory_id
    inner join public.store s 
        on i.store_id = s.store_id
    inner join  public.address a 
        on s.address_id = a.address_id
    where p.payment_date >= DATE '2017-04-01'
    group by s.store_id, a.address, a.address2
)
select 
    (address || ' ' || coalesce(address2, '')) as full_address,
    revenue
from store_revenue;

/* Used inner join here to exclude payments without rentals and rentals without inventory. only stores with actual transactions
 are included. if we used left join here its the same situation as in task 1, we would include stores with zero revenue
 if we didnt have filter on payment_date. it would behave same as inner join in this case but still using inner join is  
 better and more advised.
 */
 

-- Solution 2: Subquery

select 
    (sub.address || ' ' || coalesce(sub.address2, '')) as full_address,
    sub.revenue
from (
    select 
        s.store_id,
        a.address,
        a.address2,
        SUM(p.amount) AS revenue
    from public.payment p
    inner join public.rental r  on p.rental_id = r.rental_id
    inner join public.inventory i  on  r.inventory_id = i.inventory_id
    inner join public.store s  on  i.store_id = s.store_id
    inner join public.address a on s.address_id = a.address_id
    where p.payment_date >= DATE '2017-04-01'
    group by s.store_id, a.address, a.address2
) sub;


-- Solution 3: Join

select 
    (a.address || ' ' || COALESCE(a.address2, '')) as full_address,
    SUM(p.amount) AS revenue
from public.payment p
inner join public.rental r on p.rental_id = r.rental_id
inner join public.inventory i on r.inventory_id = i.inventory_id
inner join public.store s on i.store_id = s.store_id
inner join public.address a on s.address_id = a.address_id
where p.payment_date >= DATE '2017-04-01'
group by s.store_id, a.address, a.address2;

/* Choice: I would go with Join here as well for the same reasons. it is simple and efficient and doesnt require 
intermediate steps.
*/

/* Task 1.3   The most successful actors since 2015
Conditions: count number of films per actor
			include first_name, last_name, number_of_movies. and sort by number_of_movies desc
			limit to top 5
*/


/* Assumptions and business logic:
Assumptions : we need to filter movies actors took part in based on film_actor table
			  release_year is from film table
			  We need to consider only films released after 2015
Business logic: join actor > film_actor > film
				filter films after 2015
				count number of films per actor
				sort it by desc and limit to top 5
*/


-- Solution 1: CTE

with actor_movies as (
    select 
        a.actor_id,
        a.first_name,
        a.last_name,
        count(f.film_id) as number_of_movies
    from public.actor a
    inner join public.film_actor fa on a.actor_id = fa.actor_id
    inner join public.film f on fa.film_id = f.film_id
    where f.release_year >= 2015
    group by a.actor_id, a.first_name, a.last_name
)
select 
    first_name,
    last_name,
    number_of_movies
from actor_movies
order by number_of_movies desc
limit 5;


/* Same situation here with inner and left joins. left join would behave same as inner join because of the filter on
 f.release_year. still better to use inner join here anyway.
 */

-- Solution 2: Subquery

select 
    sub.first_name,
    sub.last_name,
    sub.number_of_movies
from (
    select 
        a.actor_id,
        a.first_name,
        a.last_name,
        count(f.film_id) as number_of_movies
    from public.actor a
    inner join public.film_actor fa on a.actor_id = fa.actor_id
    inner join public.film f on fa.film_id = f.film_id
    where f.release_year >= 2015
    group by a.actor_id, a.first_name, a.last_name
) sub
order by sub.number_of_movies desc
limit 5;

-- Solution 3: Join

select 
    a.first_name,
    a.last_name,
    count(f.film_id) as number_of_movies
from public.actor a
inner join public.film_actor fa 
    on a.actor_id = fa.actor_id
inner join public.film f 
    on fa.film_id = f.film_id
where f.release_year >= 2015
group by a.actor_id, a.first_name, a.last_name
order by number_of_movies desc
limit 5;
			

-- Choice: I would go with Join here again for the same reasons.


/* Task 1.4    Trends of different genres to ifnorm genre-specific marketing strategies.
Conditions: have to include: release_year, number_of_drama_movies, number_of_travel_movies,
			number_of_documentary_movies. take care of null values and sort by release_year desc.
 */

/* Assumptions and business logic
Assumptions : one film belongs to one category
			  release_year is stored in film table
			  film categories are defined in category table
			  film_category connects films to categories
Business logic : join film > film_category > category
				 group by release_year
				 count films conditionally per category
				 use contidional aggregation to separate categories into columns
 */

-- Solution 1: CTE

with categorized_films as (
    select 
        f.release_year,
        c.name as category_name
    from public.film f
    inner join public.film_category fc on f.film_id = fc.film_id
    inner join public.category c on fc.category_id = c.category_id
    where lower(c.name) in ('drama', 'travel', 'documentary')
)
select 
    release_year,
    sum(case when lower(category_name) = 'drama' then 1 else 0 end) as number_of_drama_movies,
    sum(case when lower(category_name) = 'travel' then 1 else 0 end) as number_of_travel_movies,
    sum(case when lower(category_name) = 'documentary' then 1 else 0 end) as number_of_documentary_movies
from categorized_films
group by release_year
order by release_year desc;

/* Same intention with joins here. since we have filter on c.name left join would behave same as inner join here.
 
 */

-- Solution 2: Subquery

select 
    sub.release_year,
    sum(case when lower(sub.category_name) = 'drama' then 1 else 0 end) as number_of_drama_movies,
    sum(case when lower(sub.category_name) = 'travel' then 1 else 0 end) as number_of_travel_movies,
    sum(case when lower(sub.category_name) = 'documentary' then 1 else 0 end) as number_of_documentary_movies
from (
    select 
        f.release_year,
        c.name as category_name
    from public.film f
    inner join public.film_category fc on f.film_id = fc.film_id
    inner join public.category c on fc.category_id = c.category_id
    where lower(c.name) in ('drama', 'travel', 'documentary')
) sub
group by sub.release_year
order by sub.release_year desc;

-- Solution 3 : Join

select 
    f.release_year,
    sum(case when lower(c.name) = 'drama' then 1 else 0 end) as number_of_drama_movies,
    sum(case when lower(c.name) = 'travel' then 1 else 0 end) as number_of_travel_movies,
    sum(case when lower(c.name) = 'documentary' then 1 else 0 end) as number_of_documentary_movies
from public.film f
inner join public.film_category fc on f.film_id = fc.film_id
inner join public.category c on fc.category_id = c.category_id
where lower(c.name) in ('drama', 'travel', 'documentary')
group by f.release_year
order by f.release_year desc;

-- Choice: i would use Join solution in this case as well for the same reasons.


/* Task 2.1   Top performing employees in 2017
 Conditions: revenue = sum(payment.amount)
 			 need to consider payments only in 2017
 			 include the store where the staff last worked, if staff processed payment > they worked in that store
 			 output: first_name, last_name, store_id, revenue. 
 			 sort by revenue desc and limit to 3.
 Assumptions and business logic
 Assumptions: store_id is determined through inventory > rental > payment chain
 			  'last store' the store where the staff had their lastest payment_date in 2017
 			  as staff may appear in many stores we must pick the latest one.
 Business logic : filter payments in 2017
 				  calculate toral revenue per staff
 				  identify last store
 				  sort and limit to top 3
*/

-- Solution 1: CTE


with staff_revenue as (
    select 
        p.staff_id,
        sum(p.amount) as total_revenue
    from public.payment p
    where p.payment_date >= date '2017-01-01'
      and p.payment_date < date '2018-01-01'
    group by p.staff_id
),
last_payment as (
    select 
        p.staff_id,
        max(p.payment_date) as last_payment_date
    from public.payment p
    where p.payment_date >= date '2017-01-01'
      and p.payment_date < date '2018-01-01'
    group by p.staff_id
),
last_payment_row as (
    select 
        p.staff_id,
        max(p.rental_id) as rental_id
    from public.payment p
    inner join last_payment lp on p.staff_id = lp.staff_id
       and p.payment_date = lp.last_payment_date
    group by p.staff_id
)
select 
    s.first_name,
    s.last_name,
    i.store_id,
    sr.total_revenue
from staff_revenue sr
inner join public.staff s on sr.staff_id = s.staff_id
inner join last_payment_row lpr on sr.staff_id = lpr.staff_id
inner join public.rental r on lpr.rental_id = r.rental_id
inner join public.inventory i on r.inventory_id = i.inventory_id
order by sr.total_revenue desc
limit 3;

/* initial approach using max(payment_date) caused duplicate rows because multiple payments 
can exist on the same date. To resolve this an additional tie-breaker max(rental_id) was used to ensure only one record per 
staff is selected. This guarantees correct identification of the last store
*/

-- Solution 2 : Subquery

select 
    s.first_name,
    s.last_name,
    i.store_id,
    sr.total_revenue
from (
    select 
        p.staff_id,
        sum(p.amount) as total_revenue
    from public.payment p
    where p.payment_date >= date '2017-01-01' and p.payment_date < date '2018-01-01'
    group by p.staff_id
) sr
inner join public.staff s on sr.staff_id = s.staff_id
inner join public.rental r on r.rental_id = (select max(p2.rental_id)
        from public.payment p2
        where p2.staff_id = sr.staff_id and p2.payment_date = (select max(p3.payment_date)
              from public.payment p3
              where p3.staff_id = sr.staff_id
                and p3.payment_date >= date '2017-01-01'
                and p3.payment_date < date '2018-01-01'
          )
    )
inner join public.inventory i on r.inventory_id = i.inventory_id
order by sr.total_revenue desc
limit 3;


/* Solution 3: Join is not applicable because we need to calculate aggregate and also select a specific row
As SQL does not allow selecing max row and aggregated values simultaneously without subquery or CTE we cannot use just join.


In both examples we used inner join because we only want valid payment records. We are not interested in staff with zero 
revenue, but since we have filter on payment_date left join would return the same result anyway

Choice: i would use the CTE solution because the logic is clearer and i think its easier to read this type of query.
we would also avoid repeated subqueries.
  */


/* Task 2.2    Most popular movies and their target audience
Conditions: count number of rentals per movie
			sort by number_of_rentals desc
			limit to 5
			use mpaa system to map film.rating to expected audience age
			output title, number_of_rentals, expected age
Assumptions and business logic
Assumptions: popularity = number of rentals
			 rentals can be counted in rental table
			 film rating follows mpaa system
Business logic: join film > inventory > rental
				count rentals per film
				sort and select 5
				map rating using case expression
 */

-- Solution 1: CTE

with film_rentals as (
    select 
        f.film_id,
        f.title,
        f.rating,
        count(r.rental_id) as number_of_rentals
    from public.film f
    inner join public.inventory i on f.film_id = i.film_id
    inner join public.rental r on i.inventory_id = r.inventory_id
    group by f.film_id, f.title, f.rating
)
select 
    title,
    number_of_rentals,
    case 
        when rating = 'G' then 'all ages'
        when rating = 'PG' then 'parental guidance (approx 10+)'
        when rating = 'PG-13' then '13+'
        when rating = 'R' then '17+'
        when rating = 'NC-17' then '18+'
        else 'unknown'end as expected_age
from film_rentals
order by number_of_rentals desc
limit 5;  

-- Solution 2: Subquery

select 
    sub.title,
    sub.number_of_rentals,
    case 
        when sub.rating = 'G' then 'all ages'
        when sub.rating = 'PG' then 'parental guidance (approx 10+)'
        when sub.rating = 'PG-13' then '13+'
        when sub.rating = 'R' then '17+'
        when sub.rating = 'NC-17' then '18+'
        else 'unknown' end as expected_age
from (
    select 
        f.film_id,
        f.title,
        f.rating,
        count(r.rental_id) as number_of_rentals
    from public.film f
    inner join public.inventory i on f.film_id = i.film_id
    inner join public.rental r on i.inventory_id = r.inventory_id
    group by f.film_id, f.title, f.rating
) sub
order by sub.number_of_rentals desc
limit 5;

-- Solution 3: Join

select 
    f.title,
    count(r.rental_id) as number_of_rentals,
    case 
        when f.rating = 'G' then 'all ages'
        when f.rating = 'PG' then 'parental guidance (approx 10+)'
        when f.rating = 'PG-13' then '13+'
        when f.rating = 'R' then '17+'
        when f.rating = 'NC-17' then '18+'
        else 'unknown' end as expected_age
from public.film f
inner join public.inventory i on f.film_id = i.film_id
inner join public.rental r on i.inventory_id = r.inventory_id
group by f.film_id, f.title, f.rating
order by number_of_rentals desc
limit 5;

/* Used inner join here because only films that were actually rented are relevant to the task. ensures valid relationship
between film, inventory and rental. if we used left join zero rental films would also appear, however we wouldnt see it
in top 5. 

Choice: i would use solution 3: Join here because of the simplicity and efficiency. We dont need intermediate steps here.
*/

/* Task 3.1   Actors inactivity period
Conditions: calculate max(release_year) per actor
			calculate inactivity = current_year - latest_release_year  
			sort by inactivity desc
Assumptions and business logic
Assumptions : current year derived using extract(year from current_date)
			  latest inactivity = max(film.release_year) 
			  actors without films are excluded  
Business logic : join actor > film_actor > film 
			  get max release_year per actor
			  subtract from current year
  			  sort by inactivity desc 
*/

-- Solution 1 : CTE

with actor_last_film as (
    select 
        a.actor_id,
        a.first_name,
        a.last_name,
        max(f.release_year) as last_release_year
    from public.actor a
    inner join public.film_actor fa on a.actor_id = fa.actor_id
    inner join public.film f on fa.film_id = f.film_id
    group by a.actor_id, a.first_name, a.last_name
)
select 
    first_name,
    last_name,
    last_release_year,
    extract(year from current_date) - last_release_year as inactivity_years
from actor_last_film
order by inactivity_years desc;

-- Solution 2: Subquery

select 
    sub.first_name,
    sub.last_name,
    sub.last_release_year,
    extract(year from current_date) - sub.last_release_year as inactivity_years
from (
    select 
        a.actor_id,
        a.first_name,
        a.last_name,
        max(f.release_year) as last_release_year
    from public.actor a
    inner join public.film_actor fa  on a.actor_id = fa.actor_id
    inner join public.film f  on fa.film_id = f.film_id
    group by a.actor_id, a.first_name, a.last_name
) sub
order by inactivity_years desc;

-- Solution 3: Join

select 
    a.first_name,
    a.last_name,
    max(f.release_year) as last_release_year,
    extract(year from current_date) - max(f.release_year) as inactivity_years
from public.actor a
inner join public.film_actor fa  on a.actor_id = fa.actor_id
inner join public.film f  on fa.film_id = f.film_id
group by a.actor_id, a.first_name, a.last_name
order by inactivity_years desc;

/* Inner join ensures only actors with films are included. aggregation(max release_year) finds the last activity 
left join could include actors with no films, but inactivity cannot be calculated for them, so inner join is used here. 

Choice: I would use solution 3: Join because it is the most simple approach and guarantees best performance as well. 
*/

/* Task 4.2    
Conditions :  calculate difference between film release years 
			  identify largest gap per actor  
			  consider only forward comparisons (later film > earlier film) 
			  sort results by maximum gap desc 
Assumptions and business logic
Assumptions : each actor can participate in multiple films across different years 
			  release_year represents the time of participation in a film 
Business logic: generate all possible pairs of films for each actor
				filter pairs where the second film has a later release year 
				calculate the gap between the two release years 
				aggregate to find the maximum gap per actor
*/ 

-- Solution 1 : CTE

with actor_films as (
    select distinct
        a.actor_id,
        a.first_name,
        a.last_name,
        f.release_year
    from public.actor a
    inner join public.film_actor fa on a.actor_id = fa.actor_id
    inner join public.film f on fa.film_id = f.film_id
),
next_years as (
    select 
        af1.actor_id,
        af1.first_name,
        af1.last_name,
        af1.release_year as current_year,
        min(af2.release_year) as next_year
    from actor_films af1
    inner join actor_films af2 
        on af1.actor_id = af2.actor_id
       and af2.release_year > af1.release_year
    group by 
        af1.actor_id,
        af1.first_name,
        af1.last_name,
        af1.release_year
)
select 
    actor_id,
    first_name,
    last_name,
    max(next_year - current_year) as max_gap
from next_years
group by actor_id, first_name, last_name
order by max_gap desc;

-- Solution 2: Subquery

select 
    t.actor_id,
    t.first_name,
    t.last_name,
    max(t.next_year - t.current_year) as max_gap
from (
    select distinct
        af1.actor_id,
        af1.first_name,
        af1.last_name,
        af1.release_year as current_year,
        min(af2.release_year) as next_year
    from (
        select distinct
            a.actor_id,
            a.first_name,
            a.last_name,
            f.release_year
        from public.actor a
        inner join public.film_actor fa on a.actor_id = fa.actor_id
        inner join public.film f on fa.film_id = f.film_id
    ) af1
    inner join (
        select distinct
            a.actor_id,
            f.release_year
        from public.actor a
        inner join public.film_actor fa on a.actor_id = fa.actor_id
        inner join public.film f on fa.film_id = f.film_id
    ) af2
        on af1.actor_id = af2.actor_id
       and af2.release_year > af1.release_year
    group by 
        af1.actor_id,
        af1.first_name,
        af1.last_name,
        af1.release_year
) t
group by t.actor_id, t.first_name, t.last_name
order by max_gap desc;

-- Distinct is used to avoid duplicate release years per actor, ensuring accurate calculation of consecutive year gaps.

-- Solution 3: Join > We need intermediate calculation of gaps and its required to compare multiple rows per actor
-- therefore, cte or subquery is required

/* Inner join is used here to ensure valid actor-film relationships, self join compares films of the same actor. 
Condition (f2.releasy_year > f1.release_year) avoids duplicate and negative gaps. 

Choice: for this task CTE should be prefferable because it makes the query more readable. 