variable "hcloud_token" {
  description = "Hetzner Cloud API token (create at https://console.hetzner.cloud > Security > API Tokens)"
  type        = string
  sensitive   = true
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cx22"
}

variable "location" {
  description = "Hetzner datacenter location (fsn1=Falkenstein, nbg1=Nuremberg, hel1=Helsinki, ash=Ashburn)"
  type        = string
  default     = "fsn1"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "repo_url" {
  description = "Git repo URL for JustAVPN"
  type        = string
}

variable "wg_port" {
  description = "WireGuard listen port"
  type        = number
  default     = 51820
}

variable "wg_subnet" {
  description = "WireGuard VPN subnet"
  type        = string
  default     = "10.66.66.0/24"
}

variable "admin_ip" {
  description = "Your IP address for SSH and API access (e.g. 203.0.113.1/32). Use 0.0.0.0/0 to allow all (not recommended)."
  type        = string
}
