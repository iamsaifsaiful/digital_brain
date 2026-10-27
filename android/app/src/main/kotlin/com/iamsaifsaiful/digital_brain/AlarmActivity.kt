package com.iamsaifsaiful.digital_brain

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * A ringing reminder's full-screen page, on its own (owner, 27 Oct: "ফুল
 * স্কিনে বাজবে, এপ ওপেন হওয়া উচিত না"). It never starts the app: it shows
 * only the reminder's title and time (nothing private), over the lock
 * screen, with the same buttons the Flutter page had. "পরে মনে করাও" goes
 * to the notifications plugin's own background handler (it sets the next
 * ring); "আর বাজাবে না" for a repeating reminder needs the app's data, so
 * only that one opens the app.
 */
class AlarmActivity : Activity() {
    companion object {
        private const val RECEIVER = "com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver"
        private const val TAPPED = "com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver.ACTION_TAPPED"

        /** The reminder (not an assistant note) a notification intent is for, or null. */
        fun reminderOf(i: Intent?): JSONObject? {
            if (i?.action != "SELECT_NOTIFICATION") return null
            val p = i.getStringExtra("payload") ?: return null
            val j = try { JSONObject(p) } catch (_: Exception) { return null }
            val r = j.optString("r")
            if (r.isEmpty() || r.startsWith("brief:") || r.startsWith("nudge:") || r.startsWith("quick:") || r == "emergency") return null
            return j
        }

        fun from(c: Context, i: Intent): Intent = Intent(c, AlarmActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra("payload", i.getStringExtra("payload"))
            .putExtra("notificationId", i.getIntExtra("notificationId", 0))
    }

    private val main = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var id = 0
    private var payload = ""
    private var closing = false

    private fun dp(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        show(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Another reminder rang while this one was up: the new one is shown.
        stopBackup()
        show(intent)
    }

    private fun show(i: Intent) {
        closing = false
        id = i.getIntExtra("notificationId", 0)
        payload = i.getStringExtra("payload") ?: ""
        val j = try { JSONObject(payload) } catch (_: Exception) { JSONObject() }
        val title = j.optString("t").replaceFirst("আগাম মনে করানো: ", "").trim().ifEmpty { "রিমাইন্ডার" }
        val bodyText = j.optString("b").trim()
        val repeating = j.optBoolean("x")

        val green = Color.parseColor("#0B3D32")
        window.statusBarColor = green
        window.navigationBarColor = green
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(green)
            setPadding(dp(24f), dp(72f), dp(24f), dp(28f))
        }
        fun text(s: String, size: Float, color: Int, bold: Boolean = false) = TextView(this).apply {
            text = s
            setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
            setTextColor(color)
            gravity = Gravity.CENTER
            if (bold) typeface = Typeface.DEFAULT_BOLD
        }
        val time = SimpleDateFormat("h:mm", Locale.US).format(Date()).map { if (it.isDigit()) '০' + (it - '0') else it }.joinToString("")
        root.addView(text("রিমাইন্ডার · $time", 16f, Color.parseColor("#7FE0C2")))
        root.addView(View(this), LinearLayout.LayoutParams(1, dp(8f)))
        root.addView(text(title, 30f, Color.WHITE, bold = true))
        if (bodyText.isNotEmpty() && bodyText != title) {
            root.addView(View(this), LinearLayout.LayoutParams(1, dp(8f)))
            root.addView(text(bodyText, 16f, Color.parseColor("#CDE7DE")))
        }
        root.addView(View(this), LinearLayout.LayoutParams(1, 0, 1f))

        fun button(label: String, primary: Boolean, onTap: () -> Unit): Button = Button(this).apply {
            text = label
            isAllCaps = false
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (primary) 18f else 15f)
            setTextColor(if (primary) green else Color.WHITE)
            background = GradientDrawable().apply {
                cornerRadius = dp(16f).toFloat()
                setColor(if (primary) Color.WHITE else Color.parseColor("#10493C"))
                if (!primary) setStroke(dp(1f), Color.parseColor("#2E6F5E"))
            }
            setOnClickListener { onTap() }
        }
        fun full(b: View, h: Float) = root.addView(b, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(h)).apply { topMargin = dp(12f) })

