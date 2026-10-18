package com.iamsaifsaiful.digital_brain

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import androidx.exifinterface.media.ExifInterface
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.File

/**
 * "my_assistant/ocr": the printed text of a photo or of a PDF's first pages,
 * read on the phone (Google ML Kit through Play Services — nothing is sent
 * anywhere). Used to fill a paper's details (number, dates…) for the user to
 * check. Latin letters and digits only; null when it cannot be read.
 */
object TextReader {
    private const val MAX_PDF_PAGES = 4

    fun handle(call: MethodCall, result: MethodChannel.Result, cacheDir: File) {
        if (call.method != "read") return result.notImplemented()
        val bytes = call.argument<ByteArray>("bytes") ?: return result.success(null)
        val pdf = call.argument<String>("mime") == "application/pdf"
        val main = Handler(Looper.getMainLooper())
        Thread {
            val text = try {
                val pages = if (pdf) pdfPages(bytes, cacheDir) else listOfNotNull(upright(bytes))
                val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                pages.joinToString("\n") { Tasks.await(recognizer.process(InputImage.fromBitmap(it, 0))).text }
            } catch (e: Throwable) {
                null
            }
            main.post { result.success(text) }
        }.start()
    }

    /** The photo turned the way it was taken, and not larger than needed to read it. */
    private fun upright(bytes: ByteArray): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 2600) sample *= 2
        val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
        val turn = when (ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        if (turn == 0f) return bmp
        return Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, Matrix().apply { postRotate(turn) }, true)
    }

    /** A PDF's first pages as pictures (white behind, about 2000 px wide), via a short-lived file. */
    private fun pdfPages(bytes: ByteArray, cacheDir: File): List<Bitmap> {
        val f = File.createTempFile("read", ".pdf", cacheDir)
        try {
            f.writeBytes(bytes)
            ParcelFileDescriptor.open(f, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                PdfRenderer(fd).use { r ->
                    return (0 until minOf(r.pageCount, MAX_PDF_PAGES)).map { i ->
                        r.openPage(i).use { p ->
                            val scale = 2000f / maxOf(p.width, 1)
                            val bmp = Bitmap.createBitmap((p.width * scale).toInt().coerceAtLeast(1), (p.height * scale).toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
                            bmp.eraseColor(Color.WHITE)
                            p.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            bmp
                        }
                    }
                }
            }
        } finally {
            f.delete()
        }
    }
}
