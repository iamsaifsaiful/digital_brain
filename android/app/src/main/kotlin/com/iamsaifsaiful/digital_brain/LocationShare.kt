package com.iamsaifsaiful.digital_brain

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.BatteryManager
import android.os.Build
import android.util.Base64
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.tasks.Tasks
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.SecureRandom
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * ফ্যামিলি › লোকেশন: when a family member the user allowed asks "এখন কোথায়?",
 * our server sends a silent push and this answers by itself — also with the
 * app closed (that needs "Allow all the time"), so a lost phone can be found.
 * The place is locked with the 32-byte location key the user's app shared
 * with those members (AES-256-GCM: nonce 12 + text + tag 16, the same as
 * lib/services/family_crypto.dart sealPlace); our server only passes it on.
 * Nothing is sent unless the user turned sharing on in the app.
 */
object LocationShare {
    private const val PREFS = "ma_location_share"

    fun configure(context: Context, on: Boolean, key: String?, session: String?, base: String?) {
        val e = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        if (!on || key.isNullOrEmpty() || session.isNullOrEmpty() || base.isNullOrEmpty()) {
            e.clear().apply()
            return
        }
        e.putBoolean("on", true).putString("key", key).putString("session", session).putString("base", base).apply()
    }

    fun isOn(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("on", false)

    fun status(context: Context): Map<String, Any> {
        fun has(p: String) = context.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        val service = try {
            if (Build.VERSION.SDK_INT >= 28) lm?.isLocationEnabled == true else lm?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true || lm?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true
        } catch (_: Exception) { false }
        return mapOf(
            "fine" to (has(Manifest.permission.ACCESS_FINE_LOCATION) || has(Manifest.permission.ACCESS_COARSE_LOCATION)),
            "background" to (Build.VERSION.SDK_INT < 29 || has(Manifest.permission.ACCESS_BACKGROUND_LOCATION)),
            "service" to service,
            "sharing" to isOn(context),
        )
    }

    /** Finds the phone and sends where it is. Blocking: call it off the main thread. */
    fun answer(context: Context): Boolean {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!p.getBoolean("on", false)) return false
        val key = Base64.decode(p.getString("key", "") ?: "", Base64.DEFAULT)
        val session = p.getString("session", "") ?: ""
        val base = p.getString("base", "") ?: ""
        if (key.size != 32 || session.isEmpty() || base.isEmpty()) return false
        val loc = find(context) ?: return false
        val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val place = JSONObject()
            .put("lat", loc.latitude)
            .put("lon", loc.longitude)
            .put("acc", loc.accuracy.toDouble())
            .put("at", fmt.format(Date(loc.time)))
            .put("battery", bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1)
        val sealed = seal(place.toString().toByteArray(Charsets.UTF_8), key)
        return post("$base/wp-json/my-assistant/v1/family/location", session, JSONObject().put("sealed", sealed).toString())
    }

    private fun find(context: Context): Location? {
        val fine = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) return null
        val client = LocationServices.getFusedLocationProviderClient(context)
        return try {
            val cts = CancellationTokenSource()
            Tasks.await(client.getCurrentLocation(if (fine) Priority.PRIORITY_HIGH_ACCURACY else Priority.PRIORITY_BALANCED_POWER_ACCURACY, cts.token), 20, TimeUnit.SECONDS)
                ?: Tasks.await(client.lastLocation, 5, TimeUnit.SECONDS)
        } catch (_: SecurityException) {
            null
        } catch (_: Exception) {
            try { Tasks.await(client.lastLocation, 5, TimeUnit.SECONDS) } catch (_: Exception) { null }
        }
    }

    private fun seal(clear: ByteArray, key: ByteArray): String {
        val nonce = ByteArray(12).also { SecureRandom().nextBytes(it) }
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
        return Base64.encodeToString(nonce + c.doFinal(clear), Base64.NO_WRAP)
    }

    private fun post(url: String, session: String, body: String): Boolean = try {
        val c = URL(url).openConnection() as HttpURLConnection
        c.requestMethod = "POST"
        c.connectTimeout = 15000
        c.readTimeout = 15000
        c.doOutput = true
        c.setRequestProperty("Content-Type", "application/json")
        c.setRequestProperty("Authorization", "Bearer $session")
        c.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
        val ok = c.responseCode == 200
        c.disconnect()
        ok
    } catch (_: Exception) {
        false
    }
}
