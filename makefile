.PHONY: fmt all

all: fmt static/main.js static/backend.html

static/main.js: src/Main.elm src/Design.elm src/Common.elm
	elm-format src --yes
	elm make src/Main.elm --optimize --output=static/main.js

static/backend.html: src/Common.elm src/Backend.elm
	elm-format src --yes
	elm make src/Backend.elm --optimize --output=static/backend.html

fmt: static/index.html static/style.css init.py static/main.js
	prettier --write static/index.html
	prettier --write static/style.css
	black .

