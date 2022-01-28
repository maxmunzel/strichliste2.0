# Strichliste 2.0

  A reliable, no-maintenance solution to replace tally lists.

![Screenshot of the main view showing a picture of each user.](https://user-images.githubusercontent.com/5411096/151516646-33655e9c-3ae4-4a82-a4b6-6821629d6d0a.png)
![Screenshot of the order view, where users select what they want to buy.](https://user-images.githubusercontent.com/5411096/151516691-0c9beed1-1823-4350-925d-f787e8d379a2.png)

## History and Design Goals

During my time as the treasurer of my student dormitory, I hated counting the tally lists ontop of the drinks fridge.
Not hesitant to waste hours implementing and optimizing a computer system to avoid a small manual task ([relevant xkcd](https://xkcd.com/1319/)), I created the first version of
[strichliste](https://github.com/maxmunzel/strichliste). After it served us for a few years, a vision for a better system came to mind. 

The requirements were:

1. Robustness in the face of network failures or server downtime
1. Foolproof to use for treasurers
1. Snappy on cheap hardware (We currently deploy 35€ Kindle HD tablets)
1. Completely zero-maintenance.
1. Easy backups.
1. Have pictures of both users and beverages
1. Have some products only appear on certain tablets. Use one system for drinks, the washing maschine, coffee, ...
3. Make statistics accessible to the users
4. Have a dead-simple UI (users may be drunk from time to time)
5. Be reasonably secure and temper-proof
6. Easy deployment
7. Simple, easy to change code

The result is this system. Its fits our use-case nicely and just works (tm).

## Overview & Technologies used


### User Interface

The complete system is web-based. The user interface as well as the backoffice (called "backend" for historical reasons) is written in [elm](https://elm-lang.org).
The source code for the UI is in the `src` directory and split into `Main.elm` for the user facing stuff, `Backend.html` for backoffice and `Common.elm` for the
network code they both share. To ease deployment, the compiled `main.js` and `backend.html` are checked into the git repo.

### Database

A PostgreSQL database serves as the main datastore. A [postgREST](https://postgrest.org/en/stable/) instance sits between the database and the rest of the world 
and provides auth as well as a REST API.

### API

All non-database api's are implemented in go. First, there's an `/auth` enpoint that trades passwords for jwts and also validates jwts.
A second endpoint `/api` is used to process images and serve some protected files like reports. Go is not nessessarily the best language for this
kind of use-case, but its robust standard library gives me confidence that I the code will compile and run for the forseeable future.

### Web Server

[Caddy](https://caddyserver.com) is used as both a reverse proxy for all the HTTP endpoints and also serves static files. It does HTTPS by itself and just works.

### Report Generation

The scripts in `/cronjobs` are run by a docker container connected to the database to generate billings and backups.

### Service Management

The whole project is packaged as a docker compose unit. This makes both deployment and development easier. I also make extensive use of it to
put services in private networks and limit their view on the filesystem. This should contain the effect of possible bugs.

## Deployment

```bash
$ git clone git@github.com:maxmunzel/strichliste2.0.git
$ cd strichliste2.0
$ pip3 install pyjwt  # just needed to generate secrets. If you don't like python, send me an email and I generate secrets for you ;)
$ python3 init.py
Please Enter the Password used for setting up Tablets and backoffice access:
****************
Congig generation successful! Secrets stored in 'secrets.json'.
$ docker compose up --build
```

Thats basically it! The only thing left to do is configure the domain name in `Caddyfile` i.e. replace `:80` in the first line with `example.com` or whatever. Also setup backups for the whole folder.
