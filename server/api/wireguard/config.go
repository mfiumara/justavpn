package wireguard

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

func formatEndpoint(ip, port string) string {
	if strings.Contains(ip, ":") {
		return "[" + ip + "]:" + port
	}
	return ip + ":" + port
}

type ServerEnv struct {
	PublicIP  string
	PublicKey string
	Port      string
	Subnet   string
	ServerIP string
	Iface    string
	NextIP   int
}

type PeerInfo struct {
	Name          string `json:"name"`
	PublicKey     string `json:"publicKey"`
	IP            string `json:"ip"`
	Created       string `json:"created"`
	LastHandshake string `json:"lastHandshake,omitempty"`
	TransferRx    int64  `json:"transferRx,omitempty"`
	TransferTx    int64  `json:"transferTx,omitempty"`
}

type ServerStatus struct {
	PublicKey    string `json:"publicKey"`
	ListenPort  string `json:"listenPort"`
	Endpoint    string `json:"endpoint"`
	PeerCount   int    `json:"peerCount"`
	Interface   string `json:"interface"`
}

func LoadServerEnv(configDir string) (*ServerEnv, error) {
	f, err := os.Open(configDir + "/server.env")
	if err != nil {
		return nil, err
	}
	defer f.Close()

	env := &ServerEnv{}
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key, val := parts[0], parts[1]
		switch key {
		case "SERVER_PUBLIC_IP":
			env.PublicIP = val
		case "SERVER_PUBLIC_KEY":
			env.PublicKey = val
		case "WG_PORT":
			env.Port = val
		case "WG_SUBNET":
			env.Subnet = val
		case "WG_SERVER_IP":
			env.ServerIP = val
		case "DEFAULT_IFACE":
			env.Iface = val
		case "NEXT_IP":
			env.NextIP, _ = strconv.Atoi(val)
		}
	}
	return env, nil
}

func SaveServerEnv(configDir string, env *ServerEnv) error {
	content := fmt.Sprintf(`SERVER_PUBLIC_IP=%s
SERVER_PUBLIC_KEY=%s
WG_PORT=%s
WG_SUBNET=%s
WG_SERVER_IP=%s
DEFAULT_IFACE=%s
NEXT_IP=%d
`, env.PublicIP, env.PublicKey, env.Port, env.Subnet, env.ServerIP, env.Iface, env.NextIP)
	return os.WriteFile(configDir+"/server.env", []byte(content), 0600)
}

func GetStatus(configDir string) (*ServerStatus, error) {
	env, err := LoadServerEnv(configDir)
	if err != nil {
		return nil, err
	}

	peers, err := ListPeers(configDir)
	if err != nil {
		return nil, err
	}

	return &ServerStatus{
		PublicKey:   env.PublicKey,
		ListenPort: env.Port,
		Endpoint:   formatEndpoint(env.PublicIP, env.Port),
		PeerCount:  len(peers),
		Interface:  "wg0",
	}, nil
}

func ListPeers(configDir string) ([]PeerInfo, error) {
	peersDir := configDir + "/peers"
	entries, err := os.ReadDir(peersDir)
	if err != nil {
		if os.IsNotExist(err) {
			return []PeerInfo{}, nil
		}
		return nil, err
	}

	// Get live stats from wg show
	liveStats := getWgStats()

	var peers []PeerInfo
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		metaPath := peersDir + "/" + entry.Name() + "/metadata.env"
		meta, err := loadPeerMeta(metaPath)
		if err != nil {
			continue
		}

		if stats, ok := liveStats[meta.PublicKey]; ok {
			meta.LastHandshake = stats.LastHandshake
			meta.TransferRx = stats.TransferRx
			meta.TransferTx = stats.TransferTx
		}

		peers = append(peers, meta)
	}
	return peers, nil
}

