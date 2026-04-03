package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/justavpn/server-api/wireguard"
)

// ── helpers ──────────────────────────────────────────────────────────────────

func setupConfigDir(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	// Write server.env
	env := &wireguard.ServerEnv{
		PublicIP:  "1.2.3.4",
		PublicKey: "serverPubKey==",
		Port:      "51820",
		Subnet:    "10.66.66.0/24",
		ServerIP:  "10.66.66.1",
		Iface:     "eth0",
		NextIP:    2,
	}
	if err := wireguard.SaveServerEnv(dir, env); err != nil {
		t.Fatal(err)
	}
	return dir
}

func addPeer(t *testing.T, dir, name, pubKey, ip string) {
	t.Helper()
	peerDir := filepath.Join(dir, "peers", name)
	if err := os.MkdirAll(peerDir, 0700); err != nil {
		t.Fatal(err)
	}
	meta := "PEER_NAME=" + name + "\nPEER_PUBLIC_KEY=" + pubKey + "\nPEER_IP=" + ip + "\nCREATED=2024-01-01T00:00:00Z\n"
	if err := os.WriteFile(filepath.Join(peerDir, "metadata.env"), []byte(meta), 0600); err != nil {
		t.Fatal(err)
	}
	conf := "[Interface]\nPrivateKey = abc\nAddress = " + ip + "/32\n"
	if err := os.WriteFile(filepath.Join(peerDir, name+".conf"), []byte(conf), 0600); err != nil {
		t.Fatal(err)
	}
}

// ── writeJSON / writeError ───────────────────────────────────────────────────

func TestWriteJSON(t *testing.T) {
	rr := httptest.NewRecorder()
	writeJSON(rr, http.StatusOK, map[string]string{"key": "value"})

	if rr.Code != http.StatusOK {
		t.Errorf("got status %d, want %d", rr.Code, http.StatusOK)
	}
	if ct := rr.Header().Get("Content-Type"); ct != "application/json" {
		t.Errorf("Content-Type: got %q, want %q", ct, "application/json")
	}

	var body map[string]string
	json.NewDecoder(rr.Body).Decode(&body)
	if body["key"] != "value" {
		t.Errorf("body: got %v", body)
	}
}

func TestWriteError(t *testing.T) {
	rr := httptest.NewRecorder()
	writeError(rr, http.StatusBadRequest, "something went wrong")

	if rr.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want %d", rr.Code, http.StatusBadRequest)
	}

	var body map[string]string
	json.NewDecoder(rr.Body).Decode(&body)
	if body["error"] != "something went wrong" {
		t.Errorf("error: got %q", body["error"])
	}
}

// ── ListPeers ────────────────────────────────────────────────────────────────

func TestListPeers_Empty(t *testing.T) {
	dir := setupConfigDir(t)
	h := New(dir)

	req := httptest.NewRequest("GET", "/api/v1/peers", nil)
	rr := httptest.NewRecorder()
	h.ListPeers(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("got status %d, want %d", rr.Code, http.StatusOK)
	}

	var peers []wireguard.PeerInfo
	json.NewDecoder(rr.Body).Decode(&peers)
	if len(peers) != 0 {
		t.Errorf("expected 0 peers, got %d", len(peers))
	}
}

func TestListPeers_WithPeers(t *testing.T) {
	dir := setupConfigDir(t)
	addPeer(t, dir, "alice", "alicePub==", "10.66.66.2")
	addPeer(t, dir, "bob", "bobPub==", "10.66.66.3")
	h := New(dir)

	req := httptest.NewRequest("GET", "/api/v1/peers", nil)
	rr := httptest.NewRecorder()
	h.ListPeers(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("got status %d, want %d", rr.Code, http.StatusOK)
	}

	var peers []wireguard.PeerInfo
	json.NewDecoder(rr.Body).Decode(&peers)
	if len(peers) != 2 {
		t.Errorf("expected 2 peers, got %d", len(peers))
	}
}

// ── GetPeerConfig ────────────────────────────────────────────────────────────

