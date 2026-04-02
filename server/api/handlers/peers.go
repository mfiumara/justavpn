package handlers

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/justavpn/server-api/wireguard"
)

type Handler struct {
	configDir string
}

func New(configDir string) *Handler {
	return &Handler{configDir: configDir}
}

type createPeerRequest struct {
	Name string `json:"name"`
	DNS  string `json:"dns,omitempty"`
}

type createPeerResponse struct {
	Peer       wireguard.PeerInfo `json:"peer"`
	ClientConf string             `json:"clientConfig"`
}

func (h *Handler) ListPeers(w http.ResponseWriter, r *http.Request) {
	peers, err := wireguard.ListPeers(h.configDir)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, peers)
}

func (h *Handler) CreatePeer(w http.ResponseWriter, r *http.Request) {
	var req createPeerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.Name == "" {
		writeError(w, http.StatusBadRequest, "name is required")
		return
	}

	peer, clientConf, err := wireguard.CreatePeer(h.configDir, req.Name, req.DNS)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, createPeerResponse{
		Peer:       *peer,
		ClientConf: clientConf,
	})
}

func (h *Handler) GetPeerConfig(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	if name == "" {
		writeError(w, http.StatusBadRequest, "name is required")
		return
	}
	conf, err := wireguard.GetPeerConfig(h.configDir, name)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			writeError(w, http.StatusNotFound, err.Error())
		} else {
			writeError(w, http.StatusInternalServerError, err.Error())
		}
		return
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="`+name+`.conf"`)
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(conf))
}

func (h *Handler) DeletePeer(w http.ResponseWriter, r *http.Request) {
	publicKey := r.PathValue("publicKey")
	if publicKey == "" {
		writeError(w, http.StatusBadRequest, "publicKey is required")
		return
	}

	if err := wireguard.DeletePeer(h.configDir, publicKey); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
