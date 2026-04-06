-- 1. Database and schema

drop database if exists auction_db;
create database auction_db;

-- if not exists is not supported for create database therefore i think this is the correct approach

-- there is another option to run that script in a separate window however i think we need to
-- keep it in 1 script. drop is usually dangerous because it deletes data so im not entirely sure.
create schema if not exists auction_schema;
set search_path to auction_schema;

-- 2. Creating parent tables first so we dont encounter error, as relation wouldnt exist, 
-- Fk cannot find referenced table.

create table if not exists countries (
    country_id SERIAL primary key,
    country_name VARCHAR(100) unique not null) ;

-- UNIQUE prevents duplicate countries
-- Without it → duplicate country entries → inconsistent data

create table if not exists categories (
    category_id SERIAL primary key,
    category_name VARCHAR(100) unique not null);


create table if not exists participants (
    participant_id SERIAL primary key,
    full_name TEXT not null,
    email VARCHAR(150) unique not null,
    phone VARCHAR(20) unique,
    registered_at TIMESTAMP not null default CURRENT_TIMESTAMP) ;

-- NOT NULL → prevents missing required identity
-- UNIQUE email → prevents duplicate users

-- data type risk: if email was TEXT without limit → possible garbage/invalid data

create table if not exists employees (
    employee_id SERIAL primary key,
    full_name TEXT not null,
    role VARCHAR(50) not null,
    hire_date DATE not null check (hire_date > '2000-01-01') );

-- CHECK date prevents unrealistic hire dates


-- 3. Child tables

create table if not exists auction_locations (
    location_id SERIAL primary key,
    country_id INT not null,
    address TEXT not null,
    
    foreign key (country_id) references countries(country_id));
    
-- Without fk: Locations could reference non-existing countries.
    
create table if not exists items (
    item_id SERIAL primary key,
    seller_id INT not null,
    category_id INT not null,
    title TEXT not null,
    description TEXT,
    created_at TIMESTAMP not null  default CURRENT_TIMESTAMP,
    
    foreign key (seller_id) references participants(participant_id),
    foreign key (category_id) references categories(category_id)
);

create table if not exists auction_events (
    event_id SERIAL primary key,
    location_id INT not  null,
    event_date TIMESTAMP not null check (event_date > '2000-01-01'),
    event_manager_id INT not null,
    
    foreign key (location_id) references auction_locations(location_id),
    foreign key (event_manager_id) references employees(employee_id)
);

create table if not exists lots (
    lot_id SERIAL primary key,
    event_id INT not null,
    lot_number INT not null,
    starting_price NUMERIC(10,2) not null check (starting_price >= 0),
    
    foreign key (event_id) references auction_events(event_id)
);

create table if not exists lot_items (
    lot_id INT not null,
    item_id INT not null,
    
    primary key (lot_id, item_id),
    
    foreign key (lot_id) references lots(lot_id),
    foreign key (item_id) references items(item_id)
);

create table if not exists bids (
    bid_id SERIAL primary key,
    lot_id INT not null,
    bidder_id INT not null,
    bid_amount NUMERIC(10,2) not null check (bid_amount > 0),
    bid_time TIMESTAMP not null default CURRENT_TIMESTAMP,
    
    foreign key (lot_id) references lots(lot_id),
    foreign key (bidder_id) references participants(participant_id)
);


create table if not exists auction_results (
    result_id SERIAL primary key,
    lot_id INT not null unique,
    final_price NUMERIC(10,2) not null check (final_price > 0),
    closed_at TIMESTAMP not null,
    
    foreign key (lot_id) references lots(lot_id)
);

create table if not exists payments (
    payment_id SERIAL primary key,
    result_id INT not null,
    payer_id INT not null,
    amount NUMERIC(10,2) not null check (amount >= 0),
    payment_date TIMESTAMP not null default CURRENT_TIMESTAMP,
    method VARCHAR(50) not null,
    
    foreign key (result_id) references auction_results(result_id),
    foreign key (payer_id) references participants(participant_id)
);


-- generated column

alter table bids
add column if not exists bid_with_fee numeric(10,2)
generated always as (bid_amount * 1.05) stored;

-- 4. inserting Data(no duplicates and no hardcoding). consistency ensured using Select statement

insert into countries (country_name) values
('Georgia'), ('USA')
on conflict do nothing;

insert into categories (category_name) values
('Art'), ('Electronics')
on conflict do nothing;

insert into participants (full_name, email) values
('Vako Tamazashvili','vakot@mail.com'),
('Ana Kakauridze','ana@mail.com'),
('Luka Maisuradze','luka@mail.com')
on conflict do nothing;

insert into employees (full_name, role, hire_date) values
('Manager One','Manager','2021-01-01'),
('Manager Two','Manager','2022-02-02')
on conflict do nothing;

insert into auction_locations (country_id, address)
select country_id, 'Tbilisi' from countries where country_name='Georgia'
on conflict do nothing;

insert into auction_locations (country_id, address)
select country_id, 'New York' from countries where country_name='USA'
on conflict do nothing;

insert into items (seller_id, category_id, title)
select p.participant_id, c.category_id, 'Painting'
from participants p, categories c
where p.email='vakot@mail.com' and c.category_name='Art'
limit 1;

insert into items (seller_id, category_id, title)
select p.participant_id, c.category_id, 'Laptop'
from participants p, categories c
where p.email='ana@mail.com' and c.category_name='Electronics'
limit 1;

insert into auction_events (location_id, event_date, event_manager_id)
select l.location_id, current_timestamp, e.employee_id
from auction_locations l, employees e
limit 2;

insert into lots (event_id, lot_number, starting_price)
select event_id, 1, 100 from auction_events limit 1;

insert into lots (event_id, lot_number, starting_price)
select event_id, 2, 200 from auction_events limit 1;

insert into lot_items
select l.lot_id, i.item_id
from lots l, items i
limit 2;

insert into bids (lot_id, bidder_id, bid_amount)
select l.lot_id, p.participant_id, 150
from lots l, participants p
limit 2;

insert into auction_results (lot_id, final_price, closed_at)
select lot_id, 300, current_timestamp from lots limit 2;

insert into payments (result_id, payer_id, amount, method)
select r.result_id, p.participant_id, 300, 'card'
from auction_results r, participants p
limit 2;

-- 5. Adding record_ts column to all tables

alter table countries add column if not exists record_ts date default current_date not null;
alter table categories add column if not exists record_ts date default current_date not null;
alter table participants add column if not exists record_ts date default current_date not null;
alter table employees add column if not exists record_ts date default current_date not null;
alter table auction_locations add column if not exists record_ts date default current_date not null;
alter table items add column if not exists record_ts date default current_date not null;
alter table auction_events add column if not exists record_ts date default current_date not null;
alter table lots add column if not exists record_ts date default current_date not null;
alter table lot_items add column if not exists record_ts date default current_date not null;
alter table bids add column if not exists record_ts date default current_date not null;
alter table auction_results add column if not exists record_ts date default current_date not null;
alter table payments add column if not exists record_ts date default current_date not null;

-- Validation
select count(*) from participants where record_ts is null;

/* Clarifications:
If foreign key was missing, it would break relationships and it would lead to orphan records for 
example bid for non-existing lot. 
if child table was created first sql would tell us that parent_table does not exist. 
for constraints : 
	Not null prevents missing required data and without it we would have incomplete records. 
	Unique prevents duplicate values and without it we would have inconsistent system
	Check(date>2000) prevents invalid dates and without it we would have wrong timeline
	check(>=0) perevents negative prices and without it we would get illogical values
	FK prevents invalid relations and without it we would have broken database