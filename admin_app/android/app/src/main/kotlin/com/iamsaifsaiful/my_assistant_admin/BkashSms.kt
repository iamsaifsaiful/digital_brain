package com.iamsaifsaiful.my_assistant_admin

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Telephony
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

/**
 * বিকাশ মেলানো (owner, 27 Oct): on the phone with the payment SIM, bKash's
 * "You have received Tk …" messages are read here and only four things go
 * to our server — amount, TrxID, sender number and time. Never the message
 * itself, the balance, other messages or anything else on the phone. Only
 * messages whose sender is bKash count. Off until turned on in the app.
 */
object BkashSms {
    const val PREFS = "ma_bkash"

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isOn(c: Context) = prefs(c).getBoolean("on", false) && prefs(c).getString("key", "").orEmpty().isNotEmpty()

    fun setup(c: Context, key: String, base: String) {
        prefs(c).edit().putString("key", key).putString("base", base).putBoolean("on", true).apply()
    }

    fun off(c: Context) {
        prefs(c).edit().putBoolean("on", false).remove("key").apply()
    }

    fun status(c: Context): Map<String, Any?> = mapOf(
        "on" to isOn(c),
        "last" to prefs(c).getString("last", null),
        "queued" to JSONArray(prefs(c).getString("queue", "[]")).length(),
    )

    private val bnDigits = mapOf('০' to '0', '১' to '1', '২' to '2', '৩' to '3', '৪' to '4', '৫' to '5', '৬' to '6', '৭' to '7', '৮' to '8', '৯' to '9')

    private fun ascii(s: String) = buildString { for (ch in s) append(bnDigits[ch] ?: ch) }

    private fun phone(s: String): String {
        var d = s.filter { it.isDigit() }
        if (d.startsWith("880")) d = d.substring(2)
        return if (Regex("^01[3-9]\\d{8}$").matches(d)) d else ""
    }

    /** The same reading as the server's ma_bk_parse: received money only. */
    fun parse(raw: String): JSONObject? {
        val t = ascii(raw.trim())
        if (!Regex("(you have received|received payment|পেয়েছেন|গ্রহণ করেছেন)", RegexOption.IGNORE_CASE).containsMatchIn(t)) return null
        val trx = Regex("TrxID[:\\s#]*([A-Z0-9]{8,12})\\b", RegexOption.IGNORE_CASE).find(t)?.groupValues?.get(1)?.uppercase() ?: return null
        val amountText = Regex("Tk\\.?\\s*([\\d,]+(?:\\.\\d{1,2})?)", RegexOption.IGNORE_CASE).find(t)?.groupValues?.get(1)
            ?: Regex("([\\d,]+(?:\\.\\d{1,2})?)\\s*টাকা").find(t)?.groupValues?.get(1)
            ?: Regex("৳\\s*([\\d,]+(?:\\.\\d{1,2})?)").find(t)?.groupValues?.get(1)
            ?: return null
        val amount = amountText.replace(",", "").toDoubleOrNull()?.toInt() ?: return null
        if (amount <= 0) return null
        val from = Regex("from\\s+(\\+?[\\d\\-\\s]{11,16})", RegexOption.IGNORE_CASE).find(t)?.groupValues?.get(1)
            ?: Regex("(\\+?[\\d\\-]{11,16})\\s*(?:নম্বর\\s*)?থেকে").find(t)?.groupValues?.get(1)
        var at = ""
        Regex("(\\d{1,2})/(\\d{1,2})/(\\d{4})\\s+(\\d{1,2}):(\\d{2})").find(t)?.let { m ->
            val (d, mo, y, h, mi) = m.destructured
            try {
                val f = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US).apply { timeZone = TimeZone.getTimeZone("Asia/Dhaka") }
                val date = f.parse("%04d-%02d-%02d %02d:%02d".format(y.toInt(), mo.toInt(), d.toInt(), h.toInt(), mi.toInt()))
                if (date != null) at = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }.format(date)
            } catch (_: Exception) {
            }
        }
        return JSONObject().put("trx", trx).put("amount", amount).put("sender", if (from != null) phone(from) else "").put("at", at)
    }

    /** bKash's own sender name (alphanumeric "bKash"), not a number someone could text from. */
    fun fromBkash(address: String?) = address != null && address.trim().equals("bKash", ignoreCase = true)

    /** Sends what is waiting plus [items]; what fails waits for the next time. */
    fun send(c: Context, items: List<JSONObject>) {
        val p = prefs(c)
        val queue = JSONArray(p.getString("queue", "[]"))
        for (it in items) queue.put(it)
        if (queue.length() == 0 || !isOn(c)) return
        val ok = post(p.getString("base", "").orEmpty(), p.getString("key", "").orEmpty(), queue)
        val e = p.edit()
        if (ok) {
            e.putString("queue", "[]").putString("last", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }.format(java.util.Date()))
        } else {
            // Keep at most the newest 50.
            val keep = JSONArray()
            for (i in maxOf(0, queue.length() - 50) until queue.length()) keep.put(queue.get(i))
            e.putString("queue", keep.toString())
        }
        e.apply()
    }

    private fun post(base: String, key: String, items: JSONArray): Boolean {
        if (base.isEmpty() || key.isEmpty()) return false
        return try {
            val con = URL("$base/wp-json/my-assistant/v1/bkash/sms").openConnection() as HttpURLConnection
            con.requestMethod = "POST"
            con.connectTimeout = 15000
            con.readTimeout = 20000
            con.doOutput = true
            con.setRequestProperty("content-type", "application/json")
            con.setRequestProperty("x-ma-bkash-key", key)
            con.outputStream.use { it.write(JSONObject().put("items", items).toString().toByteArray()) }
            val code = con.responseCode
            con.disconnect()
            code == 200
        } catch (_: Exception) {
            false
        }
    }

    /** bKash payments received in the last [days] days, from the phone's inbox (needs READ_SMS). */
    fun scan(c: Context, days: Int): List<JSONObject> {
        val out = mutableListOf<JSONObject>()
        val since = System.currentTimeMillis() - days * 86_400_000L
        try {
            c.contentResolver.query(Uri.parse("content://sms/inbox"), arrayOf("address", "body", "date"), "date >= ?", arrayOf(since.toString()), "date DESC")?.use { cur ->
                while (cur.moveToNext()) {
                    if (!fromBkash(cur.getString(0))) continue
                    parse(cur.getString(1) ?: "")?.let { out.add(it) }
                }
            }
        } catch (_: SecurityException) {
        }
        return out
    }
}

/** A new SMS: if it is bKash's and the matching is on, the four fields go to our server. */
class BkashSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION || !BkashSms.isOn(context)) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val bodies = mutableMapOf<String, StringBuilder>()
        for (m in parts) {
            val from = m.originatingAddress ?: continue
            if (!BkashSms.fromBkash(from)) continue
            bodies.getOrPut(from) { StringBuilder() }.append(m.messageBody ?: "")
        }
        val items = bodies.values.mapNotNull { BkashSms.parse(it.toString()) }
        if (items.isEmpty()) return
        val pending = goAsync()
        Thread {
            try {
                BkashSms.send(context.applicationContext, items)
            } finally {
                pending.finish()
            }
        }.start()
    }
}
