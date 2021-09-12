import random
import json
import os
import getpass
import hashlib
import sys

try:
    import jwt
except ModuleNotFoundError:
    print(
        "Error! Could not create JWT Tokens for you - run `pip3 install pyjwt` and try again"
    )
    sys.exit(1)


def generate_password():
    alphabet = "qwertzuiopasdfghjklyxcvbnmQWERTZUIOPASDFGHJKLYXCVBNM1234567890"
    return "".join(random.sample(alphabet, k=40))


def get_postgrest_config(secret: str) -> str:
    conf = (
        f"""db-uri = "postgres://rest@db:5432/postgres"\n"""
        f"""db-schema = "strichliste"\n"""
        f"""db-anon-role = "web_anon"\n"""
        f"""jwt-secret = "{secret}"\n"""
        f"""max-rows = 200 \n"""
    )
    return conf


if __name__ == "__main__":
    jwt_secret = generate_password()
    with open("postgREST.conf", "w", os.O_CREAT) as f:
        f.write(get_postgrest_config(jwt_secret))

    # generate setup password

    sha = hashlib.sha3_256()
    sha.update(
        getpass.getpass(
            "Please Enter the Password used for setting up Tablets and backoffice access"
        ).encode("utf8")
    )
    password_sha3_256 = sha.hexdigest()

    tokens = {
        user: jwt.encode({"role": user}, jwt_secret, algorithm="HS256").decode()
        for user in ["order_user", "xxxx_user"]
    }
    with open("secrets.json", "w", os.O_CREAT) as f:
        f.write(
            json.dumps(
                {
                    "jwt_secret": jwt_secret,
                    "password_sha3_256": password_sha3_256,
                    "tokens": tokens,
                }
            )
        )

    print("Congig generation successful! Secrets stored in 'secrets.json'.")
