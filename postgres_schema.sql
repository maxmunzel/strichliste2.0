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
    price numeric not null
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

create role web_anon nologin;
grant usage on schema strichliste to web_anon;

grant select on users to web_anon;
grant select on products to web_anon;

create role rest login noinherit password '$PASSWORD';
grant web_anon to rest;

create role order_user nologin;
grant order_user to rest;
grant usage on schema strichliste to order_user;
grant insert, select on orders to order_user;
grant usage, select on sequence orders_id_seq to order_user;
--
-- Data for Name: products; Type: TABLE DATA; Schema: strichliste; Owner: postgres
--

COPY products (id, name, description, image, price) FROM stdin;
1	Ötti Softdrinks		/static/product_pics/A.png	0.35
2	Ötti Bier		/static/product_pics/B.png	0.40
3	Bier 0,3	Rothaus, Radler	/static/product_pics/C.jpg	0.8
4	Bier Premium	Augustiner, Goldköpfle, Bleifrei	/static/product_pics/D.jpg	1.1
6	Paulaner Spezi		/static/product_pics/Spezi.png	0.8
7	Sprudel		/static/product_pics/Sprudel.png	0.4
5	Mate		/static/product_pics/Mate.jpg	1.1
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: strichliste; Owner: postgres
--

COPY users (id, name, avatar, active) FROM stdin;
2	Bocky McBockface	/static/profile_pics/1.jpg	t
3	Hello Kitty	/static/profile_pics/2.jpg	t
4	Letztes Whiskasmal	/static/profile_pics/3.jpg	t
5	Bocky McGraßface	/static/profile_pics/4.jpg	t
6	Katze McWäscheleine	/static/profile_pics/5.jpg	t
7	Schlecki Giraffe	/static/profile_pics/6.jpg	t
8	Rippo Harambee	/static/profile_pics/7.jpg	t
9	Dackel Krause	/static/profile_pics/8.jpg	t
10	Meormychildren Everagain	/static/profile_pics/9.jpg	t
11	Concerned Lion	/static/profile_pics/10.jpg	t
12	YouWant Sumfuk	/static/profile_pics/11.jpg	t
13	Tiger McSadface	/static/profile_pics/12.jpg	t
14	Disturbed Tiger	/static/profile_pics/13.jpg	t
15	Bocky McGanja	/static/profile_pics/14.jpg	t
16	Matthias Ruppert	/static/profile_pics/15.jpg	t
17	Wuffer Aporti	/static/profile_pics/16.jpg	t
18	Irgendwas mit Mädchen	/static/profile_pics/17.jpg	t
19	Scratchy Kopfy	/static/profile_pics/18.jpg	t
20	Wolfy McWallpaper	/static/profile_pics/19.jpg	t
1	Reh	/static/profile_pics/0.jpg	t
\.