func TestGetPeerConfig_Success(t *testing.T) {
	dir := setupConfigDir(t)
	addPeer(t, dir, "alice", "alicePub==", "10.66.66.2")
	h := New(dir)

	req := httptest.NewRequest("GET", "/api/v1/peers/alice/config", nil)
	req.SetPathValue("name", "alice")
	rr := httptest.NewRecorder()
	h.GetPeerConfig(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("got status %d, want %d", rr.Code, http.StatusOK)
	}
	if ct := rr.Header().Get("Content-Type"); ct != "text/plain; charset=utf-8" {
		t.Errorf("Content-Type: got %q", ct)
	}
	if disp := rr.Header().Get("Content-Disposition"); !strings.Contains(disp, "alice.conf") {
		t.Errorf("Content-Disposition: got %q", disp)
	}
	if !strings.Contains(rr.Body.String(), "[Interface]") {
		t.Error("expected config content in body")
	}
}

func TestGetPeerConfig_NotFound(t *testing.T) {
	dir := setupConfigDir(t)
	h := New(dir)

	req := httptest.NewRequest("GET", "/api/v1/peers/ghost/config", nil)
	req.SetPathValue("name", "ghost")
	rr := httptest.NewRecorder()
	h.GetPeerConfig(rr, req)

	if rr.Code != http.StatusNotFound {
		t.Errorf("got status %d, want %d", rr.Code, http.StatusNotFound)
	}
}

func TestGetPeerConfig_MissingName(t *testing.T) {
	dir := setupConfigDir(t)
	h := New(dir)

	req := httptest.NewRequest("GET", "/api/v1/peers//config", nil)
	// Don't set path value — simulates empty name
	rr := httptest.NewRecorder()
	h.GetPeerConfig(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want %d", rr.Code, http.StatusBadRequest)
	}
}

// ── CreatePeer ───────────────────────────────────────────────────────────────

func TestCreatePeer_InvalidJSON(t *testing.T) {
	dir := setupConfigDir(t)
	h := New(dir)

	req := httptest.NewRequest("POST", "/api/v1/peers", strings.NewReader("not json"))
	rr := httptest.NewRecorder()
	h.CreatePeer(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want %d", rr.Code, http.StatusBadRequest)
	}
}

func TestCreatePeer_EmptyName(t *testing.T) {
	dir := setupConfigDir(t)
	h := New(dir)

	req := httptest.NewRequest("POST", "/api/v1/peers", strings.NewReader(`{"name":""}`))
	rr := httptest.NewRecorder()
	h.CreatePeer(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want %d", rr.Code, http.StatusBadRequest)
	}
}

func TestCreatePeer_MissingName(t *testing.T) {
	dir := setupConfigDir(t)
	h := New(dir)

	req := httptest.NewRequest("POST", "/api/v1/peers", strings.NewReader(`{}`))
	rr := httptest.NewRecorder()
	h.CreatePeer(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want %d", rr.Code, http.StatusBadRequest)
	}
}

// ── DeletePeer ───────────────────────────────────────────────────────────────

func TestDeletePeer_MissingPublicKey(t *testing.T) {
	dir := setupConfigDir(t)
	h := New(dir)

	req := httptest.NewRequest("DELETE", "/api/v1/peers/", nil)
	// Don't set path value — simulates empty publicKey
	rr := httptest.NewRecorder()
	h.DeletePeer(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want %d", rr.Code, http.StatusBadRequest)
	}
}

// ── GetStatus ────────────────────────────────────────────────────────────────

func TestGetStatus_Success(t *testing.T) {
	dir := setupConfigDir(t)
	addPeer(t, dir, "alice", "alicePub==", "10.66.66.2")
	h := New(dir)

	req := httptest.NewRequest("GET", "/api/v1/status", nil)
	rr := httptest.NewRecorder()
	h.GetStatus(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("got status %d, want %d", rr.Code, http.StatusOK)
	}

	var status wireguard.ServerStatus
	json.NewDecoder(rr.Body).Decode(&status)
	if status.PublicKey != "serverPubKey==" {
		t.Errorf("publicKey: got %q", status.PublicKey)
	}
	if status.PeerCount != 1 {
		t.Errorf("peerCount: got %d, want 1", status.PeerCount)
	}
	if status.Endpoint != "1.2.3.4:51820" {
		t.Errorf("endpoint: got %q", status.Endpoint)
	}
}

func TestGetStatus_MissingConfig(t *testing.T) {
	dir := t.TempDir() // no server.env
	h := New(dir)

	req := httptest.NewRequest("GET", "/api/v1/status", nil)
	rr := httptest.NewRecorder()
	h.GetStatus(rr, req)

	if rr.Code != http.StatusInternalServerError {
		t.Errorf("got status %d, want %d", rr.Code, http.StatusInternalServerError)
	}
}
