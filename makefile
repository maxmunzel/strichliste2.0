.PHONY: fmt

static/main.js: src/Main.elm src/Design.elm
	elm make src/Main.elm --optimize --output=static/main.js

fmt:
	elm-format src --yes
	prettier --write index.html
	prettier --write static/style.css
	black .

