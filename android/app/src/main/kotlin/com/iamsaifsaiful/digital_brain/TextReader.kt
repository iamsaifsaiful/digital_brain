package com.iamsaifsaiful.digital_brain

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream

/**
 * "my_assistant/ocr": the printed text in a photo, read on the phone (Google
 * ML Kit through Play Services — nothing is sent anywhere). Used to find a
 * warranty or expiry date on a paper being kept. Latin letters and digits
 * only; null when it cannot be read.
 */
object TextReader {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "read") return result.notImplemented()
        val bytes = call.argument<ByteArray>("bytes") ?: return result.success(null)
        val bitmap = try { upright(bytes) } catch (e: Throwable) { null } ?: return result.success(null)
        try {
            TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                .process(InputImage.fromBitmap(bitmap, 0))
                .addOnSuccessListener { result.success(it.text) }
                .addOnFailureListener { result.success(null) }
        } catch (e: Throwable) {
            result.success(null)
        }
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
}
