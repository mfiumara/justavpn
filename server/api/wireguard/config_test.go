package wireguard

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// ── formatEndpoint ────────────────────────────────────────────────────────────

func TestFormatEndpoint_IPv4(t *testing.T) {
	got := formatEndpoint("1.2.3.4", "51820")
	if got != "1.2.3.4:51820" {
		t.Errorf("got %q, want %q", got, "1.2.3.4:51820")
	}
}

func TestFormatEndpoint_IPv6(t *testing.T) {
	got := formatEndpoint("2a01:4f8:c0c:946a::1", "51820")
	want := "[2a01:4f8:c0c:946a::1]:51820"
	if got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestFormatEndpoint_Hostname(t *testing.T) {
	got := formatEndpoint("vpn.example.com", "51820")
	if got != "vpn.example.com:51820" {
		t.Errorf("got %q, want %q", got, "vpn.example.com:51820")
	}
}

// ── LoadServerEnv / SaveServerEnv ─────────────────────────────────────────────

func writeEnvFile(t *testing.T, dir, content string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, "server.env"), []byte(content), 0600); err != nil {
		t.Fatal(err)
	}
}

func TestLoadServerEnv(t *testing.T) {
	dir := t.TempDir()
	writeEnvFile(t, dir, `SERVER_PUBLIC_IP=1.2.3.4
SERVER_PUBLIC_KEY=pubkey123
WG_PORT=51820
WG_SUBNET=10.66.66.0/24
WG_SERVER_IP=10.66.66.1
DEFAULT_IFACE=eth0
NEXT_IP=2
`)

	env, err := LoadServerEnv(dir)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if env.PublicIP != "1.2.3.4" {
		t.Errorf("PublicIP: got %q, want %q", env.PublicIP, "1.2.3.4")
	}
	if env.PublicKey != "pubkey123" {
		t.Errorf("PublicKey: got %q, want %q", env.PublicKey, "pubkey123")
	}
	if env.Port != "51820" {
		t.Errorf("Port: got %q, want %q", env.Port, "51820")
	}
	if env.NextIP != 2 {
		t.Errorf("NextIP: got %d, want %d", env.NextIP, 2)
	}
}

func TestLoadServerEnv_Missing(t *testing.T) {
	dir := t.TempDir()
	_, err := LoadServerEnv(dir)
	if err == nil {
		t.Error("expected error for missing server.env, got nil")
	}
}

func TestLoadServerEnv_IPv6(t *testing.T) {
	dir := t.TempDir()
	writeEnvFile(t, dir, "SERVER_PUBLIC_IP=2a01:4f8:c0c:946a::1\nWG_PORT=51820\n")

	env, err := LoadServerEnv(dir)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	endpoint := formatEndpoint(env.PublicIP, env.Port)
	want := "[2a01:4f8:c0c:946a::1]:51820"
	if endpoint != want {
		t.Errorf("endpoint: got %q, want %q", endpoint, want)
	}
}

func TestSaveAndLoadServerEnv(t *testing.T) {
	dir := t.TempDir()
	orig := &ServerEnv{
		PublicIP:  "5.6.7.8",
		PublicKey: "testkey",
		Port:      "51820",
		Subnet:    "10.66.66.0/24",
		ServerIP:  "10.66.66.1",
		Iface:     "eth0",
		NextIP:    5,
	}
	if err := SaveServerEnv(dir, orig); err != nil {
		t.Fatalf("SaveServerEnv: %v", err)
	}
	loaded, err := LoadServerEnv(dir)
	if err != nil {
		t.Fatalf("LoadServerEnv: %v", err)
	}
	if loaded.PublicIP != orig.PublicIP {
		t.Errorf("PublicIP round-trip: got %q, want %q", loaded.PublicIP, orig.PublicIP)
	}
	if loaded.NextIP != orig.NextIP {
		t.Errorf("NextIP round-trip: got %d, want %d", loaded.NextIP, orig.NextIP)
	}
}

// ── GetPeerConfig ─────────────────────────────────────────────────────────────

