create schema strichliste;

create table strichliste.users(
    id serial primary key,
    name text not null,
    avatar text not null,
    active boolean default true not null
);

create table strichliste.products (
    id serial primary key,
    name text not null,
    description text default '' not null,
    image text not null,
    price numeric not null
);

create role web_anon nologin;
grant usage on schema strichliste to web_anon;

grant select on strichliste.users to web_anon;
grant select on strichliste.products to web_anon;

create role rest login noinherit password 'mysecretpassword';
grant web_anon to rest;
