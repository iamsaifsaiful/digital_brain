package com.iamsaifsaiful.digital_brain

import android.app.Activity
import android.Manifest
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.provider.ContactsContract
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
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
 *
 * The "my_assistant/alarm" channel helps reminders ring on every phone:
 * battery-saving exemption, the maker's own "auto-start" page, and showing
 * the alarm page over the lock screen while a reminder rings.
 */
class MainActivity : FlutterFragmentActivity() {
    private var pendingBytes: ByteArray? = null
    private var pendingResult: MethodChannel.Result? = null
    private var soundResult: MethodChannel.Result? = null
    private var contactsResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
        if (isReminderIntent(intent)) setOverLock(true)
    }

    override fun onNewIntent(intent: Intent) {
        if (isReminderIntent(intent)) setOverLock(true)
        super.onNewIntent(intent)
    }

    /** Opened by a reminder (tap or the full-screen alarm). */
    private fun isReminderIntent(i: Intent?): Boolean = i?.action == "SELECT_NOTIFICATION"

    private fun setOverLock(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    private val brand: String get() = Build.MANUFACTURER.lowercase()

    /** Makers whose phones stop apps' alarms unless "auto-start" is on. */
    private val autostartBrands = setOf(
        "xiaomi", "redmi", "poco", "oppo", "realme", "vivo", "iqoo", "huawei", "honor",
        "oneplus", "infinix", "tecno", "itel", "asus", "letv", "meizu", "samsung"
    )

    private fun batteryFree(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun tryStart(i: Intent): Boolean = try {
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(i)
        true
    } catch (e: Exception) {
        false
    }

    private fun openAutostart() {
        val pages = listOf(
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
            "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
            "com.transsion.phonemaster" to "com.cyin.himgr.autostart.AutoStartActivity",
            "com.asus.mobilemanager" to "com.asus.mobilemanager.entry.FunctionActivity",
            "com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity",
            "com.letv.android.letvsafe" to "com.letv.android.letvsafe.AutobootManageActivity"
        )
        for ((pkg, cls) in pages) {
            if (tryStart(Intent().setComponent(ComponentName(pkg, cls)))) return
        }
        tryStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
    }

    private fun askBattery() {
        if (batteryFree()) return
        val ask = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))
        if (tryStart(ask)) return
        if (tryStart(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))) return
        tryStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
    }

    /** Android's own sound picker (alarm tones, ringtones, and on many phones the user's own files). */
    private fun pickSound(current: String?, result: MethodChannel.Result) {
        soundResult?.success(null)
        soundResult = result
        val i = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALL)
            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "রিমাইন্ডারের রিংটোন")
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(RingtoneManager.EXTRA_RINGTONE_DEFAULT_URI, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
            if (current != null) putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(current))
        }
        try {
            startActivityForResult(i, SOUND_REQUEST)
        } catch (e: Exception) {
            soundResult = null
            result.error("no_picker", e.message, null)
        }
    }

    /** Every name and number in the phone book (read on a background thread). */
    private fun readContacts(result: MethodChannel.Result) {
        Thread {
            val out = ArrayList<Map<String, String>>()
            try {
                contentResolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    arrayOf(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME, ContactsContract.CommonDataKinds.Phone.NUMBER),
                    null, null, null
                )?.use { c ->
                    while (c.moveToNext()) {
                        val name = c.getString(0) ?: ""
                        val number = c.getString(1) ?: ""
                        if (number.isNotBlank()) out.add(mapOf("name" to name, "phone" to number))
                    }
                }
                runOnUiThread { result.success(out) }
            } catch (e: Exception) {
                runOnUiThread { result.error("read", e.message, null) }
            }
        }.start()
    }

    private fun contactsChannel(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        if (call.method != "readAll") {
            result.notImplemented()
            return
        }
        if (checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED) {
            readContacts(result)
            return
        }
        contactsResult?.success(null)
        contactsResult = result
        requestPermissions(arrayOf(Manifest.permission.READ_CONTACTS), CONTACTS_REQUEST)
    }

    @Deprecated("Uses the platform permission callback")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CONTACTS_REQUEST) return
        val result = contactsResult ?: return
        contactsResult = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            readContacts(result)
        } else {
            result.success(null)
        }
    }

    private fun alarmChannel(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val fullScreen = if (Build.VERSION.SDK_INT >= 34) nm.canUseFullScreenIntent() else true
                result.success(mapOf(
                    "batteryFree" to batteryFree(),
                    "fullScreen" to fullScreen,
                    "brand" to brand,
                    "hasAutostart" to autostartBrands.contains(brand)
                ))
            }
            "askBattery" -> { askBattery(); result.success(null) }
            "openAutostart" -> { openAutostart(); result.success(null) }
            "openNotificationSettings" -> {
                val i = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                if (!tryStart(i)) tryStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                result.success(null)
            }
            "showOverLock" -> { setOverLock(call.arguments == true); result.success(null) }
            "openAppSettings" -> {
                tryStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                result.success(null)
            }
            "pickSound" -> pickSound(call.arguments as? String, result)
            "dismissShown" -> {
                val id = call.argument<Int>("id")
                val tag = call.argument<String>("tag")
                if (id != null) {
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    nm.cancel(tag, id)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/alarm").setMethodCallHandler { call, result ->
            alarmChannel(call, result)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/contacts").setMethodCallHandler { call, result ->
            contactsChannel(call, result)
        }
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
        if (requestCode == SOUND_REQUEST) {
            val r = soundResult ?: return
            soundResult = null
            @Suppress("DEPRECATION")
            val uri: Uri? = data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            if (resultCode != Activity.RESULT_OK || uri == null) {
                r.success(null)
                return
            }
            val title = try {
                RingtoneManager.getRingtone(this, uri)?.getTitle(this) ?: ""
            } catch (e: Exception) {
                ""
            }
            r.success(mapOf("uri" to uri.toString(), "title" to title))
            return
        }
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
        private const val SOUND_REQUEST = 4712
        private const val CONTACTS_REQUEST = 4713
    }
}
