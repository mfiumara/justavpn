package com.justavpn

import android.app.Application
import com.wireguard.android.backend.GoBackend

class JustAVPNApp : Application() {
    lateinit var backend: GoBackend
        private set

    override fun onCreate() {
        super.onCreate()
        backend = GoBackend(this)
    }

    companion object {
        lateinit var instance: JustAVPNApp
            private set
    }

    init {
        instance = this
    }
}
