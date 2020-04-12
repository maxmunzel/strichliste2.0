import random
from subprocess import run, PIPE
import json
import os
import time


def generate_password():
    alphabet = "qwertzuiopasdfghjklyxcvbnmQWERTZUIOPASDFGHJKLYXCVBNM1234567890"
    return "".join(random.sample(alphabet, k=40))


def get_postgrest_config(secret: str, db_rest_password: str) -> str:
    conf = (
        f"""db-uri = "postgres://rest:{db_rest_password}@localhost:5433/postgres"\n"""
        f"""db-schema = "strichliste"\n"""
        f"""db-anon-role = "web_anon"\n"""
        f"""jwt-secret = "{secret}"\n"""
        f"""max-rows = 200 \n"""
    )
    return conf



if __name__ == "__main__":
    db_pass = generate_password()  # password for the postgres superuser
    jwt_secret = generate_password()
    db_rest_password = generate_password()  # used by postgREST
    run(
        f"docker run --name strichliste_postgres -p 5433:5432 -e POSTGRES_PASSWORD={db_pass} -d postgres",
        shell=True,
    )
    time.sleep(5)
    run(
        f"sed 's/$PASSWORD/{db_rest_password}/g' postgres_schema.sql | psql -U postgres -h localhost -p 5433",
        shell=True,
        env=dict(os.environ, PGPASSWORD=db_pass, PGTIMEOUT="10")
    )
    with open("postgREST.conf", "w", os.O_CREAT) as f:
        f.write(get_postgrest_config(jwt_secret, db_rest_password))
    
    tokens = []
    try:
        import jwt
        tokens = [jwt.encode({"role":"order_user"}, jwt_secret, algorithm="HS256").decode() for _ in range(10)]
    except ModuleNotFoundError:
        print("Error! Could not create JWT Tokens for you - run `pip3 install pyjwt` and try again") 
    with open("secrets.json", "w", os.O_CREAT) as f:
        f.write(json.dumps({
            "jwt_secret":jwt_secret,
            "db_pass": db_pass,
            "db_rest_password": db_rest_password,
            "tokens": tokens}))

    print(" Congig generation successful! Secrets stored in 'secrets.json'.")
