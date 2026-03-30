package com.justavpn.tunnel

import com.justavpn.JustAVPNApp
import com.justavpn.data.ConnectionState
import com.justavpn.data.ServerConfig
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import com.wireguard.config.InetEndpoint
import com.wireguard.config.InetNetwork
import com.wireguard.config.Interface
import com.wireguard.config.Peer
import com.wireguard.crypto.Key
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.Instant

class TunnelManager {
    private val backend get() = JustAVPNApp.instance.backend
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val _state = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val state: StateFlow<ConnectionState> = _state.asStateFlow()

    private var currentTunnel: JustAVPNTunnel? = null
    private var pauseJob: Job? = null

    fun connect(config: ServerConfig) {
        cancelPause()
        _state.value = ConnectionState.Connecting

        scope.launch {
            try {
                val tunnel = JustAVPNTunnel(config.name)
                val wgConfig = buildWireGuardConfig(config)
                backend.setState(tunnel, Tunnel.State.UP, wgConfig)
                currentTunnel = tunnel
                _state.value = ConnectionState.Connected()
            } catch (e: Exception) {
                _state.value = ConnectionState.Error(e.message ?: "Connection failed")
            }
        }
    }

    fun disconnect() {
        cancelPause()
        val tunnel = currentTunnel ?: return
        _state.value = ConnectionState.Disconnecting

        scope.launch {
            try {
                backend.setState(tunnel, Tunnel.State.DOWN, null)
                currentTunnel = null
                _state.value = ConnectionState.Disconnected
            } catch (e: Exception) {
                _state.value = ConnectionState.Error(e.message ?: "Disconnect failed")
            }
        }
    }

    fun toggle(config: ServerConfig?) {
        when (_state.value) {
            is ConnectionState.Connected, is ConnectionState.Connecting -> disconnect()
            is ConnectionState.Disconnected, is ConnectionState.Error, is ConnectionState.Paused -> {
                config?.let { connect(it) }
            }
            else -> {}
        }
    }

    fun pause(seconds: Int, config: ServerConfig) {
        if (_state.value !is ConnectionState.Connected) return

        val resumeAt = Instant.now().plusSeconds(seconds.toLong())
        disconnect()
        _state.value = ConnectionState.Paused(resumeAt)

        pauseJob = scope.launch {
            delay(seconds * 1000L)
            if (isActive) {
                connect(config)
            }
        }
    }

    private fun cancelPause() {
        pauseJob?.cancel()
        pauseJob = null
    }

    private fun buildWireGuardConfig(config: ServerConfig): Config {
        val interfaceBuilder = Interface.Builder().apply {
            parsePrivateKey(config.privateKey)
            parseAddresses(config.address)
            parseDnsServers(config.dns)
        }

        val peerBuilder = Peer.Builder().apply {
            parsePublicKey(config.publicKey)
            config.presharedKey?.let { parsePreSharedKey(it) }
            parseEndpoint(config.endpoint)
            parseAllowedIPs(config.allowedIPs)
            parsePersistentKeepalive("${config.persistentKeepalive}")
        }

        return Config.Builder()
            .setInterface(interfaceBuilder.build())
            .addPeer(peerBuilder.build())
            .build()
    }

    companion object {
        val instance by lazy { TunnelManager() }
    }
}

class JustAVPNTunnel(private val tunnelName: String) : Tunnel {
    override fun getName(): String = tunnelName
    override fun onStateChange(newState: Tunnel.State) {}
}
