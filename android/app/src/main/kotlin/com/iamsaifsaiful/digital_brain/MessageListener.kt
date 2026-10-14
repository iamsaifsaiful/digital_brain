package com.iamsaifsaiful.digital_brain

import android.app.Notification
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Reads new-message notifications from the apps the user picked (WhatsApp,
 * Telegram, imo, Gmail, SMS…) so the assistant can list what needs doing.
 *
 * Everything stays on the phone: messages wait in a small private file until
 * the app opens and moves them into its encrypted data. Messages with an
 * OTP, PIN or password are never kept. Nothing is read until the user turns
 * on notification access and chooses the apps.
 */
class MessageListener : NotificationListenerService() {
    companion object {
        const val PREFS = "inbox"
        const val QUEUE = "inbox_queue.jsonl"

        /** Default apps (the user can switch each off). */
        val KNOWN = linkedMapOf(
            "com.whatsapp" to "WhatsApp",
            "com.whatsapp.w4b" to "WhatsApp Business",
            "org.telegram.messenger" to "Telegram",
            "org.thunderdog.challegram" to "Telegram X",
            "com.imo.android.imoim" to "imo",
            "com.imo.android.imoimbeta" to "imo",
            "com.imo.android.imoimhd" to "imo HD",
            "com.imo.android.imous" to "imo Lite",
            "com.facebook.orca" to "Messenger",
            "com.facebook.mlite" to "Messenger Lite",
            "com.google.android.gm" to "Gmail",
            "com.microsoft.office.outlook" to "Outlook",
            "com.yahoo.mobile.client.android.mail" to "Yahoo Mail",
            "com.samsung.android.email.provider" to "Email",
            "com.google.android.apps.messaging" to "SMS",
            "com.samsung.android.messaging" to "SMS",
            "com.android.mms" to "SMS",
            "com.viber.voip" to "Viber",
            "org.thoughtcrime.securesms" to "Signal",
            "com.skype.raider" to "Skype",
            "com.linkedin.android" to "LinkedIn",
        )

        /** Reply buttons of messages still on the phone (notification key → action). */
        val replies = LinkedHashMap<String, Notification.Action>()

        private val secret = Regex("(?i)(otp|one[ -]?time|verification|verify|passcode|password|pin\\b|code|কোড|ওটিপি|পিন|পাসওয়ার্ড|গোপন)")
        private val digits = Regex("\\b[0-9০-৯]{4,8}\\b")
        private val summary = Regex("(?i)^(\\d+|[০-৯]+)\\s*(new messages?|messages? from|টি নতুন|নতুন বার্তা|unread)|checking for new messages|backup|ব্যাকআপ|is typing|typing…|লিখছে")

        fun hasAccess(c: Context): Boolean {
            val on = Settings.Secure.getString(c.contentResolver, "enabled_notification_listeners") ?: return false
            return on.contains(ComponentName(c, MessageListener::class.java).flattenToString()) || on.contains(c.packageName)
        }

        fun enabledApps(c: Context): Set<String> {
            val p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return p.getStringSet("apps", null) ?: KNOWN.keys
        }

        fun isOn(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("on", true)

        /** Waiting messages, removed from the file. */
        @Synchronized
        fun take(c: Context): List<Map<String, Any>> {
            val f = File(c.filesDir, QUEUE)
            if (!f.exists()) return emptyList()
            val out = ArrayList<Map<String, Any>>()
            f.readLines().forEach { line ->
                try {
                    val o = JSONObject(line)
                    out.add(mapOf(
                        "id" to o.optString("id"), "app" to o.optString("app"), "appName" to o.optString("appName"),
                        "chat" to o.optString("chat"), "from" to o.optString("from"), "text" to o.optString("text"),
                        "at" to o.optLong("at"), "key" to o.optString("key"), "group" to o.optBoolean("group"),
                    ))
                } catch (_: Exception) {}
            }
            f.delete()
            return out
        }

        @Synchronized
        private fun append(c: Context, o: JSONObject) {
            val f = File(c.filesDir, QUEUE)
            // Never let the waiting file grow without end (the app was not opened for long).
            if (f.exists() && f.length() > 512 * 1024) {
                val keep = f.readLines().takeLast(300)
                f.writeText(keep.joinToString("\n", postfix = "\n"))
            }
            f.appendText(o.toString() + "\n")
        }

        /** Sends [text] with a message's own reply button. */
        fun reply(c: Context, key: String, text: String): Boolean {
            val a = synchronized(replies) { replies[key] } ?: return false
            val inputs = a.remoteInputs ?: return false
            return try {
                val intent = Intent()
                val bundle = Bundle()
                for (r in inputs) bundle.putCharSequence(r.resultKey, text)
                RemoteInput.addResultsToIntent(inputs, intent, bundle)
                a.actionIntent.send(c, 0, intent)
                true
            } catch (e: PendingIntent.CanceledException) {
                false
            }
        }
    }

    private val seen = LinkedHashSet<String>()

    @Suppress("DEPRECATION")
    private fun senderName(b: Bundle): String? =
        if (Build.VERSION.SDK_INT >= 28) (b.getParcelable<android.app.Person>("sender_person"))?.name?.toString() else null

    override fun onListenerConnected() {
        super.onListenerConnected()
        // Messages already waiting in the notification shade.
        try {
            activeNotifications?.forEach { handle(it) }
        } catch (_: Exception) {}
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            handle(sbn)
        } catch (_: Exception) {}
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        synchronized(replies) { replies.remove(sbn.key) }
    }

