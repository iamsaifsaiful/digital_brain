package com.iamsaifsaiful.riyal_hisab

import android.app.Application

/** Starts Firebase with the settings the server gave at sign-in, so push
 *  arrives even when the app was closed. */
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        PushService.startSaved(this)
    }
}
