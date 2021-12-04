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
)

type secrets = struct {
	Tokens struct {
		Xxxx_user  string
		Order_user string
	}
	Password_sha3_256 string
}

func main() {
	secrets_bytes, err := ioutil.ReadFile("secrets.json")
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

	http.HandleFunc("/get_jwt", func(w http.ResponseWriter, r *http.Request) {
		password := r.Header.Get("password")
		user := r.Header.Get("user")
		password_hash := make([]byte, 32)
		sha3.ShakeSum256(password_hash, []byte(password))
		h := sha3.New256()
		h.Write([]byte(password))
		password_hash = h.Sum(nil)

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
