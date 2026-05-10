-- Final task. 3.

-- 0. reset schema (rerunnable safely) 
create schema if not exists museum_core;
set search_path to museum_core;

-- 1. parent tables

create table if not exists museum (
    museum_id serial primary key,
    name varchar(100) not null,
    location varchar(150) not null,
    
    constraint uq_museum_name_location unique (name, location)
);

create table if not exists artist (
    artist_id serial primary key,
    full_name varchar(100) not null,
    birth_date date,
    country varchar(50),
    
    constraint uq_artist_identity unique (full_name, birth_date)
);

create table if not exists visitor (
    visitor_id serial primary key,
    full_name varchar(100) not null,
    email varchar(100),

    constraint uq_visitor_email unique (email)
);


--2. Child tables.

create table if not exists exhibition (
    exhibition_id serial primary key,
    museum_id int not null,
    name varchar(100) not null,
    start_date date not null,
    end_date date,

    constraint fk_exhibition_museum
        foreign key (museum_id)
        references museum(museum_id)
);

create table if not exists artwork (
    artwork_id serial primary key,
    artist_id int not null,
    title varchar(150) not null,
    creation_year int,
    type varchar(50),

    constraint fk_artwork_artist
        foreign key (artist_id)
        references artist(artist_id)
);

create table if not exists staff (
    staff_id serial primary key,
    museum_id int not null,
    full_name varchar(100) not null,
    role varchar(50) not null,

    constraint fk_staff_museum
        foreign key (museum_id)
        references museum(museum_id)
);

-- 3. ticket (generated column)

create table if not exists ticket (
    ticket_id serial primary key,
    visitor_id int not null,
    exhibition_id int not null,
    purchase_date date not null default current_date,
    base_price numeric(8,2) not null,

    final_price numeric(8,2)
        generated always as (base_price * 1.10) stored,

    constraint fk_ticket_visitor
        foreign key (visitor_id)
        references visitor(visitor_id),

    constraint fk_ticket_exhibition
        foreign key (exhibition_id)
        references exhibition(exhibition_id)
);

-- 4. many-to-many bridge

create table if not exists artwork_exhibition (
    artwork_id int,
    exhibition_id int,

    primary key (artwork_id, exhibition_id),

    constraint fk_ae_artwork
        foreign key (artwork_id)
        references artwork(artwork_id),

    constraint fk_ae_exhibition
        foreign key (exhibition_id)
        references exhibition(exhibition_id)
);

-- 5. constraints

do $$
begin
    if not exists (
        select 1 from pg_constraint 
        where conname = 'chk_artwork_year_valid'
    ) then
        alter table artwork
        add constraint chk_artwork_year_valid
        check (
            creation_year is null or
            creation_year <= extract(year from current_date)
        );
    end if;
end $$;

-- staff role restriction
do $$
begin
    if not exists (
        select 1 from pg_constraint 
        where conname = 'chk_staff_role_valid'
    ) then
        alter table staff
        add constraint chk_staff_role_valid
        check (role in ('guide', 'manager', 'curator', 'security'));
    end if;
end $$;

-- visitor email format
do $$
begin
    if not exists (
        select 1 from pg_constraint 
        where conname = 'chk_visitor_email_format'
    ) then
        alter table visitor
        add constraint chk_visitor_email_format
        check (email is null or email like '%@%.%');
    end if;
end $$;

--4. DML script(populating data)

set search_path to museum_core;

insert into museum (name, location)
values
('national art museum', 'tbilisi'),
('modern art gallery', 'batumi'),
('history museum', 'kutaisi'),
('science museum', 'rustavi'),
('cultural heritage museum', 'telavi'),
('fine arts center', 'gori');

insert into artist (full_name, birth_date, country)
values
('pablo picasso', '1881-10-25', 'spain'),
('vincent van gogh', '1853-03-30', 'netherlands'),
('leonardo da vinci', '1452-04-15', 'italy'),
('claude monet', '1840-11-14', 'france'),
('salvador dali', '1904-05-11', 'spain'),
('andy warhol', '1928-08-06', 'usa');

insert into visitor (full_name, email)
values
('giorgi beridze', 'giorgi@gmail.com'),
('nino lashkhi', 'nino@gmail.com'),
('dato gelashvili', 'dato@gmail.com'),
('ana khurtsidze', 'ana@gmail.com'),
('luka tsiklauri', 'luka@gmail.com'),
('mariam chubinidze', 'mariam@gmail.com');

insert into exhibition (museum_id, name, start_date, end_date)
values
((select museum_id from museum where name='national art museum'), 'renaissance expo', current_date - interval '60 days', current_date - interval '30 days'),
((select museum_id from museum where name='modern art gallery'), 'modern vibes', current_date - interval '50 days', current_date - interval '10 days'),
((select museum_id from museum where name='history museum'), 'ancient history', current_date - interval '70 days', current_date - interval '20 days'),
((select museum_id from museum where name='science museum'), 'future tech', current_date - interval '40 days', null),
((select museum_id from museum where name='cultural heritage museum'), 'georgian culture', current_date - interval '30 days', null),
((select museum_id from museum where name='fine arts center'), 'abstract world', current_date - interval '20 days', null);

insert into artwork (artist_id, title, creation_year, type)
values
((select artist_id from artist where full_name='pablo picasso'), 'guernica', 1937, 'painting'),
((select artist_id from artist where full_name='vincent van gogh'), 'starry night', 1889, 'painting'),
((select artist_id from artist where full_name='leonardo da vinci'), 'mona lisa', 1503, 'painting'),
((select artist_id from artist where full_name='claude monet'), 'water lilies', 1906, 'painting'),
((select artist_id from artist where full_name='salvador dali'), 'persistence of memory', 1931, 'painting'),
((select artist_id from artist where full_name='andy warhol'), 'marilyn diptych', 1962, 'painting');

