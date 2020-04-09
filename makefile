static/main.js: src/Main.elm src/Design.elm
	elm make src/Main.elm --optimize --output=static/main.js
