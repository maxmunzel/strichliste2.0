from argparse import ArgumentParser
import json


parser = ArgumentParser()
parser.add_argument("location")
args = parser.parse_args()

location = args.location

with open("secrets.json") as f:
    jwt = json.load(f)["tokens"]["order_user"]

data = {"location": location, "orders": [], "jwtToken": jwt}

template = """
<h1> Passwort wurde gesetzt.
<script>
localStorage.setItem("persistance", '$DATA$');
</script>
"""

config_path = f"setup_{location}.html"

with open(f"static/{config_path}", "w") as f:
    f.write(template.replace("$DATA$", json.dumps(data)))

print(f"Setup Successful!, Open /{config_path} on the device to set it up.")
