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
	"strconv"
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
		name := r.Form.Get("name")
		description := r.Form.Get("description")
		price, err := strconv.ParseFloat(r.Form.Get("price"), 64)
		if err != nil {
			http.Error(w, "Cant parse price", 400)
			return
		}
		volume_in_ml, err := strconv.ParseFloat(r.Form.Get("volume_in_ml"), 64)
		if err != nil {
			http.Error(w, "Cant parse volume_in_ml", 400)
			return
		}
		alcohol_content, err := strconv.ParseFloat(r.Form.Get("alcohol_content"), 64)
		if err != nil {
			http.Error(w, "Cant parse alcohol_content", 400)
			return
		}
		location := r.Form.Get("location")

		file, _, err := r.FormFile("image")
		if err != nil {
			log.Println("Cant read file")
			log.Print(err)
			return
		}
		buf := bytes.NewBuffer(nil)
		io.Copy(buf, file)
		file_contents := buf.Bytes()

		file_contents_copy := make([]byte, len(file_contents))
		copy(file_contents_copy, file_contents)
		cropped, err := cropscalePng(bytes.NewReader(file_contents_copy), 140, 400)
		if err != nil {
			log.Printf("Error scaling image: %s\n", err)
			http.Error(w, "Invalid Image", 400)
			return
		}

		hash := sha3.Sum256(file_contents)
		hash_slice := hash[:]
		hash_str := base32.StdEncoding.EncodeToString(hash_slice)[:25]

		filename := "/product_pics/" + hash_str + ".png"

		type newProduct = struct {
			Name            string  `json:"name"`
			Description     string  `json:"description"`
			Image           string  `json:"image"`
			Price           float64 `json:"price"`
			Volume          float64 `json:"volume_in_ml"`
			Alcohol_content float64 `json:"alcohol_content"`
			Location        string  `json:"location"`
		}
		body, _ := json.Marshal(newProduct{
			name, description, filename, price, volume_in_ml, alcohol_content, location})
		body_reader := bytes.NewBuffer(body)
		req, err := http.NewRequest("POST", "http://api:3000/products", body_reader)
		req.Header.Add("Content-Type", "application/json")
		req.Header.Add("Authorization", "Bearer "+jwt)
		response, err := http.DefaultClient.Do(req)
		if err != nil || response.StatusCode != 201 {
			log.Println(err)
			log.Println(response)
			http.Error(w, "Could not create Product", 500)
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

	log.Fatal(http.ListenAndServe(":8087", nil))
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
