package com.iamsaifsaiful.my_assistant_admin

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity: local_auth's fingerprint dialog needs it.
 * FLAG_SECURE keeps members' emails and payments out of screenshots and the
 * recent-apps preview. "my_assistant/push": the Firebase token.
 * "my_assistant/open": a link in the phone's browser (the members PDF).
 * "my_assistant/bkash": বিকাশ মেলানো on the payment-SIM phone (BkashSms.kt).
 */
class MainActivity : FlutterFragmentActivity() {
    private var smsAsk: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
        // New payments come as notifications: ask once on Android 13+.
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/push").setMethodCallHandler { call, result ->
            PushService.handle(this, call, result)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/open").setMethodCallHandler { call, result ->
            val url = call.argument<String>("url").orEmpty()
            if (!url.startsWith("https://")) {
                result.success(false)
            } else {
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/bkash").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(BkashSms.status(this) + mapOf("permission" to smsAllowed()))
                "permission" -> {
                    if (smsAllowed()) {
                        result.success(true)
                    } else {
                        smsAsk = result
                        requestPermissions(arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS), 7)
                    }
                }
                "setup" -> {
                    BkashSms.setup(this, call.argument<String>("key").orEmpty(), call.argument<String>("base").orEmpty())
                    result.success(true)
                }
                "off" -> {
                    BkashSms.off(this)
                    result.success(true)
                }
                // Recent bKash payments from the inbox (parsed here; only the four fields).
                "scan" -> Thread {
                    val items = BkashSms.scan(this, call.argument<Int>("days") ?: 3)
                    val list = items.map { mapOf("trx" to it.optString("trx"), "amount" to it.optInt("amount"), "sender" to it.optString("sender"), "at" to it.optString("at")) }
                    runOnUiThread { result.success(list) }
                }.start()
                // What waited (offline) goes now.
                "flush" -> Thread {
                    BkashSms.send(applicationContext, emptyList())
                    runOnUiThread { result.success(BkashSms.status(this)) }
                }.start()
                else -> result.notImplemented()
            }
        }
    }

    private fun smsAllowed() = checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED &&
        checkSelfPermission(Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7) {
            smsAsk?.success(smsAllowed())
            smsAsk = null
        }
    }
}
