package com.iamsaifsaiful.digital_brain

import android.content.Context
import android.os.Handler
import android.os.Looper

/**
 * সমস্যার লগ (owner, 6 Nov): "IllegalStateException: Reply already submitted"
 * closed the app (17 times on 1.0.0–1.0.5). It is a plugin answering one
 * call from Dart twice — the first answer has already reached Dart, the
 * second one only throws. The release build's code names are shortened, so
 * the log could not say whose.
 *
 * This keeps the main thread's loop going past exactly that error (and no
 * other): the app stays open, and the full place is written to the log as a
 * problem (not a crash), so the plugin can be found and fixed.
 */
object ReplyGuard {
    private var installed = false

    fun install(c: Context) {
        if (installed) return
        installed = true
        val app = c.applicationContext
        Handler(Looper.getMainLooper()).post {
            while (true) {
                try {
                    Looper.loop()
                    return@post // the loop ended on purpose (the app is quitting)
                } catch (e: Throwable) {
                    if (!isDoubleReply(e)) throw e
                    CrashLog.note(app, "ReplyTwice", e, level = "problem")
                }
            }
        }
    }

    fun isDoubleReply(e: Throwable): Boolean =
        e is IllegalStateException && e.message?.startsWith("Reply already submitted") == true
}
