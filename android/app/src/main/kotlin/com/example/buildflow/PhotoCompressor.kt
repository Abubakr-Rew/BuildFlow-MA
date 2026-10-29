package com.example.buildflow

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Photo compression for reports and chat: the `buildflow/photos` channel,
 * called from lib/core/photos/photo_compressor.dart.
 *
 * - `compress` decodes a picked photo, turns the pixels upright by its EXIF
 *   orientation, scales the long side down to `maxSide` with filtering and
 *   writes a JPEG to cacheDir/photos, trying the `qualities` in turn until
 *   the file fits `targetBytes`. `Bitmap.compress` writes no EXIF, so GPS,
 *   the phone model and serial numbers never leave the device; only the
 *   capture time is read and returned for reports.
 * - `delete` removes files, but only inside cacheDir: never the user's own.
 * - `sweep` removes copies and image_picker leftovers older than
 *   `olderThanMs`.
 *
 * Everything runs on one background thread: photos are processed one at a
 * time, the UI thread never waits, and at most one large bitmap is in
 * memory.
 */
class PhotoCompressor(private val context: Context) : MethodChannel.MethodCallHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in setOf("compress", "delete", "sweep")) {
            result.notImplemented()
            return
        }
        worker.execute {
            try {
                val value: Any? = when (call.method) {
                    "compress" -> compress(
                        path = call.argument<String>("path")!!,
                        maxSide = call.argument<Number>("maxSide")!!.toInt(),
                        targetBytes = call.argument<Number>("targetBytes")!!.toInt(),
                        qualities = call.argument<List<Number>>("qualities")!!.map { it.toInt() },
                    )
                    "delete" -> {
                        call.argument<List<String>>("paths")!!.forEach(::deleteInCache)
                        null
                    }
                    else -> {
                        sweep(call.argument<Number>("olderThanMs")!!.toLong())
                        null
                    }
                }
                main.post { result.success(value) }
            } catch (e: PhotoException) {
                main.post { result.error(e.code, e.message, null) }
            } catch (e: OutOfMemoryError) {
                main.post { result.error("out_of_memory", e.toString(), null) }
            } catch (e: Exception) {
                main.post { result.error("failed", e.toString(), null) }
            }
        }
    }

    // ── compress ────────────────────────────────────────────────

    private fun compress(
        path: String,
        maxSide: Int,
        targetBytes: Int,
        qualities: List<Int>,
    ): Map<String, Any?> {
        val started = System.nanoTime()
        if (!File(path).isFile) throw PhotoException("not_found", "No file at $path")

        // Size and type only; nothing is decoded yet.
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw PhotoException("unsupported_format", "Cannot read ${bounds.outMimeType} at $path")
        }

        // Decode at the largest power-of-two reduction that still keeps the
        // long side at or above maxSide; the exact scaling below is filtered,
        // so thin lines like cracks and joints stay continuous.
        val longSide = maxOf(bounds.outWidth, bounds.outHeight)
        var sample = 1
        while (longSide / (sample * 2) >= maxSide) sample *= 2
        // HEIC decodes from Android 9 on; before that this returns null.
        val decoded = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: throw PhotoException("unsupported_format", "Cannot decode ${bounds.outMimeType} at $path")

        val exif = try {
            ExifInterface(path)
        } catch (e: Exception) {
            null
        }
        val orientation = exif?.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            ?: ExifInterface.ORIENTATION_NORMAL
        val scale = minOf(1f, maxSide.toFloat() / maxOf(decoded.width, decoded.height))
        val matrix = orientationMatrix(orientation).apply { postScale(scale, scale) }
        var bitmap = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        if (bitmap !== decoded) decoded.recycle()
        // JPEG has no transparency: transparent pixels would turn black.
        if (bitmap.hasAlpha()) bitmap = onWhite(bitmap)

        // The first quality that fits; if none does, the last one as is.
        val jpeg = ByteArrayOutputStream()
        var quality = qualities.first()
        for (q in qualities) {
            quality = q
            jpeg.reset()
            bitmap.compress(Bitmap.CompressFormat.JPEG, q, jpeg)
            if (jpeg.size() <= targetBytes) break
        }
        val width = bitmap.width
        val height = bitmap.height
        bitmap.recycle()

        val dir = File(context.cacheDir, DIR).apply { mkdirs() }
        val file = File(dir, "${UUID.randomUUID()}.jpg")
        file.outputStream().use { jpeg.writeTo(it) }

        return mapOf(
            "path" to file.absolutePath,
            "width" to width,
            "height" to height,
            "bytes" to jpeg.size(),
            "quality" to quality,
            // For the log: the original as stored (not turned upright) and
            // the time of the work itself, without waiting in the queue.
            "sourceWidth" to bounds.outWidth,
            "sourceHeight" to bounds.outHeight,
            "sourceBytes" to File(path).length(),
            "elapsedMs" to (System.nanoTime() - started) / 1_000_000,
            // «2026:10:28 11:42:05» and «+06:00»; parsed on the Dart side.
            "takenAt" to exif?.getAttribute("DateTimeOriginal"),
            "takenAtOffset" to exif?.getAttribute("OffsetTimeOriginal"),
        )
    }

    /** Turns pixels stored sideways or mirrored upright (the EXIF orientations 2–8). */
    private fun orientationMatrix(orientation: Int) = Matrix().apply {
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> {
                setRotate(180f)
                postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                setRotate(90f)
                postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                setRotate(-90f)
                postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> setRotate(-90f)
        }
    }

    private fun onWhite(source: Bitmap): Bitmap {
        val flat = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
        Canvas(flat).apply {
            drawColor(Color.WHITE)
            drawBitmap(source, 0f, 0f, null)
        }
        source.recycle()
        return flat
    }

    // ── delete and sweep ────────────────────────────────────────

    private fun deleteInCache(path: String) {
        val file = File(path).canonicalFile
        if (file.path.startsWith(context.cacheDir.canonicalPath + File.separator)) file.delete()
    }

    /**
     * Our copies in cacheDir/photos, voice notes (voice-…), plus what
     * image_picker leaves in cacheDir: camera shots (image_picker…), its own
     * scaled copies (scaled_…) and gallery copies, each in a folder named by a UUID.
     */
    private fun sweep(olderThanMs: Long) {
        val cutoff = System.currentTimeMillis() - olderThanMs
        val cache = context.cacheDir
        File(cache, DIR).listFiles()?.forEach { if (it.lastModified() < cutoff) it.delete() }
        cache.listFiles()?.forEach { f ->
            val leftover = if (f.isDirectory) {
                UUID_NAME.matches(f.name)
            } else {
                f.name.startsWith("image_picker") || f.name.startsWith("scaled_") ||
                    f.name.startsWith("voice-")
            }
            if (leftover && f.lastModified() < cutoff) f.deleteRecursively()
        }
    }

    private class PhotoException(val code: String, message: String) : Exception(message)

    private companion object {
        const val CHANNEL = "buildflow/photos"
        const val DIR = "photos"
        val UUID_NAME = Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
    }
}