func writePeerConf(t *testing.T, configDir, name, content string) {
	t.Helper()
	dir := filepath.Join(configDir, "peers", name)
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, name+".conf"), []byte(content), 0600); err != nil {
		t.Fatal(err)
	}
}

func TestGetPeerConfig(t *testing.T) {
	dir := t.TempDir()
	want := "[Interface]\nPrivateKey = abc\nAddress = 10.66.66.2/32\n"
	writePeerConf(t, dir, "alice", want)

	got, err := GetPeerConfig(dir, "alice")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestGetPeerConfig_NotFound(t *testing.T) {
	dir := t.TempDir()
	_, err := GetPeerConfig(dir, "ghost")
	if err == nil {
		t.Error("expected error for missing peer, got nil")
	}
	if !strings.Contains(err.Error(), "not found") {
		t.Errorf("expected 'not found' in error, got %q", err.Error())
	}
}

// ── ListPeers ─────────────────────────────────────────────────────────────────

func writePeerMeta(t *testing.T, configDir, name, pubKey, ip string) {
	t.Helper()
	dir := filepath.Join(configDir, "peers", name)
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	meta := "PEER_NAME=" + name + "\nPEER_PUBLIC_KEY=" + pubKey + "\nPEER_IP=" + ip + "\nCREATED=2024-01-01T00:00:00Z\n"
	if err := os.WriteFile(filepath.Join(dir, "metadata.env"), []byte(meta), 0600); err != nil {
		t.Fatal(err)
	}
}

func TestListPeers_Empty(t *testing.T) {
	dir := t.TempDir()
	peers, err := ListPeers(dir)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(peers) != 0 {
		t.Errorf("expected 0 peers, got %d", len(peers))
	}
}

func TestListPeers(t *testing.T) {
	dir := t.TempDir()
	writePeerMeta(t, dir, "alice", "alicePubKey==", "10.66.66.2")
	writePeerMeta(t, dir, "bob", "bobPubKey==", "10.66.66.3")

	peers, err := ListPeers(dir)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(peers) != 2 {
		t.Errorf("expected 2 peers, got %d", len(peers))
	}

	names := map[string]bool{}
	for _, p := range peers {
		names[p.Name] = true
	}
	if !names["alice"] || !names["bob"] {
		t.Errorf("missing peers in result: %v", peers)
	}
}

func TestListPeers_SkipsFiles(t *testing.T) {
	dir := t.TempDir()
	peersDir := filepath.Join(dir, "peers")
	os.MkdirAll(peersDir, 0700)
	// Create a regular file (not a directory) — should be skipped
	os.WriteFile(filepath.Join(peersDir, "not-a-peer.txt"), []byte("hi"), 0600)
	writePeerMeta(t, dir, "alice", "alicePubKey==", "10.66.66.2")

	peers, err := ListPeers(dir)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(peers) != 1 {
		t.Errorf("expected 1 peer, got %d", len(peers))
	}
}

// ── loadPeerMeta ─────────────────────────────────────────────────────────────

func TestLoadPeerMeta(t *testing.T) {
	dir := t.TempDir()
	writePeerMeta(t, dir, "alice", "alicePubKey==", "10.66.66.2")

	meta, err := loadPeerMeta(filepath.Join(dir, "peers", "alice", "metadata.env"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if meta.Name != "alice" {
		t.Errorf("Name: got %q, want %q", meta.Name, "alice")
	}
	if meta.PublicKey != "alicePubKey==" {
		t.Errorf("PublicKey: got %q, want %q", meta.PublicKey, "alicePubKey==")
	}
	if meta.IP != "10.66.66.2" {
		t.Errorf("IP: got %q, want %q", meta.IP, "10.66.66.2")
	}
	if meta.Created != "2024-01-01T00:00:00Z" {
		t.Errorf("Created: got %q", meta.Created)
	}
}

func TestLoadPeerMeta_Missing(t *testing.T) {
	_, err := loadPeerMeta("/nonexistent/metadata.env")
	if err == nil {
		t.Error("expected error for missing file, got nil")
	}
}

func TestLoadPeerMeta_MalformedLines(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "metadata.env"), []byte("no-equals-sign\nPEER_NAME=bob\n"), 0600)

	meta, err := loadPeerMeta(filepath.Join(dir, "metadata.env"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if meta.Name != "bob" {
		t.Errorf("Name: got %q, want %q", meta.Name, "bob")
	}
}

// ── GetStatus ────────────────────────────────────────────────────────────────

func TestGetStatus(t *testing.T) {
	dir := t.TempDir()
	writeEnvFile(t, dir, `SERVER_PUBLIC_IP=5.6.7.8
SERVER_PUBLIC_KEY=srvKey==
WG_PORT=51820
WG_SUBNET=10.66.66.0/24
WG_SERVER_IP=10.66.66.1
DEFAULT_IFACE=eth0
NEXT_IP=4
`)
	writePeerMeta(t, dir, "alice", "alicePubKey==", "10.66.66.2")
	writePeerMeta(t, dir, "bob", "bobPubKey==", "10.66.66.3")

	status, err := GetStatus(dir)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if status.PublicKey != "srvKey==" {
		t.Errorf("PublicKey: got %q", status.PublicKey)
	}
	if status.ListenPort != "51820" {
		t.Errorf("ListenPort: got %q", status.ListenPort)
	}
	if status.Endpoint != "5.6.7.8:51820" {
		t.Errorf("Endpoint: got %q", status.Endpoint)
	}
	if status.PeerCount != 2 {
		t.Errorf("PeerCount: got %d, want 2", status.PeerCount)
	}
	if status.Interface != "wg0" {
		t.Errorf("Interface: got %q", status.Interface)
	}
}

func TestGetStatus_MissingEnv(t *testing.T) {
	dir := t.TempDir()
	_, err := GetStatus(dir)
	if err == nil {
		t.Error("expected error for missing server.env, got nil")
	}
}

// ── DeletePeer ───────────────────────────────────────────────────────────────

func TestDeletePeer_NotFound(t *testing.T) {
	dir := t.TempDir()
	peersDir := filepath.Join(dir, "peers")
	os.MkdirAll(peersDir, 0700)

	err := DeletePeer(dir, "nonexistentKey==")
	if err == nil {
		t.Error("expected error for missing peer, got nil")
	}
	if !strings.Contains(err.Error(), "not found") {
		t.Errorf("expected 'not found' in error, got %q", err.Error())
	}
}

func TestDeletePeer_NoPeersDir(t *testing.T) {
	dir := t.TempDir()
	err := DeletePeer(dir, "someKey==")
	if err == nil {
		t.Error("expected error when peers dir missing, got nil")
	}
}

// ── SaveServerEnv round-trip all fields ──────────────────────────────────────

func TestSaveServerEnv_AllFields(t *testing.T) {
	dir := t.TempDir()
	orig := &ServerEnv{
		PublicIP:  "2a01:4f8::1",
		PublicKey: "key==",
		Port:      "51821",
		Subnet:    "10.0.0.0/24",
		ServerIP:  "10.0.0.1",
		Iface:     "ens3",
		NextIP:    100,
	}
	if err := SaveServerEnv(dir, orig); err != nil {
		t.Fatalf("SaveServerEnv: %v", err)
	}
	loaded, err := LoadServerEnv(dir)
	if err != nil {
		t.Fatalf("LoadServerEnv: %v", err)
	}
	if loaded.Subnet != orig.Subnet {
		t.Errorf("Subnet: got %q, want %q", loaded.Subnet, orig.Subnet)
	}
	if loaded.ServerIP != orig.ServerIP {
		t.Errorf("ServerIP: got %q, want %q", loaded.ServerIP, orig.ServerIP)
	}
	if loaded.Iface != orig.Iface {
		t.Errorf("Iface: got %q, want %q", loaded.Iface, orig.Iface)
	}
}
