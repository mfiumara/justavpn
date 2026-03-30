package com.justavpn.data

import java.time.Instant

sealed class ConnectionState {
    data object Disconnected : ConnectionState()
    data object Connecting : ConnectionState()
    data class Connected(val since: Instant = Instant.now()) : ConnectionState()
    data object Disconnecting : ConnectionState()
    data class Paused(val resumeAt: Instant) : ConnectionState()
    data class Error(val message: String) : ConnectionState()

    val isActive: Boolean
        get() = this is Connected || this is Connecting

    val statusText: String
        get() = when (this) {
            is Disconnected -> "Disconnected"
            is Connecting -> "Connecting..."
            is Connected -> "Connected"
            is Disconnecting -> "Disconnecting..."
            is Paused -> "Paused"
            is Error -> "Error: $message"
        }
}
