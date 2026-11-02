package com.iamsaifsaiful.riyal_hisab

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintManager
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

// "riyal/pdf": save a file into Downloads, and print a PDF.
object PdfTools {
    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "save" -> result.success(
                    save(activity, call.argument<ByteArray>("bytes")!!, call.argument<String>("name")!!, call.argument<String>("mime") ?: "application/pdf")
                )
                "print" -> {
                    print(activity, call.argument<String>("path")!!, call.argument<String>("name") ?: "hisab")
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("pdf", e.message, null)
        }
    }

    private fun save(ctx: Context, bytes: ByteArray, name: String, mime: String): String {
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/RiyalHisab")
            }
            val uri = ctx.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("no uri")
            ctx.contentResolver.openOutputStream(uri)!!.use { it.write(bytes) }
            return "Download/RiyalHisab/$name"
        }
        val dir = File(ctx.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "")
        dir.mkdirs()
        val f = File(dir, name)
        f.writeBytes(bytes)
        return f.absolutePath
    }

    private fun print(activity: Activity, path: String, name: String) {
        val pm = activity.getSystemService(Context.PRINT_SERVICE) as PrintManager
        pm.print(name, object : PrintDocumentAdapter() {
            override fun onLayout(old: PrintAttributes?, new: PrintAttributes, signal: CancellationSignal?, cb: LayoutResultCallback, extras: Bundle?) {
                if (signal?.isCanceled == true) { cb.onLayoutCancelled(); return }
                cb.onLayoutFinished(PrintDocumentInfo.Builder(name).setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT).build(), true)
            }

            override fun onWrite(pages: Array<out PageRange>?, dest: ParcelFileDescriptor, signal: CancellationSignal?, cb: WriteResultCallback) {
                FileInputStream(File(path)).use { input ->
                    FileOutputStream(dest.fileDescriptor).use { out -> input.copyTo(out) }
                }
                cb.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
            }
        }, PrintAttributes.Builder().setMediaSize(PrintAttributes.MediaSize.ISO_A4).build())
    }
}
