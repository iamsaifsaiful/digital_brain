package com.iamsaifsaiful.digital_brain

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity is needed by local_auth (fingerprint dialog).
 * FLAG_SECURE keeps passwords out of screenshots, screen recordings and the
 * recent-apps preview.
 *
 * The "my_assistant/files" channel saves a backup file where the user
 * chooses (Download, Drive folder…) through Android's own save dialog.
 */
class MainActivity : FlutterFragmentActivity() {
    private var pendingBytes: ByteArray? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/files").setMethodCallHandler { call, result ->
            if (call.method != "saveFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            val name = call.argument<String>("name") ?: "my-assistant-backup.dbrain"
            if (bytes == null) {
                result.error("args", "no data", null)
                return@setMethodCallHandler
            }
            pendingResult?.success(false)
            pendingBytes = bytes
            pendingResult = result
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/octet-stream"
                putExtra(Intent.EXTRA_TITLE, name)
            }
            try {
                startActivityForResult(intent, SAVE_REQUEST)
            } catch (e: Exception) {
                pendingResult = null
                pendingBytes = null
                result.error("no_picker", e.message, null)
            }
        }
    }

    @Deprecated("Uses the platform result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_REQUEST) return
        val result = pendingResult ?: return
        val bytes = pendingBytes
        pendingResult = null
        pendingBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
            result.success(false)
            return
        }
        try {
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
            result.success(true)
        } catch (e: Exception) {
            result.error("write", e.message, null)
        }
    }

    companion object {
        private const val SAVE_REQUEST = 4711
    }
}
