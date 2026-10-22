package com.iamsaifsaiful.digital_brain

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import java.io.File

/**
 * The member's own audio file (an mp3 from the phone) as the reminder tone.
 *
 * A notification channel's sound is played by the system, which cannot read
 * a file the user only lent to this app. So the file is copied:
 *  - Android 10+: into the phone's media store under Alarms/My Assistant
 *    (no permission needed for the app's own entries) — the system reads it
 *    like any alarm tone, also after a restart;
 *  - Android 7–9: into the app's files, shared with the system through the
 *    FileProvider; the read grant is given again whenever the app starts.
 */
object CustomTone {
    private const val MAX_BYTES = 15L * 1024 * 1024
    private const val PREFS = "custom_tone"
    private val readers = listOf("com.android.systemui", "android")

    /** (uri, title) of the copy, or an error code: "too_big", "not_audio", "failed". */
    fun add(ctx: Context, src: Uri): Map<String, String> {
        val cr = ctx.contentResolver
        var name = "tone"
        var size = -1L
        try {
            cr.query(src, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    name = c.getString(0) ?: name
                    if (!c.isNull(1)) size = c.getLong(1)
                }
            }
        } catch (e: Exception) {
        }
        if (size > MAX_BYTES) return mapOf("error" to "too_big")
        val mime = cr.getType(src) ?: "audio/mpeg"
        if (!mime.startsWith("audio/") && mime != "application/ogg") return mapOf("error" to "not_audio")
        val title = name.substringBeforeLast('.').ifBlank { name }.take(60)
        val safe = name.replace(Regex("[^\\p{L}\\p{N}._ -]"), "_").take(80)
        return try {
            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) toMediaStore(ctx, src, safe, title, mime) else toFiles(ctx, src, safe)
            if (uri == null) mapOf("error" to "failed") else mapOf("uri" to uri.toString(), "title" to title)
        } catch (e: TooBig) {
            mapOf("error" to "too_big")
        } catch (e: Exception) {
            mapOf("error" to "failed")
        }
    }

    private class TooBig : Exception()

    private fun copy(ctx: Context, src: Uri, out: java.io.OutputStream) {
        ctx.contentResolver.openInputStream(src)?.use { inp ->
            val buf = ByteArray(64 * 1024)
            var total = 0L
            while (true) {
                val n = inp.read(buf)
                if (n < 0) break
                total += n
                if (total > MAX_BYTES) throw TooBig()
                out.write(buf, 0, n)
            }
        } ?: throw IllegalStateException("cannot read")
    }

    private fun toMediaStore(ctx: Context, src: Uri, fileName: String, title: String, mime: String): Uri? {
        val cr = ctx.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Audio.Media.TITLE, title)
            put(MediaStore.Audio.Media.MIME_TYPE, mime)
            put(MediaStore.Audio.Media.RELATIVE_PATH, Environment.DIRECTORY_ALARMS + "/My Assistant")
            put(MediaStore.Audio.Media.IS_ALARM, 1)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val uri = cr.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values) ?: return null
        try {
            cr.openOutputStream(uri)?.use { copy(ctx, src, it) } ?: throw IllegalStateException("cannot write")
            cr.update(uri, ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) }, null, null)
        } catch (e: Exception) {
            try { cr.delete(uri, null, null) } catch (x: Exception) {}
            throw e
        }
        return uri
    }

    private fun toFiles(ctx: Context, src: Uri, fileName: String): Uri {
        val dir = File(ctx.filesDir, "tones").apply { mkdirs() }
        val f = File(dir, "${System.currentTimeMillis()}_$fileName")
        try {
            f.outputStream().use { copy(ctx, src, it) }
        } catch (e: Exception) {
            f.delete()
            throw e
        }
        val uri = androidx.core.content.FileProvider.getUriForFile(ctx, "${ctx.packageName}.files", f)
        grant(ctx, uri)
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("shared", uri.toString()).apply()
        return uri
    }

    private fun grant(ctx: Context, uri: Uri) {
        for (p in readers) {
            try { ctx.grantUriPermission(p, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (e: Exception) {}
        }
    }

    /** Android 7–9: read grants end with a restart, so they are given again at start. */
    fun regrant(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) return
        val s = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("shared", null) ?: return
        grant(ctx, Uri.parse(s))
    }

    /** Removes a tone this app added (when another is chosen); others are left alone. */
    fun remove(ctx: Context, uri: String) {
        try {
            val u = Uri.parse(uri)
            if (u.authority == "${ctx.packageName}.files") {
                val name = u.lastPathSegment ?: return
                File(File(ctx.filesDir, "tones"), name).delete()
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && u.authority == MediaStore.AUTHORITY) {
                // Only entries this app inserted can be deleted without asking.
                ctx.contentResolver.delete(u, null, null)
            }
        } catch (e: Exception) {
        }
    }
}
