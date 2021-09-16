package main

import (
	"bytes"
	"encoding/base32"
	"encoding/json"
	"errors"
	"golang.org/x/crypto/sha3"
	"golang.org/x/image/draw"
	"image"
	_ "image/jpeg"
	"image/png"
	"io"
	"io/ioutil"
	"log"
	"net/http"
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

		cropped, err := cropscalePng(file_contents, 200, 200)
		if err != nil {
			log.Printf("Error scaling image: %s\n", err)
			http.Error(w, "Invalid Image", 400)
			return
		}

		// prepend the files hash to make the filename (hence URL) non-enumeratable
		hash := sha3.New256()
		_, _ = hash.Write(file_contents.Bytes())
		hash_str := base32.StdEncoding.EncodeToString(hash.Sum(nil))[:20]
		filename := "/profile_pics/" + hash_str + "_" + head.Filename

		type newUser = struct {
			Name   string `json:"name"`
			Avatar string `json:"avatar"`
		}
		body, _ := json.Marshal(newUser{user_name, filename})
		body_reader := bytes.NewBuffer(body)
		req, err := http.NewRequest("POST", "http://api:3000/users", body_reader)
		req.Header.Add("Content-Type", "application/json")
		req.Header.Add("Authorization", "Bearer "+jwt)
		response, err := http.DefaultClient.Do(req)
		if err != nil || response.StatusCode != 201 {
			log.Println(err)
			log.Println(response)
			http.Error(w, "Could not create User", 500)
			return
		}

		err = ioutil.WriteFile(filename, cropped, 0600)
		if err != nil {
			log.Println("Cant write file")
			log.Print(err)
			http.Error(w, "", 500)
			return
		}
	})

	log.Fatal(http.ListenAndServe(":8088", nil))
}

func cropscalePng(r io.Reader, target_x, target_y int) ([]byte, error) {
	if target_x*target_y == 0 {
		return nil, errors.New("target dimensions cannot be zero")
	}
	img, _, err := image.Decode(r)
	if err != nil {
		return nil, err
	}

	ratio := float32(img.Bounds().Dx()) / float32(img.Bounds().Dy())
	ratio_target := float32(target_x) / float32(target_y)

	var crop_x, crop_y int
	if ratio < ratio_target {
		crop_x = img.Bounds().Dx()
		crop_y = int(float32(img.Bounds().Dx()) / ratio_target)
	} else {
		crop_y = img.Bounds().Dy()
		crop_x = int(float32(img.Bounds().Dy()) * ratio_target)
	}

	rect := image.Rect(
		img.Bounds().Min.X+(img.Bounds().Dx()/2)-crop_x/2,
		img.Bounds().Min.Y+(img.Bounds().Dy()/2)-crop_y/2,
		img.Bounds().Min.X+(img.Bounds().Dx()/2)+crop_x/2,
		img.Bounds().Min.Y+(img.Bounds().Dy()/2)+crop_y/2,
	)

	scaled := image.NewNRGBA(image.Rect(0, 0, target_x, target_y))
	draw.BiLinear.Scale(scaled, scaled.Rect, img, rect, draw.Over, nil)

	buf := new(bytes.Buffer)
	err = png.Encode(buf, scaled)

	return buf.Bytes(), err

}
