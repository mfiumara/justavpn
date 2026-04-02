package main

import (
	"log"
	"net/http"
	"os"

	"github.com/justavpn/server-api/auth"
	"github.com/justavpn/server-api/handlers"
)

func main() {
	token := os.Getenv("API_TOKEN")
	if token == "" {
		log.Fatal("API_TOKEN environment variable is required")
	}

	configDir := os.Getenv("CONFIG_DIR")
	if configDir == "" {
		configDir = "/opt/justavpn/configs"
	}

	mux := http.NewServeMux()

	h := handlers.New(configDir)

	mux.HandleFunc("GET /api/v1/status", h.GetStatus)
	mux.HandleFunc("GET /api/v1/peers", h.ListPeers)
	mux.HandleFunc("POST /api/v1/peers", h.CreatePeer)
	mux.HandleFunc("GET /api/v1/peers/{name}/config", h.GetPeerConfig)
	mux.HandleFunc("DELETE /api/v1/peers/{publicKey}", h.DeletePeer)

	authed := auth.TokenMiddleware(token, mux)

	log.Println("API server listening on :8443")
	if err := http.ListenAndServe(":8443", authed); err != nil {
		log.Fatal(err)
	}
}
