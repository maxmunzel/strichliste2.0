package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"golang.org/x/crypto/sha3"
	"io/ioutil"
	"log"
	"net/http"
	"strings"
)

type secrets = struct {
	Tokens struct {
		Xxxx_user  string
		Order_user string
	}
	Password_sha3_256 string
}

func main() {
	secrets_bytes, err := ioutil.ReadFile("../secrets.json")
	if err != nil {
		log.Fatal(err)
	}
	secrets := secrets{}
	err = json.Unmarshal(secrets_bytes, &secrets)
	if err != nil {
		log.Fatal(err)
	}

	expected_hash, err := hex.DecodeString(secrets.Password_sha3_256)
	if err != nil {
		log.Fatal(err)
	}

	http.HandleFunc("/check_jwt", func(w http.ResponseWriter, r *http.Request) {
		docstring := `This endpoint expects an user ('user') and an jwt token ('Authorization') as Headers.
It returns 200 iff the given jwt is valid for the given user.
You can obtain a jwt using the /auth/get_jwt endpoint.`
		jwt := r.Header.Get("Authorization")
		user := r.Header.Get("user")

		accept := func() {
			http.Error(w, "Valid jwt for "+user+".", 200)
			fmt.Printf("INFO: Successful Authorization as %s from %s.\n", user, r.RemoteAddr)
		}

		reject := func() {
			http.Error(w, "Invalid jwt for user or incorrect request.\n"+docstring, 401)
			fmt.Printf("WARN: Invalid Authorization attempt as %s from %s.\n", user, r.RemoteAddr)
		}

		if strings.HasPrefix(jwt, "Bearer ") {
			jwt = strings.Replace(jwt, "Bearer ", "", 1)
		}

		if user == "xxxx_user" && jwt == secrets.Tokens.Xxxx_user {
			accept()
		} else if user == "order_user" && jwt == secrets.Tokens.Order_user {
			accept()
		} else {
			reject()
		}

		// Do not write to w at this point, as the http.Error() calls closed it.

	})

	http.HandleFunc("/get_jwt", func(w http.ResponseWriter, r *http.Request) {
		docstring := `This endpoint expects an user ('user') and a password ('password') as Headers.
It returns a jwt token for the user and a 200 status code iff the given password is valid for the given user. 
You can validate jwts using the /auth/check_jwt endpoint`
		password := r.Header.Get("password")
		user := r.Header.Get("user")
		password_hash := make([]byte, 32)
		sha3.ShakeSum256(password_hash, []byte(password))
		h := sha3.New256()
		h.Write([]byte(password))
		password_hash = h.Sum(nil)

		if user == "" {
			http.Error(w, docstring, 400)
			return
		}

		if bytes.Equal(password_hash, expected_hash) {
			if user == "xxxx_user" {
				fmt.Fprintf(w, "%s", secrets.Tokens.Xxxx_user)
			} else if user == "order_user" {
				fmt.Fprintf(w, "%s", secrets.Tokens.Order_user)
			} else {

				http.Error(w, "Wrong Password for user.", 401)
			}

		} else {
			http.Error(w, "Wrong password for user.", 401)
		}
	})

	log.Fatal(http.ListenAndServe(":8080", nil))
}
