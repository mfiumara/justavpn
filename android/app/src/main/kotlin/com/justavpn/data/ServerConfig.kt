package com.justavpn.data

import java.util.UUID

data class ServerConfig(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val endpoint: String,
    val publicKey: String,
    val presharedKey: String? = null,
    val privateKey: String,
    val address: String,
    val dns: String = "1.1.1.1, 1.0.0.1",
    val allowedIPs: String = "0.0.0.0/0, ::/0",
    val persistentKeepalive: Int = 25
) {
    companion object {
        fun fromWireGuardConfig(text: String, name: String = "Imported Server"): ServerConfig? {
            var privateKey = ""
            var address = ""
            var dns = "1.1.1.1"
            var publicKey = ""
            var presharedKey: String? = null
            var endpoint = ""
            var allowedIPs = "0.0.0.0/0, ::/0"
            var keepalive = 25

            var inInterface = false
            var inPeer = false

            for (line in text.lines()) {
                val trimmed = line.trim()
                if (trimmed.startsWith("[Interface]")) { inInterface = true; inPeer = false; continue }
                if (trimmed.startsWith("[Peer]")) { inPeer = true; inInterface = false; continue }

                val parts = trimmed.split("=", limit = 2).map { it.trim() }
                if (parts.size != 2) continue
                val (key, value) = parts

                if (inInterface) {
                    when (key) {
                        "PrivateKey" -> privateKey = value
                        "Address" -> address = value
                        "DNS" -> dns = value
                    }
                } else if (inPeer) {
                    when (key) {
                        "PublicKey" -> publicKey = value
                        "PresharedKey" -> presharedKey = value
                        "Endpoint" -> endpoint = value
                        "AllowedIPs" -> allowedIPs = value
                        "PersistentKeepalive" -> keepalive = value.toIntOrNull() ?: 25
                    }
                }
            }

            if (publicKey.isBlank() || endpoint.isBlank() || address.isBlank() || privateKey.isBlank()) {
                return null
            }

            return ServerConfig(
                name = name,
                endpoint = endpoint,
                publicKey = publicKey,
                presharedKey = presharedKey,
                privateKey = privateKey,
                address = address,
                dns = dns,
                allowedIPs = allowedIPs,
                persistentKeepalive = keepalive
            )
        }
    }
}
