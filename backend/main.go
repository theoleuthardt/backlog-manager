package main

import (
	"log"
	"net/http"
)

func main() {
	log.Println("Server runs on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
