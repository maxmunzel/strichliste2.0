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
	"os"
	"path/filepath"
	"strconv"
)

type FileList = struct {
	Files []string `json:"files"`
}

func main() {
	http.HandleFunc("/get_report", func(w http.ResponseWriter, r *http.Request) {
		ok, err := is_authenticated_as(r, "xxxx_user")

		if !ok || err != nil {
			http.Error(w, "Please provide valid jwt via the \"Authorization\" header.", 401)
			return
		}

		report := r.Header.Get("report")
		if report == "" {
			http.Error(w, "Please specify required report via the \"report\" header.", 400)
			return
		}

		_, report = filepath.Split(report) // split of dir to avoid something like "../../etc/passwd"

		report_path := "../reports/" + report
		file, err := os.Open(report_path)
		defer file.Close()
		if err != nil {
			log.Printf("WARN: Could not open report \"%s\": %s\n", report_path, err)
			http.Error(w, "Could not find report "+report+".", 404)
			return
		}
		w.Header().Add("Content-Type", "application/octet-stream")
		_, err = io.Copy(w, file)
		if err != nil {
			http.Error(w, "Internal Error", 500)
		}
	})

	http.HandleFunc("/list_reports", func(w http.ResponseWriter, r *http.Request) {
		ok, err := is_authenticated_as(r, "xxxx_user")

		if !ok || err != nil {
			http.Error(w, "Please provide valid jwt via the \"Authorization\" header.", 401)
			return
		}
		// firstly, make sure we have all parameters we want

		files, err := ioutil.ReadDir("../reports")
		if err != nil {
			log.Println(err)
			http.Error(w, "Could not read Reports", 500)
			return
		}

		payload := FileList{}
		payload.Files = make([]string, 0, 10)
		for _, file := range files {
			payload.Files = append(payload.Files, file.Name())
		}
		payload_json, err := json.Marshal(payload.Files)
		if err != nil {
			log.Fatalln(err)
		}

		w.Header().Add("Content-Type", "application/json")
		w.Write(payload_json)
	})
	http.HandleFunc("/create_user", func(w http.ResponseWriter, r *http.Request) {
		// firstly, make sure we have all parameters we want
		err := r.ParseMultipartForm(10 * 1024 * 1024)
		if err != nil {
			log.Println("Cant parse Form.")
			log.Println(err)
			return
		}
		jwt := r.Form.Get("jwt")
		user_name := r.Form.Get("name")

		file, _, err := r.FormFile("file")
		if err != nil {
			log.Println("Cant read file")
			log.Print(err)
			return
		}
		buf := bytes.NewBuffer(nil)
		io.Copy(buf, file)
		file_contents := buf.Bytes()

		cropped, err := cropscalePng(bytes.NewBuffer(file_contents), 200, 200)
		if err != nil {
			log.Printf("Error scaling image: %s\n", err)
			http.Error(w, "Invalid Image", 400)
			return
		}

		hash := sha3.Sum256(file_contents)
		hash_slice := hash[:]
		hash_str := base32.StdEncoding.EncodeToString(hash_slice)[:25]

		filename := "/profile_pics/" + hash_str + ".png"

		type newUser = struct {
			Name   string `json:"name"`
			Avatar string `json:"avatar"`
		}
		body, _ := json.Marshal(newUser{user_name, filename})
		body_reader := bytes.NewBuffer(body)
		req, err := http.NewRequest("POST", "http://postgrest:3000/users", body_reader)
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
	http.HandleFunc("/create_product", func(w http.ResponseWriter, r *http.Request) {
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
		req, err := http.NewRequest("POST", "http://postgrest:3000/products", body_reader)
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

	log.Println("Starting API Server")
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
func is_authenticated_as(r *http.Request, user string) (bool, error) {
	// check if a given request has the proper authentication as the required user by consulting the auth service
	// if user != r.Header.Get("user") {
	// 	return false, nil
	// }

	c := http.Client{}
	req, err := http.NewRequest("GET", "http://auth:8080/check_jwt", nil)
	if err != nil {
		return false, err
	}

	req.Header.Add("user", user)
	req.Header.Add("Authorization", r.Header.Get("Authorization"))

	resp, err := c.Do(req)
	if err != nil {
		log.Printf("Error consulting auth service: %s\n", err)
		return false, nil
	}

	if resp.StatusCode != 200 {
		msg, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			msg = []byte(err.Error())
		}
		return false, errors.New(string(msg))
	}

	return true, nil
}
