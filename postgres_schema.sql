create schema strichliste;
set search_path to strichliste;
create table users
(
    id     serial primary key,
    name   text    not null,
    avatar text    not null,
    active boolean not null default true
);

create table products
(
    id              serial primary key,
    name            text    not null,
    description     text             default '' not null,
    image           text    not null,
    price           numeric not null,
    volume_in_ml    float   not null,
    alcohol_content float   not null,
    active          boolean not null default true,
    location        text    not null default 'Bar, Kühlschrank EG'
);

create table orders
(
    id            serial primary key,
    creation_date timestamptz      default NOW() not null,
    product_id    int references products (id),
    user_id       int references users (id),
    amount        int     not null,
    undone        boolean not null default false,
    location      TEXT    not null,
    idempotence_token TEXT UNIQUE
);

create index orders_undone_name on strichliste.orders (undone, creation_date);

create or replace view history as
select u.name                       as "user_name",
       o.*,
       p.name                       as "product_name",
       p.price * o.amount           as "cost",
       p.alcohol_content * p.volume_in_ml * o.amount as "ml_alcohol",
       p.alcohol_content * p.volume_in_ml * o.amount * 0.02 as "liters_beer"
from users u
         join orders o on u.id = o.user_id
         join products p on o.product_id = p.id
where o.undone = false
order by o.creation_date desc;
-- Create supporting views for users_and_costs

create view cost_last_30_days as
select o.user_id, sum(o.amount * p.price) as cost_last_30_days
from orders o
         join products p on o.product_id = p.id
where undone = false
  and creation_date between now() - interval '1 month' and now()
group by o.user_id;

create view alc_ml_last_30_days as
select o.user_id, sum(o.amount * p.alcohol_content * p.volume_in_ml) as alc_ml_last_30_days
from orders o
         join products p on o.product_id = p.id
where undone = false
  and creation_date between now() - interval '1 month' and now()
group by o.user_id;

create view cost_this_month as
select o.user_id, sum(o.amount * p.price) as cost_this_month
from orders o
         join products p on o.product_id = p.id
where undone = false
  and creation_date between date_trunc('month', now()) and now()
group by o.user_id;

create or replace view cost_last_month as
select o.user_id, sum(o.amount * p.price) as cost_last_month
from orders o
         join products p on o.product_id = p.id
where undone = false
  and creation_date between date_trunc('month', now()) - interval '1 month' and date_trunc('month', now())
group by o.user_id;

-- Create main statistics view for basic metrics

create or replace view users_and_costs as
select u.*,
       coalesce(c.cost_last_30_days, 0)   as cost_last_30_days,
       coalesce(t.cost_this_month, 0)     as cost_this_month,
       coalesce(l.cost_last_month, 0)     as cost_last_month,
       coalesce(a.alc_ml_last_30_days, 0) as alc_ml_last_30_days
from users u
         left join cost_last_30_days c on u.id = c.user_id
         left join cost_this_month t on u.id = t.user_id
         left join cost_last_month l on u.id = l.user_id
         left join alc_ml_last_30_days a on u.id = a.user_id;


create role rest login noinherit password '$PASSWORD';

create role web_anon nologin;
grant web_anon to rest;

create role order_user nologin;
grant order_user to rest;

-- general read permissions
grant select on users to order_user;
grant select on products to order_user;
grant select on orders to order_user;
grant select on users_and_costs to order_user;

-- allow order_user to place... orders
grant usage on schema strichliste to order_user;
grant insert, select on orders to order_user;
grant usage, select on sequence orders_id_seq to order_user;


create role xxxx_user nologin;
grant usage on schema strichliste to xxxx_user;
grant xxxx_user to rest;

-- general read permissions
grant select on users to xxxx_user;
grant select on products to xxxx_user;
grant select on orders to xxxx_user;
grant select on users_and_costs to xxxx_user;

-- Allow xxxx_user to update records.
-- Notice, that he is not allowed to insert orders, so that 
-- he can't be used instead of the order_user. This way it
-- is less likely that his login in leaked to clients by user error.
grant select, update, insert on users to xxxx_user;
grant usage, select on sequence users_id_seq to xxxx_user;
grant select, update, insert on products to xxxx_user;
grant usage, select on sequence products_id_seq to xxxx_user;
grant select, update on orders to xxxx_user;
grant usage, select on sequence orders_id_seq to xxxx_user;

--
-- Data for Name: products; Type: TABLE DATA; Schema: strichliste; Owner: postgres
--

COPY products (name, description, image, price, volume_in_ml, alcohol_content) FROM stdin;
Ötti Softdrinks		/product_pics/A.png	0.35	500	0.0
Ötti Bier		/product_pics/B.png	0.40	500	0.05
Bier 0,3	Rothaus, Radler	/product_pics/C.jpg	0.8	300	0.05
Bier Premium	Augustiner, Goldköpfle, Bleifrei	/product_pics/D.jpg	1.1	500	0.05
Paulaner Spezi		/product_pics/Spezi.png	0.8	500	0.0
Sprudel		/product_pics/Sprudel.png	0.4	750	0.0
Mate		/product_pics/Mate.jpg	1.1	500	0.0
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: strichliste; Owner: postgres
--

--COPY users (name, avatar, active) FROM stdin;
--Bocky McBockface	/profile_pics/1.jpg	t
--Hello Kitty	/profile_pics/2.jpg	t
--Letztes Whiskasmal	/profile_pics/3.jpg	t
--Bocky McGraßface	/profile_pics/4.jpg	t
--Katze McWäscheleine	/profile_pics/5.jpg	t
--Schlecki Giraffe	/profile_pics/6.jpg	t
--Rippo Harambee	/profile_pics/7.jpg	t
--Dackel Krause	/profile_pics/8.jpg	t
--Meormychildren Everagain	/profile_pics/9.jpg	t
--Concerned Lion	/profile_pics/10.jpg	t
--YouWant Sumfuk	/profile_pics/11.jpg	t
--Tiger McSadface	/profile_pics/12.jpg	t
--Disturbed Tiger	/profile_pics/13.jpg	t
--Bocky McGanja	/profile_pics/14.jpg	t
--Matthias Ruppert	/profile_pics/15.jpg	t
--Wuffer Aporti	/profile_pics/16.jpg	t
--Irgendwas mit Mädchen	/profile_pics/17.jpg	t
--Scratchy Kopfy	/profile_pics/18.jpg	t
--Wolfy McWallpaper	/profile_pics/19.jpg	t
--Reh	/profile_pics/0.jpg	t
--\.
