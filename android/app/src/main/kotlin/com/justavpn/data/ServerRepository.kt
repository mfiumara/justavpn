package com.justavpn.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "justavpn")

class ServerRepository(private val context: Context) {
    private val gson = Gson()
    private val serversKey = stringPreferencesKey("servers")
    private val activeServerKey = stringPreferencesKey("active_server_id")

    val servers: Flow<List<ServerConfig>> = context.dataStore.data.map { prefs ->
        val json = prefs[serversKey] ?: "[]"
        gson.fromJson(json, object : TypeToken<List<ServerConfig>>() {}.type)
    }

    val activeServerId: Flow<String?> = context.dataStore.data.map { prefs ->
        prefs[activeServerKey]
    }

    suspend fun addServer(config: ServerConfig) {
        context.dataStore.edit { prefs ->
            val current = getServers(prefs)
            val updated = current + config
            prefs[serversKey] = gson.toJson(updated)
            if (current.isEmpty()) {
                prefs[activeServerKey] = config.id
            }
        }
    }

    suspend fun removeServer(id: String) {
        context.dataStore.edit { prefs ->
            val current = getServers(prefs)
            val updated = current.filter { it.id != id }
            prefs[serversKey] = gson.toJson(updated)
            if (prefs[activeServerKey] == id) {
                prefs[activeServerKey] = updated.firstOrNull()?.id ?: ""
            }
        }
    }

    suspend fun setActive(id: String) {
        context.dataStore.edit { prefs ->
            prefs[activeServerKey] = id
        }
    }

    private fun getServers(prefs: Preferences): List<ServerConfig> {
        val json = prefs[serversKey] ?: "[]"
        return gson.fromJson(json, object : TypeToken<List<ServerConfig>>() {}.type)
    }
}
