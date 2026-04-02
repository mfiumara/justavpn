# JustAVPN

[![Go Tests](https://github.com/mfiumara/justavpn/actions/workflows/go-tests.yml/badge.svg)](https://github.com/mfiumara/justavpn/actions/workflows/go-tests.yml)
[![codecov](https://codecov.io/gh/mfiumara/justavpn/branch/main/graph/badge.svg)](https://codecov.io/gh/mfiumara/justavpn)

A self-hosted WireGuard VPN with a management API, iOS/macOS client, and infrastructure-as-code.

## Architecture

```
infra/          Terraform (OpenTofu) — provisions Hetzner VPS
server/api/     Go HTTP API — manages WireGuard peers
apple/          iOS/macOS SwiftUI client
tests/          Integration tests (bash + curl)
```

## Server API

The API runs on port `8443` and requires a `Bearer` token via the `Authorization` header.

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/status` | Server status and public key |
| `GET` | `/api/v1/peers` | List all peers |
| `POST` | `/api/v1/peers` | Create a peer, returns WireGuard config |
| `GET` | `/api/v1/peers/{name}/config` | Download a peer's `.conf` file |
| `DELETE` | `/api/v1/peers/{publicKey}` | Remove a peer |

### Create a peer

```bash
curl -s \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "my-laptop"}' \
  http://$SERVER:8443/api/v1/peers | jq -r '.clientConfig' > my-laptop.conf
```

### Download an existing peer config

```bash
curl -s \
  -H "Authorization: Bearer $API_TOKEN" \
  http://$SERVER:8443/api/v1/peers/my-laptop/config > my-laptop.conf
```

### Delete a peer

```bash
curl -s -X DELETE \
  -H "Authorization: Bearer $API_TOKEN" \
  "http://$SERVER:8443/api/v1/peers/<base64-encoded-public-key>"
```

## Development

### Running the Go tests

```bash
cd server/api
go test ./...
```

### Running with coverage

```bash
cd server/api
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out
```

## Infrastructure

Provisioned with [OpenTofu](https://opentofu.org/) on Hetzner Cloud.

```bash
cd infra
tofu init
tofu apply
```

## iOS / macOS Client

Built with SwiftUI and [WireGuardKit](https://github.com/WireGuard/wireguard-apple).

Open `apple/` in Xcode, configure your signing team, and run.