    private fun handle(sbn: StatusBarNotification) {
        val pkg = sbn.packageName ?: return
        if (pkg == packageName || !isOn(this) || pkg !in enabledApps(this)) return
        val n = sbn.notification ?: return
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        if (n.flags and Notification.FLAG_ONGOING_EVENT != 0) return
        val ex = n.extras ?: return
        val appName = KNOWN[pkg] ?: pkg
        val title = ex.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        val conv = ex.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString()?.trim()
        val group = ex.getBoolean(Notification.EXTRA_IS_GROUP_CONVERSATION, false) || (conv != null && conv.isNotEmpty())

        // Keep the reply button while the message is on the phone.
        n.actions?.firstOrNull { it.remoteInputs != null && it.remoteInputs.isNotEmpty() }?.let { a ->
            synchronized(replies) {
                replies[sbn.key] = a
                while (replies.size > 200) replies.remove(replies.keys.first())
            }
        }

        val items = ArrayList<Triple<String, String, Long>>() // from, text, time
        @Suppress("DEPRECATION")
        val msgs = ex.getParcelableArray(Notification.EXTRA_MESSAGES)
        if (msgs != null && msgs.isNotEmpty()) {
            for (m in msgs) {
                val b = m as? Bundle ?: continue
                val text = b.getCharSequence("text")?.toString() ?: continue
                var from = b.getCharSequence("sender")?.toString()
                if (from == null && Build.VERSION.SDK_INT >= 28) from = senderName(b)
                items.add(Triple(from ?: title, text, b.getLong("time", sbn.postTime)))
            }
        } else {
            val text = (ex.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: ex.getCharSequence(Notification.EXTRA_TEXT))?.toString() ?: return
            items.add(Triple(title, text, sbn.postTime))
        }

        for ((from, text, at) in items.takeLast(8)) {
            val t = text.trim()
            if (t.isEmpty() || summary.containsMatchIn(t) || summary.containsMatchIn(title)) continue
            // Never keep one-time codes, PINs or passwords.
            if (secret.containsMatchIn(t) && digits.containsMatchIn(t)) continue
            val chat = conv ?: title
            val id = "$pkg|$chat|$from|$at|$t".hashCode().toString()
            if (!seen.add(id)) continue
            while (seen.size > 2000) seen.remove(seen.first())
            append(this, JSONObject().apply {
                put("id", id); put("app", pkg); put("appName", appName); put("chat", chat); put("from", from)
                put("text", t.take(2000)); put("at", at); put("key", sbn.key); put("group", group)
            })
        }
    }
}
