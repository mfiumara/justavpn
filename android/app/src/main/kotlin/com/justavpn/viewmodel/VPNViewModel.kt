package com.justavpn.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.justavpn.data.ConnectionState
import com.justavpn.data.ServerConfig
import com.justavpn.data.ServerRepository
import com.justavpn.tunnel.TunnelManager
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

class VPNViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = ServerRepository(application)
    private val tunnelManager = TunnelManager.instance

    val connectionState: StateFlow<ConnectionState> = tunnelManager.state

    val servers: StateFlow<List<ServerConfig>> = repository.servers
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val activeServerId: StateFlow<String?> = repository.activeServerId
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    val activeServer: StateFlow<ServerConfig?> = combine(servers, activeServerId) { servers, id ->
        servers.firstOrNull { it.id == id } ?: servers.firstOrNull()
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    fun toggle() {
        tunnelManager.toggle(activeServer.value)
    }

    fun pause(seconds: Int) {
        val server = activeServer.value ?: return
        tunnelManager.pause(seconds, server)
    }

    fun addServer(config: ServerConfig) {
        viewModelScope.launch { repository.addServer(config) }
    }

    fun removeServer(id: String) {
        viewModelScope.launch { repository.removeServer(id) }
    }

    fun setActiveServer(id: String) {
        viewModelScope.launch { repository.setActive(id) }
    }
}