func CreatePeer(configDir, name, dns string) (*PeerInfo, string, error) {
	if dns == "" {
		dns = "1.1.1.1, 1.0.0.1"
	}

	env, err := LoadServerEnv(configDir)
	if err != nil {
		return nil, "", fmt.Errorf("load server env: %w", err)
	}

	// Check duplicate
	peersDir := configDir + "/peers/" + name
	if _, err := os.Stat(peersDir); err == nil {
		return nil, "", fmt.Errorf("peer '%s' already exists", name)
	}

	// Allocate IP
	subnet := strings.TrimSuffix(env.Subnet, ".0/24")
	peerIP := fmt.Sprintf("%s.%d", subnet, env.NextIP)
	env.NextIP++

	// Generate keys
	privKey, err := runWg("genkey")
	if err != nil {
		return nil, "", fmt.Errorf("genkey: %w", err)
	}
	pubKey, err := runWgStdin("pubkey", privKey)
	if err != nil {
		return nil, "", fmt.Errorf("pubkey: %w", err)
	}
	psk, err := runWg("genpsk")
	if err != nil {
		return nil, "", fmt.Errorf("genpsk: %w", err)
	}

	// Append peer to wg0.conf
	peerBlock := fmt.Sprintf("\n# Peer: %s\n[Peer]\nPublicKey = %s\nPresharedKey = %s\nAllowedIPs = %s/32\n",
		name, pubKey, psk, peerIP)

	f, err := os.OpenFile("/etc/wireguard/wg0.conf", os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return nil, "", fmt.Errorf("open wg0.conf: %w", err)
	}
	_, err = f.WriteString(peerBlock)
	f.Close()
	if err != nil {
		return nil, "", fmt.Errorf("write wg0.conf: %w", err)
	}

	// Sync running config
	exec.Command("bash", "-c", `wg syncconf wg0 <(wg-quick strip wg0)`).Run()

	// Write client config
	os.MkdirAll(peersDir, 0700)
	clientConf := fmt.Sprintf(`[Interface]
PrivateKey = %s
Address = %s/32
DNS = %s

[Peer]
PublicKey = %s
PresharedKey = %s
Endpoint = %s
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
`, privKey, peerIP, dns, env.PublicKey, psk, formatEndpoint(env.PublicIP, env.Port))

	os.WriteFile(peersDir+"/"+name+".conf", []byte(clientConf), 0600)

	// Write metadata
	meta := fmt.Sprintf("PEER_NAME=%s\nPEER_PUBLIC_KEY=%s\nPEER_IP=%s\nCREATED=%s\n",
		name, pubKey, peerIP, time.Now().UTC().Format(time.RFC3339))
	os.WriteFile(peersDir+"/metadata.env", []byte(meta), 0600)

	// Save updated env
	SaveServerEnv(configDir, env)

	info := &PeerInfo{
		Name:      name,
		PublicKey: pubKey,
		IP:        peerIP,
		Created:   time.Now().UTC().Format(time.RFC3339),
	}
	return info, clientConf, nil
}

func GetPeerConfig(configDir, name string) (string, error) {
	confPath := configDir + "/peers/" + name + "/" + name + ".conf"
	data, err := os.ReadFile(confPath)
	if err != nil {
		if os.IsNotExist(err) {
			return "", fmt.Errorf("peer '%s' not found", name)
		}
		return "", err
	}
	return string(data), nil
}

func DeletePeer(configDir, publicKey string) error {
	// Find peer by public key
	peersDir := configDir + "/peers"
	entries, err := os.ReadDir(peersDir)
	if err != nil {
		return fmt.Errorf("read peers dir: %w", err)
	}

	var peerName string
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		meta, err := loadPeerMeta(peersDir + "/" + entry.Name() + "/metadata.env")
		if err != nil {
			continue
		}
		if meta.PublicKey == publicKey {
			peerName = meta.Name
			break
		}
	}

	if peerName == "" {
		return fmt.Errorf("peer with key '%s' not found", publicKey)
	}

	// Remove from wg0.conf
	exec.Command("bash", "-c",
		fmt.Sprintf(`sed -i '/^# Peer: %s$/,/^$/d' /etc/wireguard/wg0.conf`, peerName)).Run()

	// Remove from running interface
	exec.Command("wg", "set", "wg0", "peer", publicKey, "remove").Run()

	// Remove peer directory
	os.RemoveAll(peersDir + "/" + peerName)

	return nil
}

func runWg(args ...string) (string, error) {
	out, err := exec.Command("wg", args...).Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

func runWgStdin(arg, input string) (string, error) {
	cmd := exec.Command("wg", arg)
	cmd.Stdin = strings.NewReader(input)
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

type wgStats struct {
	LastHandshake string
	TransferRx    int64
	TransferTx    int64
}

func getWgStats() map[string]wgStats {
	stats := make(map[string]wgStats)
	out, err := exec.Command("wg", "show", "wg0", "dump").Output()
	if err != nil {
		return stats
	}

	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	// Skip first line (interface line)
	for i := 1; i < len(lines); i++ {
		fields := strings.Split(lines[i], "\t")
		if len(fields) < 8 {
			continue
		}
		pubKey := fields[0]
		rx, _ := strconv.ParseInt(fields[5], 10, 64)
		tx, _ := strconv.ParseInt(fields[6], 10, 64)
		handshake, _ := strconv.ParseInt(fields[4], 10, 64)

		s := wgStats{TransferRx: rx, TransferTx: tx}
		if handshake > 0 {
			s.LastHandshake = time.Unix(handshake, 0).UTC().Format(time.RFC3339)
		}
		stats[pubKey] = s
	}
	return stats
}

func loadPeerMeta(path string) (PeerInfo, error) {
	f, err := os.Open(path)
	if err != nil {
		return PeerInfo{}, err
	}
	defer f.Close()

	var info PeerInfo
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		parts := strings.SplitN(scanner.Text(), "=", 2)
		if len(parts) != 2 {
			continue
		}
		switch parts[0] {
		case "PEER_NAME":
			info.Name = parts[1]
		case "PEER_PUBLIC_KEY":
			info.PublicKey = parts[1]
		case "PEER_IP":
			info.IP = parts[1]
		case "CREATED":
			info.Created = parts[1]
		}
	}
	return info, nil
}
