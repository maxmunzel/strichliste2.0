create schema strichliste;
set search_path to strichliste;
create table users(
    id serial primary key,
    name text not null,
    avatar text not null,
    active boolean not null default true 
);

create table products (
    id serial primary key,
    name text not null,
    description text default '' not null,
    image text not null,
    price numeric not null,
    volume_in_ml float not null,
    alcohol_content float not null,
    active boolean not null default true
);

create table orders (
    id serial primary key,
    creation_date timestamptz default NOW() not null,
    product_id int references products(id),
    user_id int references users(id),
    amount int not null,
    undone boolean not null default false,
    location TEXT not null
);

create view history as
select u.name                       as "user_name",
       o.*,
       p.name                       as "product_name",
       p.price * o.amount           as "cost",
       p.alcohol_content * o.amount as "ml_alcohol"
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
       coalesce(c.cost_last_30_days, 0) as cost_last_30_days,
       coalesce(t.cost_this_month, 0)   as cost_this_month,
       coalesce(l.cost_last_month, 0)   as cost_last_month
from users u
         left join cost_last_30_days c on u.id = c.user_id
         left join cost_this_month t on u.id = t.user_id
         left join cost_last_month l on u.id = l.user_id;

create role web_anon nologin;
grant usage on schema strichliste to web_anon;

grant select on users to web_anon;
grant select on products to web_anon;
grant select on orders to web_anon;
grant select on users_and_costs to web_anon;

create role rest login noinherit password '$PASSWORD';
grant web_anon to rest;

create role order_user nologin;
grant order_user to rest;
grant usage on schema strichliste to order_user;
grant insert, select on orders to order_user;
grant usage, select on sequence orders_id_seq to order_user;

create role xxxx_user nologin;
grant usage on schema strichliste to xxxx_user;
grant xxxx_user to rest;

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
Ötti Softdrinks		/static/product_pics/A.png	0.35	500	0.0
Ötti Bier		/static/product_pics/B.png	0.40	500	0.05
Bier 0,3	Rothaus, Radler	/static/product_pics/C.jpg	0.8	300	0.05
Bier Premium	Augustiner, Goldköpfle, Bleifrei	/static/product_pics/D.jpg	1.1	500	0.05
Paulaner Spezi		/static/product_pics/Spezi.png	0.8	500	0.0
Sprudel		/static/product_pics/Sprudel.png	0.4	750	0.0
Mate		/static/product_pics/Mate.jpg	1.1	500	0.0
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: strichliste; Owner: postgres
--

COPY users (name, avatar, active) FROM stdin;
Bocky McBockface	/static/profile_pics/1.jpg	t
Hello Kitty	/static/profile_pics/2.jpg	t
Letztes Whiskasmal	/static/profile_pics/3.jpg	t
Bocky McGraßface	/static/profile_pics/4.jpg	t
Katze McWäscheleine	/static/profile_pics/5.jpg	t
Schlecki Giraffe	/static/profile_pics/6.jpg	t
Rippo Harambee	/static/profile_pics/7.jpg	t
Dackel Krause	/static/profile_pics/8.jpg	t
Meormychildren Everagain	/static/profile_pics/9.jpg	t
Concerned Lion	/static/profile_pics/10.jpg	t
YouWant Sumfuk	/static/profile_pics/11.jpg	t
Tiger McSadface	/static/profile_pics/12.jpg	t
Disturbed Tiger	/static/profile_pics/13.jpg	t
Bocky McGanja	/static/profile_pics/14.jpg	t
Matthias Ruppert	/static/profile_pics/15.jpg	t
Wuffer Aporti	/static/profile_pics/16.jpg	t
Irgendwas mit Mädchen	/static/profile_pics/17.jpg	t
Scratchy Kopfy	/static/profile_pics/18.jpg	t
Wolfy McWallpaper	/static/profile_pics/19.jpg	t
Reh	/static/profile_pics/0.jpg	t
\.
