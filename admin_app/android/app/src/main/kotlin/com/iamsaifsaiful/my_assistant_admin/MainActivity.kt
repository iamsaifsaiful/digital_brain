package com.iamsaifsaiful.my_assistant_admin

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Google sign-in ("my_assistant/google") and push ("my_assistant/push"). */
class MainActivity : FlutterActivity() {
    private val google by lazy { GoogleAuth(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // New payments come as notifications: ask once on Android 13+.
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/google").setMethodCallHandler { call, result ->
            google.handle(call, result)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/push").setMethodCallHandler { call, result ->
            PushService.handle(this, call, result)
        }
    }

    @Deprecated("Uses the platform result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        google.onActivityResult(requestCode, data)
    }
}
