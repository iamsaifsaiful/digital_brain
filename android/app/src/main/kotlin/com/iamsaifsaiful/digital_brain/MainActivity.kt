package com.iamsaifsaiful.digital_brain

import android.app.Activity
import android.Manifest
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.Ringtone
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
import android.provider.OpenableColumns
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity is needed by local_auth (fingerprint dialog).
 * FLAG_SECURE keeps passwords out of screenshots, screen recordings and the
 * recent-apps preview. Only the test app (".preview", installed beside the
 * real one for testing) allows screenshots, so problems can be shown; the
 * real app and the Play Store app always block them.
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
    private var preview: Ringtone? = null
    private val stopPreview = Runnable { preview?.stop() }
    private var launchChannel: MethodChannel? = null
    private val google by lazy { GoogleAuth(this) }

    /** How the app was opened (a share, the assistant gesture, the widget mic), until Dart asks. */
    private var firstLaunch: Map<String, Any>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        if (!packageName.endsWith(".preview")) {
            window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        }
        super.onCreate(savedInstanceState)
        if (isReminderIntent(intent)) setOverLock(true)
        if (savedInstanceState == null) firstLaunch = launchOf(intent)
    }

    override fun onNewIntent(intent: Intent) {
        if (isReminderIntent(intent)) setOverLock(true)
        super.onNewIntent(intent)
        val l = launchOf(intent)
        if (l != null) launchChannel?.invokeMethod("launch", l)
    }

    /** A share, the phone's assist gesture or the widget mic, as a map for Dart (null for a plain start). */
    private fun launchOf(i: Intent?): Map<String, Any>? {
        if (i == null) return null
        return when (i.action) {
            Intent.ACTION_ASSIST, "android.intent.action.VOICE_COMMAND" -> mapOf("action" to "assist")
            TodayWidget.VOICE -> mapOf("action" to "voice")
            Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE -> {
                val text = (i.getStringExtra(Intent.EXTRA_TEXT) ?: "") +
                    (i.getStringExtra(Intent.EXTRA_SUBJECT)?.let { if (it.isNotBlank() && i.getStringExtra(Intent.EXTRA_TEXT) == null) it else "" } ?: "")
                val uris = ArrayList<Uri>()
                @Suppress("DEPRECATION")
                if (i.action == Intent.ACTION_SEND) {
                    (i.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))?.let { uris.add(it) }
                } else {
                    i.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.addAll(it) }
                }
                val files = ArrayList<Map<String, Any>>()
                for (u in uris.take(10)) readShared(u)?.let { files.add(it) }
                mapOf("action" to "share", "text" to text, "files" to files)
            }
            else -> {
                // A tap on a notification from our server: "push" (shown by the app)
                // or "type" (shown by Firebase while the app was closed).
                val type = i.getStringExtra("push") ?: i.getStringExtra("type")
                if (type == "blood" || type == "feedback") {
                    i.removeExtra("push")
                    i.removeExtra("type")
                    mapOf("action" to "push:$type")
                } else null
            }
        }
    }

    /** A shared file's bytes, name and type (up to 25 MB). */
    private fun readShared(u: Uri): Map<String, Any>? = try {
        var name = "file"
        var size = -1L
        contentResolver.query(u, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                name = c.getString(0) ?: name
                if (!c.isNull(1)) size = c.getLong(1)
            }
        }
        if (size > 25L * 1024 * 1024) {
            null
        } else {
            val bytes = contentResolver.openInputStream(u)?.use { it.readBytes() }
            if (bytes == null || bytes.size > 25 * 1024 * 1024) null
            else mapOf("name" to name, "mime" to (contentResolver.getType(u) ?: "application/octet-stream"), "bytes" to bytes)
        }
    } catch (e: Exception) {
        null
    }

    private fun launchMethods(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "unmetered" -> {
                // The on-phone model (~14 MB) is downloaded only off mobile data.
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? android.net.ConnectivityManager
                result.success(try { cm != null && cm.activeNetwork != null && !cm.isActiveNetworkMetered } catch (e: Exception) { false })
            }
            "initial" -> {
                result.success(firstLaunch)
                firstLaunch = null
            }
            "assistSettings" -> {
                if (!tryStart(Intent(Settings.ACTION_VOICE_INPUT_SETTINGS)) &&
                    !tryStart(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))) {
                    tryStart(Intent(Settings.ACTION_SETTINGS))
                }
                result.success(null)
            }
            "widget" -> {
                val args = call.arguments as? Map<*, *>
                val e = getSharedPreferences(TodayWidget.PREFS, Context.MODE_PRIVATE).edit()
                args?.forEach { (k, v) -> e.putString(k.toString(), v?.toString() ?: "") }
                e.apply()
                TodayWidget.refresh(this)
                result.success(null)
            }
            else -> result.notImplemented()
        }
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

    /** The phone's alarm tones, ringtones and notification sounds, for the app's own picker. */
    private fun listSounds(result: MethodChannel.Result) {
        Thread {
            val out = ArrayList<Map<String, String>>()
            for ((type, kind) in listOf(RingtoneManager.TYPE_ALARM to "alarm", RingtoneManager.TYPE_RINGTONE to "ringtone", RingtoneManager.TYPE_NOTIFICATION to "notification")) {
                try {
                    val m = RingtoneManager(this)
                    m.setType(type)
                    val c = m.cursor
                    while (c.moveToNext()) {
                        val title = c.getString(RingtoneManager.TITLE_COLUMN_INDEX) ?: continue
                        val uri = m.getRingtoneUri(c.position) ?: continue
                        out.add(mapOf("uri" to uri.toString(), "title" to title, "kind" to kind))
                    }
                } catch (e: Exception) {
                }
            }
            runOnUiThread { result.success(out) }
        }.start()
    }

    /** Plays a sound for 8 seconds on the alarm volume, as a reminder would. */
    private fun playSound(uri: String?) {
        window.decorView.removeCallbacks(stopPreview)
        preview?.stop()
        if (uri == null) return
        try {
            val r = RingtoneManager.getRingtone(this, Uri.parse(uri)) ?: return
            r.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            r.play()
            preview = r
            window.decorView.postDelayed(stopPreview, 8000)
        } catch (e: Exception) {
        }
    }

    override fun onPause() {
        window.decorView.removeCallbacks(stopPreview)
        preview?.stop()
        super.onPause()
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

    /** ফ্যামিলি › লোকেশন: permissions, the sharing settings, and sending where the phone is now. */
    private fun locationChannel(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(LocationShare.status(this))
            "ask" -> {
                requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), LOCATION_REQUEST)
                result.success(null)
            }
            // "Allow all the time": Android 11+ only offers it on the app's settings page.
            "askBackground" -> {
                if (Build.VERSION.SDK_INT == 29) {
                    requestPermissions(arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), LOCATION_REQUEST)
                } else if (Build.VERSION.SDK_INT >= 30) {
                    tryStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                }
                result.success(null)
            }
            "configure" -> {
                LocationShare.configure(this, call.argument<Boolean>("on") == true, call.argument<String>("key"), call.argument<String>("session"), call.argument<String>("base"))
                result.success(null)
            }
            "report" -> Thread {
                val ok = LocationShare.answer(applicationContext)
                runOnUiThread { result.success(ok) }
            }.start()
            else -> result.notImplemented()
        }
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
            "listSounds" -> listSounds(result)
            "playSound" -> {
                playSound(call.arguments as? String)
                result.success(null)
            }
            "stopSound" -> {
                window.decorView.removeCallbacks(stopPreview)
                preview?.stop()
                result.success(null)
            }
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

    /** Messages from other apps (see [MessageListener]). */
    private fun inboxChannel(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "access" -> result.success(MessageListener.hasAccess(this))
            // Declared in the manifest? (Not in builds shared as an APK — Play Protect blocks those.)
            "supported" -> result.success(try {
                packageManager.getServiceInfo(ComponentName(this, MessageListener::class.java), 0)
                true
            } catch (e: Exception) {
                false
            })
            "openAccess" -> {
                val i = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                if (Build.VERSION.SDK_INT >= 30) {
                    val d = Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                        .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, ComponentName(this, MessageListener::class.java).flattenToString())
                    if (!tryStart(d)) tryStart(i)
                } else {
                    tryStart(i)
                }
                result.success(null)
            }
            "appInfo" -> {
                tryStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                result.success(null)
            }
            "take" -> result.success(MessageListener.take(this))
            "reply" -> {
                val key = call.argument<String>("key") ?: ""
                val text = call.argument<String>("text") ?: ""
                result.success(text.isNotBlank() && MessageListener.reply(this, key, text))
            }
            "canReply" -> {
                val key = call.argument<String>("key") ?: ""
                result.success(synchronized(MessageListener.replies) { MessageListener.replies.containsKey(key) })
            }
            "setApps" -> {
                val apps = call.argument<List<String>>("apps") ?: emptyList()
                val on = call.argument<Boolean>("on") ?: true
                getSharedPreferences(MessageListener.PREFS, Context.MODE_PRIVATE).edit()
                    .putStringSet("apps", apps.toSet()).putBoolean("on", on).apply()
                result.success(null)
            }
            "known" -> result.success(MessageListener.KNOWN.map { mapOf("id" to it.key, "name" to it.value) })
            "openApp" -> {
                val pkg = call.argument<String>("app") ?: ""
                val i = packageManager.getLaunchIntentForPackage(pkg)
                result.success(i != null && tryStart(i))
            }
            else -> result.notImplemented()
        }
    }

    // ── Looking at a kept PDF inside the app, or in another app ──

    private class OpenPdf(val file: java.io.File, val fd: android.os.ParcelFileDescriptor, val renderer: android.graphics.pdf.PdfRenderer)

    private val pdfs = HashMap<Int, OpenPdf>()
    private var nextPdf = 1
    private val pdfWorker = java.util.concurrent.Executors.newSingleThreadExecutor()

    private fun fileViewChannel(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pdfOpen" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null) {
                    result.success(null)
                    return
                }
                pdfWorker.execute {
                    try {
                        val dir = java.io.File(cacheDir, "view").apply { mkdirs() }
                        val f = java.io.File(dir, "doc_${System.nanoTime()}.pdf")
                        f.writeBytes(bytes)
                        val fd = android.os.ParcelFileDescriptor.open(f, android.os.ParcelFileDescriptor.MODE_READ_ONLY)
                        val r = android.graphics.pdf.PdfRenderer(fd)
                        val id = synchronized(pdfs) { nextPdf++.also { pdfs[it] = OpenPdf(f, fd, r) } }
                        runOnUiThread { result.success(mapOf("id" to id, "pages" to r.pageCount)) }
                    } catch (e: Exception) {
                        runOnUiThread { result.success(null) }
                    }
                }
            }
            "pdfPage" -> {
                val id = call.argument<Int>("id") ?: 0
                val index = call.argument<Int>("index") ?: 0
                val width = (call.argument<Int>("width") ?: 1080).coerceIn(200, 2400)
                pdfWorker.execute {
                    val png = try {
                        val doc = synchronized(pdfs) { pdfs[id] }
                        if (doc == null) {
                            null
                        } else {
                            val page = doc.renderer.openPage(index)
                            try {
                                val h = (width.toFloat() * page.height / page.width).toInt().coerceAtLeast(1)
                                val bmp = android.graphics.Bitmap.createBitmap(width, h, android.graphics.Bitmap.Config.ARGB_8888)
                                bmp.eraseColor(android.graphics.Color.WHITE)
                                page.render(bmp, null, null, android.graphics.pdf.PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                val out = java.io.ByteArrayOutputStream()
                                bmp.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out)
                                bmp.recycle()
                                out.toByteArray()
                            } finally {
                                page.close()
                            }
                        }
                    } catch (e: Exception) {
                        null
                    }
                    runOnUiThread { result.success(png) }
                }
            }
            "pdfMake" -> {
                val spec = call.argument<Map<*, *>>("spec")
                if (spec == null) {
                    result.success(null)
                    return
                }
                pdfWorker.execute {
                    val bytes = try {
                        PdfMaker(applicationContext).make(spec)
                    } catch (e: Exception) {
                        null
                    }
                    runOnUiThread { result.success(bytes) }
                }
            }
            "pdfClose" -> {
                val id = call.argument<Int>("id") ?: 0
                pdfWorker.execute {
                    val doc = synchronized(pdfs) { pdfs.remove(id) }
                    try {
                        doc?.renderer?.close()
                        doc?.fd?.close()
                    } catch (_: Exception) {}
                    doc?.file?.delete()
                }
                result.success(null)
            }
            "openWith" -> {
                // A copy in the app's cache, offered to the phone's PDF/Word/… apps.
                val bytes = call.argument<ByteArray>("bytes")
                val name = (call.argument<String>("name") ?: "file").replace(Regex("[\\\\/:*?\"<>|]"), "_")
                val mime = call.argument<String>("mime") ?: "application/octet-stream"
                if (bytes == null) {
                    result.success(false)
                    return
                }
                try {
                    val dir = java.io.File(cacheDir, "open").apply { mkdirs() }
                    dir.listFiles()?.forEach { it.delete() }
                    val f = java.io.File(dir, name)
                    f.writeBytes(bytes)
                    val uri = androidx.core.content.FileProvider.getUriForFile(this, "$packageName.files", f)
                    val view = Intent(Intent.ACTION_VIEW).setDataAndType(uri, mime).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    startActivity(Intent.createChooser(view, null).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        io.flutter.plugin.common.EventChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/compass").setStreamHandler(Compass(this))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/ocr").setMethodCallHandler { call, result -> TextReader.handle(call, result, cacheDir) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/alarm").setMethodCallHandler { call, result ->
            alarmChannel(call, result)
        }
        launchChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/launch").also {
            it.setMethodCallHandler { call, result -> launchMethods(call, result) }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/inbox").setMethodCallHandler { call, result ->
            inboxChannel(call, result)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/location").setMethodCallHandler { call, result ->
            locationChannel(call, result)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/push").setMethodCallHandler { call, result ->
            PushService.handle(this, call, result)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/google").setMethodCallHandler { call, result ->
            google.handle(call, result)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/contacts").setMethodCallHandler { call, result ->
            contactsChannel(call, result)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my_assistant/files").setMethodCallHandler { call, result ->
            if (call.method != "saveFile") {
                fileViewChannel(call, result)
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
                type = call.argument<String>("mime") ?: "application/octet-stream"
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
        if (google.onActivityResult(requestCode, data)) return
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
        private const val LOCATION_REQUEST = 4721
    }
}