insert into staff (museum_id, full_name, role)
values
((select museum_id from museum where name='national art museum'), 'irakli meskhi', 'manager'),
((select museum_id from museum where name='modern art gallery'), 'tamar gelashvili', 'guide'),
((select museum_id from museum where name='history museum'), 'giorgi khutsishvili', 'curator'),
((select museum_id from museum where name='science museum'), 'ana jikidze', 'security'),
((select museum_id from museum where name='cultural heritage museum'), 'nino tsulaia', 'guide'),
((select museum_id from museum where name='fine arts center'), 'lasha beridze', 'manager');

insert into artwork_exhibition (artwork_id, exhibition_id)
values
(
 (select artwork_id from artwork where title='guernica'),
 (select exhibition_id from exhibition where name='modern vibes')
),
(
 (select artwork_id from artwork where title='starry night'),
 (select exhibition_id from exhibition where name='abstract world')
),
(
 (select artwork_id from artwork where title='mona lisa'),
 (select exhibition_id from exhibition where name='renaissance expo')
),
(
 (select artwork_id from artwork where title='water lilies'),
 (select exhibition_id from exhibition where name='abstract world')
),
(
 (select artwork_id from artwork where title='persistence of memory'),
 (select exhibition_id from exhibition where name='modern vibes')
),
(
 (select artwork_id from artwork where title='marilyn diptych'),
 (select exhibition_id from exhibition where name='future tech')
);

insert into ticket (visitor_id, exhibition_id, purchase_date, base_price)
values
(
 (select visitor_id from visitor where email='giorgi@gmail.com'),
 (select exhibition_id from exhibition where name='modern vibes'),
 current_date - interval '10 days',
 25.00
),
(
 (select visitor_id from visitor where email='nino@gmail.com'),
 (select exhibition_id from exhibition where name='renaissance expo'),
 current_date - interval '20 days',
 20.00
),
(
 (select visitor_id from visitor where email='dato@gmail.com'),
 (select exhibition_id from exhibition where name='future tech'),
 current_date - interval '5 days',
 30.00
),
(
 (select visitor_id from visitor where email='ana@gmail.com'),
 (select exhibition_id from exhibition where name='abstract world'),
 current_date - interval '15 days',
 22.00
),
(
 (select visitor_id from visitor where email='luka@gmail.com'),
 (select exhibition_id from exhibition where name='georgian culture'),
 current_date - interval '25 days',
 18.00
),
(
 (select visitor_id from visitor where email='mariam@gmail.com'),
 (select exhibition_id from exhibition where name='ancient history'),
 current_date - interval '12 days',
 19.00
);



-- 5 Functions

create or replace function update_museum_column(
    p_museum_id int,
    p_column_name text,
    p_new_value text
)
returns void
language plpgsql
as $$
declare
    v_sql text;
begin
    -- validate column name to prevent sql injection
    if p_column_name not in ('name', 'location') then
        raise exception 'invalid column name: %', p_column_name;
    end if;

    -- build safe dynamic query
    v_sql := format(
        'update museum set %I = $1 where museum_id = $2',
        p_column_name
    );

    -- execute query with parameters
    execute v_sql
    using p_new_value, p_museum_id;

    -- optional: check if row was updated
    if not found then
        raise exception 'no museum found with id %', p_museum_id;
    end if;
end;
$$;

-- 5.2 

create or replace function add_ticket_transaction(
    p_visitor_email text,
    p_exhibition_name text,
    p_base_price numeric,
    p_purchase_date date default current_date
)
returns void
language plpgsql
as $$
declare
    v_visitor_id int;
    v_exhibition_id int;
begin
    -- get visitor_id from natural key (email)
    select visitor_id
    into v_visitor_id
    from visitor
    where email = p_visitor_email;

    if v_visitor_id is null then
        raise exception 'visitor with email % not found', p_visitor_email;
    end if;

    -- get exhibition_id from natural key (name)
    select exhibition_id
    into v_exhibition_id
    from exhibition
    where name = p_exhibition_name;

    if v_exhibition_id is null then
        raise exception 'exhibition % not found', p_exhibition_name;
    end if;

    -- insert transaction
    insert into ticket (
        visitor_id,
        exhibition_id,
        purchase_date,
        base_price
    )
    values (
        v_visitor_id,
        v_exhibition_id,
        p_purchase_date,
        p_base_price
    );

    -- confirm success
    raise notice 'ticket successfully created for % (exhibition: %)',
        p_visitor_email, p_exhibition_name;

end;
$$;

-- 6. view

create or replace view vw_recent_quarter_analytics as
with recent_quarter as (
    select
        date_trunc('quarter', max(purchase_date)) as quarter_start
    from ticket
)
select
    e.name as exhibition_name,
    m.name as museum_name,

    count(t.ticket_id) as total_tickets_sold,
    sum(t.base_price) as total_revenue,
    avg(t.base_price) as avg_ticket_price

from ticket t
join exhibition e on t.exhibition_id = e.exhibition_id
join museum m on e.museum_id = m.museum_id
join recent_quarter rq
    on date_trunc('quarter', t.purchase_date) = rq.quarter_start

group by
    e.name,
    m.name;

/* this dynamically finds latest quarter, filters only that quarter. we also avoid duplicates 
and excludes surrogate keys. */

-- 7. role

create role manager_readonly
login
password 'flugen_gegen_holen'
nosuperuser
nocreatedb
nocreaterole
noinherit;
-- access to schema
grant usage on schema museum_core to manager_readonly;
-- read-only access to all tables
grant select on all tables in schema museum_core to manager_readonly;
-- future tables are also accessible
alter default privileges in schema museum_core
grant select on tables to manager_readonly;