package com.iamsaifsaiful.riyal_hisab

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity: local_auth (fingerprint) needs a FragmentActivity.
// "riyal/push": Firebase started with the server's settings, and the token.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "riyal/push").setMethodCallHandler { call, result ->
            PushService.handle(this, call, result)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "riyal/pdf").setMethodCallHandler { call, result ->
            PdfTools.handle(this, call, result)
        }
    }
}
