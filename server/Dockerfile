FROM golang:1.22-bookworm AS api-builder

WORKDIR /build
COPY api/ .
RUN go mod download && CGO_ENABLED=0 go build -o /justavpn-api .

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    wireguard-tools \
    iptables \
    iproute2 \
    qrencode \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/*

COPY --from=api-builder /justavpn-api /usr/local/bin/justavpn-api
COPY scripts/ /opt/justavpn/scripts/
RUN chmod +x /opt/justavpn/scripts/*.sh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 51820/udp
EXPOSE 8443/tcp

ENTRYPOINT ["/entrypoint.sh"]
