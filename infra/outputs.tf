output "server_ip" {
  description = "Public IPv4 address of the VPN server"
  value       = hcloud_server.justavpn.ipv4_address
}

output "server_ipv6" {
  description = "Public IPv6 address of the VPN server"
  value       = hcloud_server.justavpn.ipv6_address
}

output "wireguard_endpoint" {
  description = "WireGuard endpoint for client configs"
  value       = "${hcloud_server.justavpn.ipv4_address}:${var.wg_port}"
}

output "api_url" {
  description = "Management API URL"
  value       = "http://${hcloud_server.justavpn.ipv4_address}:8443"
}

output "api_token" {
  description = "Management API bearer token"
  value       = random_password.api_token.result
  sensitive   = true
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh root@${hcloud_server.justavpn.ipv4_address}"
}

output "create_peer_command" {
  description = "Command to create a new peer"
  value       = "ssh root@${hcloud_server.justavpn.ipv4_address} 'docker exec justavpn /opt/justavpn/scripts/generate-peer.sh <name>'"
}
