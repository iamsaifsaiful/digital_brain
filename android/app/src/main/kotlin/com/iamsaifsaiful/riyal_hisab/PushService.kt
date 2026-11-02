package com.iamsaifsaiful.riyal_hisab

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Notifications from the shop's server through Firebase Cloud Messaging:
 * new requests for an agent, "agent sent it" for the admins. Firebase's
 * settings are not built into the APK; the server gives them at sign-in
 * and they are kept here for the next start.
 */
class PushService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        // In the background Android shows "notification" messages itself;
        // with the app open they arrive here.
        val n = message.notification ?: return
        show(this, n.title ?: "রিয়াল-বিকাশ হিসাব", n.body ?: "")
    }

    override fun onNewToken(token: String) {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("token", token).apply()
    }

    companion object {
        const val CHANNEL = "rh_server"
        const val PREFS = "rh_push"

        private fun options(p: Map<String, String>): FirebaseOptions? {
            val appId = p["appId"].orEmpty()
            val apiKey = p["apiKey"].orEmpty()
            if (appId.isEmpty() || apiKey.isEmpty()) return null
            return FirebaseOptions.Builder()
                .setApplicationId(appId)
                .setApiKey(apiKey)
                .setGcmSenderId(p["senderId"].orEmpty())
                .setProjectId(p["projectId"].orEmpty())
                .build()
        }

        private fun init(context: Context, p: Map<String, String>): Boolean {
            return try {
                if (FirebaseApp.getApps(context).isNotEmpty()) return true
                val o = options(p) ?: return false
                FirebaseApp.initializeApp(context, o)
                true
            } catch (_: Exception) {
                false
            }
        }

        fun startSaved(context: Context) {
            val sp = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val p = mapOf(
                "appId" to sp.getString("appId", "").orEmpty(),
                "apiKey" to sp.getString("apiKey", "").orEmpty(),
                "senderId" to sp.getString("senderId", "").orEmpty(),
                "projectId" to sp.getString("projectId", "").orEmpty(),
            )
            init(context, p)
        }

        fun channel(context: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = context.getSystemService(NotificationManager::class.java) ?: return
            if (nm.getNotificationChannel(CHANNEL) != null) return
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "লেনদেনের খবর", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "নতুন অনুরোধ, এজেন্ট পাঠালেন, টাকা দেওয়া"
            })
        }

        fun show(context: Context, title: String, body: String) {
            channel(context)
            val open = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pi = PendingIntent.getActivity(context, title.hashCode(), open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val nb = NotificationCompat.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_reminder)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pi)
            try {
                context.getSystemService(NotificationManager::class.java)?.notify((System.currentTimeMillis() % 100000).toInt(), nb.build())
            } catch (_: SecurityException) {
                // Notifications are off for the app.
            }
        }

        /** "riyal/push": start(options) → this phone's token, or null when push is off. */
        fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
            when (call.method) {
                "start" -> {
                    @Suppress("UNCHECKED_CAST")
                    val p = (call.arguments as? Map<String, String>).orEmpty()
                    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
                        for ((k, v) in p) putString(k, v)
                    }.apply()
                    if (!init(context, p)) {
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
