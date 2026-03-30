# --- SSH Key ---

resource "hcloud_ssh_key" "justavpn" {
  name       = "justavpn"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# --- API Token ---

resource "random_password" "api_token" {
  length  = 64
  special = false
}

# --- Firewall ---

resource "hcloud_firewall" "justavpn" {
  name = "justavpn"

  # SSH - restricted to admin IP
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.admin_ip]
  }

  # WireGuard - open to all (clients connect from anywhere)
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = tostring(var.wg_port)
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Management API - restricted to admin IP
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "8443"
    source_ips = [var.admin_ip]
  }
}

# --- Cloud Init ---

locals {
  cloud_init = <<-YAML
    #cloud-config
    package_update: true
    package_upgrade: true

    packages:
      - git
      - curl

    write_files:
      - path: /opt/justavpn/setup.sh
        permissions: "0755"
        content: |
          #!/usr/bin/env bash
          set -euo pipefail

          echo "[*] Installing Docker..."
          curl -fsSL https://get.docker.com | sh
          systemctl enable docker

          echo "[*] Cloning JustAVPN..."
          git clone "${var.repo_url}" /opt/justavpn/repo
          cd /opt/justavpn/repo/server

          echo "[*] Configuring..."
          PUBLIC_IP=$(curl -s https://ifconfig.me)
          cat > .env << EOF
          SERVER_PUBLIC_IP=$PUBLIC_IP
          WG_PORT=${var.wg_port}
          WG_SUBNET=${var.wg_subnet}
          API_TOKEN=${random_password.api_token.result}
          API_PORT=8443
          EOF

          echo "[*] Starting JustAVPN..."
          docker compose up -d

          echo "[*] Done!"

    runcmd:
      - bash /opt/justavpn/setup.sh 2>&1 | tee /var/log/justavpn-setup.log
  YAML
}

# --- Server ---

resource "hcloud_server" "justavpn" {
  name        = "justavpn"
  server_type = var.server_type
  location    = var.location
  image       = "ubuntu-24.04"

  ssh_keys = [hcloud_ssh_key.justavpn.id]

  firewall_ids = [hcloud_firewall.justavpn.id]

  user_data = local.cloud_init

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  labels = {
    app = "justavpn"
  }
}
