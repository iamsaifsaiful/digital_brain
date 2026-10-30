package com.iamsaifsaiful.digital_brain

import android.content.Context
import org.json.JSONObject
import java.io.File

/**
 * সমস্যার লগ (owner, 27 Oct): when the Android side of the app crashes, the
 * kind of error, its first line and the places in our own code are written
 * to a small file in the app's private folder; the app sends it (cleaned of
 * anything that is not plain code text) the next time it opens — see
 * lib/services/error_log.dart. Nothing else on the phone is read.
 */
class CrashLog private constructor(
    private val dir: File,
    private val version: String,
    private val before: Thread.UncaughtExceptionHandler?,
) : Thread.UncaughtExceptionHandler {

    override fun uncaughtException(t: Thread, e: Throwable) {
        try {
            val places = mutableListOf<String>()
            var x: Throwable? = e
            while (x != null && places.size < 15) {
                for (f in x.stackTrace) {
                    if (f.className.startsWith("com.iamsaifsaiful") || f.className.startsWith("io.flutter")) {
                        places.add("${f.className}.${f.methodName}:${f.lineNumber}")
                        if (places.size >= 15) break
                    }
                }
                x = x.cause
            }
            val first = (e.message ?: "").lineSequence().firstOrNull().orEmpty().take(300)
            val j = JSONObject()
                .put("kind", "Android:" + e.javaClass.simpleName)
                .put("message", first)
                .put("stack", places.joinToString("\n"))
                .put("version", version)
            File(dir, "app_crash.json").writeText(j.toString())
        } catch (_: Throwable) {
        }
        before?.uncaughtException(t, e)
    }

    companion object {
        /**
         * A problem the app survived (owner, 29 Oct: AdMob's WorkManager closed
         * the app at start): its kind, message and where — Google's code too,
         * so we can see whose — for the সমস্যার লগ next time.
         */
        fun note(c: Context, what: String, e: Throwable) {
            try {
                val places = mutableListOf<String>()
                var x: Throwable? = e
                val causes = mutableListOf<String>()
                while (x != null && causes.size < 4) {
                    causes.add(x.javaClass.name + ": " + (x.message ?: "").lineSequence().firstOrNull().orEmpty().take(160))
                    for (f in x.stackTrace.take(8)) places.add("${f.className}.${f.methodName}:${f.lineNumber}")
                    x = x.cause
                }
                val ver = try { c.packageManager.getPackageInfo(c.packageName, 0).versionName ?: "" } catch (_: Exception) { "" }
                val j = JSONObject()
                    .put("kind", "Android:$what")
                    .put("message", causes.joinToString(" <- ").take(300))
                    .put("stack", places.take(30).joinToString("\n"))
                    .put("version", ver)
                File(c.filesDir, "app_crash.json").writeText(j.toString())
            } catch (_: Throwable) {
            }
        }

        fun install(c: Context) {
            val now = Thread.getDefaultUncaughtExceptionHandler()
            if (now is CrashLog) return
            val ver = try {
                c.packageManager.getPackageInfo(c.packageName, 0).versionName ?: ""
            } catch (_: Exception) {
                ""
            }
            Thread.setDefaultUncaughtExceptionHandler(CrashLog(c.filesDir, ver, now))
        }
    }
}
