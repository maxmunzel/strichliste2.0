.PHONY: fmt all

static/main.js: src/Main.elm src/Design.elm src/Common.elm
	elm-format src --yes
	elm make src/Main.elm --optimize --output=static/main.js


fmt: index.html static/style.css init.py static/main.js
	prettier --write index.html
	prettier --write static/style.css
	black .

all: fmt static/main.js

