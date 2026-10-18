package com.iamsaifsaiful.digital_brain

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Push from our server through Firebase Cloud Messaging ("প্রো চালু হয়েছে",
 * news). Firebase is set up from res/values/firebase.xml, written at build
 * time from google-services.json (tool/firebase_values.py); without it push
 * is simply off.
 */
class PushService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        // In the background Firebase shows "notification" messages itself;
        // in the foreground they arrive here.
        val n = message.notification ?: return
        show(this, n.title ?: "My Assistant", n.body ?: "", message.data["type"] ?: "")
    }

    override fun onNewToken(token: String) {
        // Dart sends it to the server the next time the app opens.
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("token", token).apply()
    }

    companion object {
        // Android never changes a channel after it is made: the vibrating
        // one has its own id; the old silent-vibration one is removed.
        const val CHANNEL = "ma_server_v3"
        const val OLD_CHANNEL = "ma_server"
        val OLDER = listOf("ma_server_vibrate")
        val VIBRATE = longArrayOf(0, 400, 250, 400)
        const val PREFS = "ma_push"

        fun channel(context: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = context.getSystemService(NotificationManager::class.java) ?: return
            for (id in OLDER + OLD_CHANNEL) if (nm.getNotificationChannel(id) != null) nm.deleteNotificationChannel(id)
            if (nm.getNotificationChannel(CHANNEL) != null) return
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "My Assistant থেকে", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "প্রো চালু হলে, আর মাঝে মাঝে অ্যাপের খবর"
                enableVibration(true)
                vibrationPattern = VIBRATE
            })
        }

        fun show(context: Context, title: String, body: String, type: String) {
            channel(context)
            val open = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("push", type)
            }
            val pi = PendingIntent.getActivity(context, title.hashCode(), open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val nb = NotificationCompat.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_reminder)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setVibrate(VIBRATE)
                .setDefaults(NotificationCompat.DEFAULT_SOUND)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pi)
            try {
                context.getSystemService(NotificationManager::class.java)?.notify(title.hashCode(), nb.build())
            } catch (_: SecurityException) {
                // Notifications are off for the app.
            }
        }

        /** "my_assistant/push": token → this phone's Firebase token, or null when push is off. */
        fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
            when (call.method) {
                "token" -> {
                    val ready = try {
                        FirebaseApp.getApps(context).isNotEmpty() || FirebaseApp.initializeApp(context) != null
                    } catch (_: Exception) {
                        false
                    }
                    if (!ready) {
                        result.success(null)
                        return
                    }
                    channel(context)
                    try {
                        FirebaseMessaging.getInstance().token
                            .addOnSuccessListener { result.success(it) }
                            .addOnFailureListener { result.success(null) }
                    } catch (_: Exception) {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
