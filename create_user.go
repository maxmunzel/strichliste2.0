package main

import (
	"bytes"
	"encoding/base32"
	"encoding/json"
	"golang.org/x/crypto/sha3"
	"io"
	"log"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// firstly, make sure we have all parameters we want
		err := r.ParseMultipartForm(10 * 1024 * 1024)
		if err != nil {
			log.Println("Cant parse Form.")
			log.Println(err)
			return
		}
		jwt := r.Form.Get("jwt")
		user_name := r.Form.Get("name")

		file, head, err := r.FormFile("file")
		if err != nil {
			log.Println("Cant read file")
			log.Print(err)
			return
		}
		file_contents := bytes.NewBuffer(nil)
		io.Copy(file_contents, file)

		// prepend the files hash to make the filename (hence URL) non-enumeratable
		filename := "/profile_pics/" + base32.StdEncoding.EncodeToString(sha3.New256().Sum(file_contents.Bytes()))[:20] + "_" + head.Filename

		type newUser = struct {
			Name   string `json:"name"`
			Avatar string `json:"avatar"`
		}
		body, err := json.Marshal(newUser{user_name, filename})
		if err != nil {
			log.Println("Can't create Payload.")
			log.Println(err)
			http.Error(w, "Internal Error", 500)
			return
		}
		log.Println(body)
		body_reader := bytes.NewBuffer(body)
		req, err := http.NewRequest("POST", "http://api:3000/users", body_reader)
		req.Header.Add("Content-Type", "application/json")
		req.Header.Add("Authorization", "Bearer "+jwt)
		response, err := http.DefaultClient.Do(req)
		if err != nil || response.StatusCode != 200 {
			log.Println(err)
			log.Println(response)
			http.Error(w, "Could not create User", 500)
		}

		dest_file, err := os.Create(filename)
		defer dest_file.Close()
		if err != nil {
			log.Println("Cant create file")
			log.Print(err)
			return
		}
		_, err = io.Copy(dest_file, file)
		if err != nil {
			log.Println("Cant write file")
			log.Print(err)
			return
		}
	})

	log.Fatal(http.ListenAndServe(":8088", nil))
}