        if (repeating) {
            full(button("ঠিক আছে", false) { close() }, 50f)
            full(button("আর বাজাবে না", true) { stopForGood() }, 58f)
        } else {
            root.addView(text("পরে মনে করাও", 14f, Color.parseColor("#CDE7DE")))
            val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
            for ((n, label) in listOf(5 to "৫ মিনিট", 10 to "১০ মিনিট", 60 to "১ ঘণ্টা")) {
                row.addView(button(label, false) { snooze(n) }, LinearLayout.LayoutParams(0, dp(50f), 1f).apply {
                    if (n != 5) leftMargin = dp(10f)
                })
            }
            root.addView(row, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(50f)).apply { topMargin = dp(10f) })
            full(button("হয়ে গেছে, বন্ধ করো", true) { close() }, 58f)
        }
        setContentView(root)

        // Rings even with the phone on silent (as the old page did): when the
        // notification is still up but nothing sounds on the alarm volume.
        main.postDelayed(startBackup, 1500)
        main.postDelayed(watch, 2000)
    }

    /** The notification was taken away elsewhere (swiped, stopped from the panel): this page goes too. */
    private val watch = object : Runnable {
        override fun run() {
            if (closing) return
            if (!stillShown()) { close(); return }
            main.postDelayed(this, 2000)
        }
    }

    private fun stillShown(): Boolean {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.activeNotifications.any { it.id == id }
    }

    private val startBackup = Runnable {
        if (player != null || closing || !stillShown() || alarmSounding()) return@Runnable
        val sound = try { JSONObject(payload).optString("s") } catch (_: Exception) { "" }
        try {
            val mp = MediaPlayer()
            mp.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            mp.setDataSource(this, Uri.parse(sound.ifEmpty { "content://settings/system/alarm_alert" }))
            mp.isLooping = true
            mp.prepare()
            mp.start()
            player = mp
            main.postDelayed({ stopBackup() }, 5 * 60 * 1000L)
        } catch (_: Exception) {
            stopBackup()
        }
    }

    private fun alarmSounding(): Boolean {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= 26) return am.activePlaybackConfigurations.any { it.audioAttributes.usage == AudioAttributes.USAGE_ALARM }
        return am.ringerMode == AudioManager.RINGER_MODE_NORMAL
    }

    private fun stopBackup() {
        main.removeCallbacks(startBackup)
        try { player?.stop() } catch (_: Exception) {}
        player?.release()
        player = null
    }

    /** Takes the ringing notification away (its sound stops with it). */
    private fun cancelShown() {
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
    }

    private fun close() {
        if (closing) return
        closing = true
        main.removeCallbacks(watch)
        stopBackup()
        cancelShown()
        finishAndRemoveTask()
    }

    /** "পরে মনে করাও": the plugin's background handler sets the next ring (lib/services/notifications.dart). */
    private fun snooze(minutes: Int) {
        sendBroadcast(Intent(TAPPED).setClassName(packageName, RECEIVER)
            .putExtra("notificationId", id)
            .putExtra("actionId", if (minutes == 10) "snooze" else "snooze:$minutes")
            .putExtra("cancelNotification", true)
            .putExtra("payload", payload))
        close()
    }

    /** "আর বাজাবে না": the app turns the reminder off (it needs the app's own data). */
    private fun stopForGood() {
        val open = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            action = "SELECT_FOREGROUND_NOTIFICATION_ACTION"
            putExtra("notificationId", id)
            putExtra("actionId", "stop")
            putExtra("payload", payload)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        close()
        if (open != null) startActivity(open)
    }

    @Deprecated("Back closes it, like the old page")
    override fun onBackPressed() {
        close()
    }

    override fun onDestroy() {
        main.removeCallbacksAndMessages(null)
        stopBackup()
        super.onDestroy()
    }
}
