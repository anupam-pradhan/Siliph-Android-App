package com.siliph.siliph.bridge

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.os.Handler
import android.os.Looper
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Image tools built on platform BitmapFactory/Bitmap APIs only (sections
 * 5, 60): compress, exact-KB, resize, crop, convert and EXIF strip. Every
 * op re-encodes the pixels, so no EXIF metadata survives into outputs.
 * Same worker-executor + typed-event contract as [PdfBridge].
 */
class ImageToolsBridge(
    private val context: Context,
    private val events: TaskEventsApi,
) : ImageToolsApi {

    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "siliph-image-tools-worker")
    }
    private val cancellations = ConcurrentHashMap<String, AtomicBoolean>()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun inspectImage(uri: String): ImageFacts {
        val parsed = Uri.parse(uri)
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(parsed)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, options)
        } ?: throw FlutterError("not_found", "Cannot open the file", null)
        if (options.outWidth <= 0 || options.outHeight <= 0) {
            throw FlutterError("invalid_input", "That file is not a decodable image", null)
        }
        return ImageFacts(
            width = options.outWidth.toLong(),
            height = options.outHeight.toLong(),
            format = formatForMime(contentType(parsed), options.outMimeType),
            sizeBytes = sizeOf(parsed),
        )
    }

    override fun startCompressImage(
        uri: String,
        format: String,
        quality: Long,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            MemoryGuard.checkMemory("image-compress")
            val bitmap = decodeBitmap(uri)
            try {
                checkCancellation(cancelled)
                postProgress(taskId, 0.4)
                encodeTo(bitmap, compressFormat(format), quality.toInt().coerceIn(1, 100), outputUri)
                postProgress(taskId, 1.0)
            } finally {
                bitmap.recycle()
            }
        }
    }

    override fun startCompressToKb(uri: String, targetKb: Long, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            if (targetKb < 10) {
                throw FlutterError("invalid_input", "Target must be at least 10 KB", null)
            }
            MemoryGuard.checkMemory("image-compress-to-kb")
            var bitmap = decodeBitmap(uri)
            try {
                val targetBytes = targetKb * 1024
                var attempt = bitmap
                var scaled = false
                repeat(MAX_KB_ROUNDS) { round ->
                    checkCancellation(cancelled)
                    postProgress(taskId, 0.1 + 0.8 * round / MAX_KB_ROUNDS)
                    val (bytes, smallest) = searchQuality(attempt, targetBytes)
                    if (bytes != null) {
                        writeBytes(bytes, outputUri)
                        return@runTask
                    }
                    // Even the lowest quality misses the target: downscale
                    // proportionally to the smallest encoding we produced.
                    val factor = sqrt(targetBytes.toDouble() / smallest)
                    if (factor >= 0.95) {
                        throw FlutterError(
                            "invalid_input",
                            "Could not reach ${targetKb}KB even after downscaling",
                            null,
                        )
                    }
                    val next = Bitmap.createScaledBitmap(
                        attempt,
                        max(1, (attempt.width * factor).toInt()),
                        max(1, (attempt.height * factor).toInt()),
                        true,
                    )
                    if (scaled) attempt.recycle()
                    attempt = next
                    scaled = true
                }
                throw FlutterError(
                    "invalid_input",
                    "Could not reach ${targetKb}KB even after downscaling",
                    null,
                )
            } finally {
                bitmap.recycle()
            }
        }
    }

    override fun startResizeImage(
        uri: String,
        width: Long,
        height: Long,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            if (width < 1 || height < 1 || width > MAX_DIMENSION || height > MAX_DIMENSION) {
                throw FlutterError("invalid_input", "Dimensions must be between 1 and $MAX_DIMENSION", null)
            }
            MemoryGuard.checkMemory("image-resize")
            val bitmap = decodeBitmap(uri)
            try {
                checkCancellation(cancelled)
                postProgress(taskId, 0.4)
                val scaled = Bitmap.createScaledBitmap(
                    bitmap, width.toInt(), height.toInt(), true,
                )
                try {
                    encodeTo(scaled, Bitmap.CompressFormat.JPEG, 92, outputUri)
                } finally {
                    if (scaled !== bitmap) scaled.recycle()
                }
                postProgress(taskId, 1.0)
            } finally {
                bitmap.recycle()
            }
        }
    }

    override fun startCropImage(
        uri: String,
        left: Long,
        top: Long,
        width: Long,
        height: Long,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            if (width < 1 || height < 1 || left < 0 || top < 0) {
                throw FlutterError("invalid_input", "Invalid crop region", null)
            }
            MemoryGuard.checkMemory("image-crop")
            val bitmap = decodeBitmap(uri)
            try {
                checkCancellation(cancelled)
                if (left + width > bitmap.width || top + height > bitmap.height) {
                    throw FlutterError("invalid_input", "Crop region is outside the image", null)
                }
                postProgress(taskId, 0.4)
                val cropped = Bitmap.createBitmap(
                    bitmap, left.toInt(), top.toInt(), width.toInt(), height.toInt(),
                )
                try {
                    encodeTo(cropped, Bitmap.CompressFormat.JPEG, 92, outputUri)
                } finally {
                    if (cropped !== bitmap) cropped.recycle()
                }
                postProgress(taskId, 1.0)
            } finally {
                bitmap.recycle()
            }
        }
    }

    override fun startConvertImage(uri: String, format: String, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            MemoryGuard.checkMemory("image-convert")
            val bitmap = decodeBitmap(uri)
            try {
                checkCancellation(cancelled)
                postProgress(taskId, 0.4)
                val target = compressFormat(format)
                val quality = if (target == Bitmap.CompressFormat.PNG) 100 else 92
                encodeTo(bitmap, target, quality, outputUri)
                postProgress(taskId, 1.0)
            } finally {
                bitmap.recycle()
            }
        }
    }

    override fun startStripExif(uri: String, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            MemoryGuard.checkMemory("image-strip-exif")
            val bitmap = decodeBitmap(uri)
            try {
                checkCancellation(cancelled)
                postProgress(taskId, 0.4)
                // A plain re-encode carries pixels only: no EXIF survives.
                encodeTo(bitmap, Bitmap.CompressFormat.JPEG, 92, outputUri)
                postProgress(taskId, 1.0)
            } finally {
                bitmap.recycle()
            }
        }
    }

    override fun startPassportSheet(uri: String, copies: Long, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            if (copies < 1 || copies > MAX_COPIES) {
                throw FlutterError("invalid_input", "Copies must be between 1 and $MAX_COPIES", null)
            }
            MemoryGuard.checkMemory("passport-sheet")
            val source = decodeBitmap(uri)
            try {
                checkCancellation(cancelled)
                postProgress(taskId, 0.3)
                // Centre-crop to the 35x45 mm (3:4) passport ratio.
                val ratio = 3.0 / 4.0
                val crop = centreCrop(source.width, source.height, ratio)
                val face = Bitmap.createBitmap(source, crop[0], crop[1], crop[2], crop[3])
                val photo = Bitmap.createScaledBitmap(face, PHOTO_W, PHOTO_H, true)
                if (face !== photo) face.recycle()

                val sheet = Bitmap.createBitmap(SHEET_W, SHEET_H, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(sheet)
                canvas.drawColor(Color.WHITE)
                val guide = Paint().apply {
                    color = Color.LTGRAY
                    style = Paint.Style.STROKE
                    strokeWidth = 2f
                }
                var placed = 0
                var row = 0
                while (placed < copies && row < GRID_ROWS) {
                    var col = 0
                    while (placed < copies && col < GRID_COLS) {
                        val x = MARGIN + col * (PHOTO_W + GAP)
                        val y = MARGIN + row * (PHOTO_H + GAP)
                        canvas.drawBitmap(photo, x.toFloat(), y.toFloat(), null)
                        canvas.drawRect(
                            x.toFloat(), y.toFloat(),
                            (x + PHOTO_W).toFloat(), (y + PHOTO_H).toFloat(), guide,
                        )
                        placed++
                        col++
                    }
                    row++
                }
                photo.recycle()
                checkCancellation(cancelled)
                postProgress(taskId, 0.8)
                encodeTo(sheet, Bitmap.CompressFormat.JPEG, 95, outputUri)
                sheet.recycle()
                postProgress(taskId, 1.0)
            } finally {
                source.recycle()
            }
        }
    }

    override fun writeImageBytes(uri: String, png: ByteArray) {
        if (png.isEmpty()) {
            throw FlutterError("invalid_input", "Nothing to write", null)
        }
        if (png.size > MAX_WRITTEN_BYTES) {
            throw FlutterError("invalid_input", "Payload too large", null)
        }
        context.contentResolver.openOutputStream(Uri.parse(uri))?.use { out ->
            out.write(png)
        } ?: throw FlutterError("io_error", "Cannot write output", null)
    }

    /// Centre-crop rectangle for [ratio] (width/height) inside w x h.
    private fun centreCrop(w: Int, h: Int, ratio: Double): IntArray {
        if (w / h.toDouble() > ratio) {
            val cw = (h * ratio).toInt().coerceIn(1, w)
            return intArrayOf((w - cw) / 2, 0, cw, h)
        }
        val ch = (w / ratio).toInt().coerceIn(1, h)
        return intArrayOf(0, (h - ch) / 2, w, ch)
    }

    override fun cancel(taskId: String) {
        cancellations[taskId]?.set(true)
    }

    fun shutdown() {
        cancellations.values.forEach { it.set(true) }
        executor.shutdownNow()
    }

    /// Runs [action] on the worker thread with cancellation + typed events.
    private fun runTask(taskId: String, action: (AtomicBoolean) -> Unit) {
        val cancelled = AtomicBoolean(false)
        cancellations[taskId] = cancelled
        executor.execute {
            try {
                action(cancelled)
                postEvent { events.onComplete(taskId) {} }
            } catch (e: Exception) {
                val (code, message) = mapFailure(e, cancelled)
                postEvent { events.onError(taskId, code, message) {} }
            } finally {
                cancellations.remove(taskId)
            }
        }
    }

    /// Decodes the whole image; throws `invalid_input` when undecodable.
    private fun decodeBitmap(uri: String): Bitmap {
        val parsed = Uri.parse(uri)
        val bitmap = context.contentResolver.openInputStream(parsed)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, null)
        } ?: throw FlutterError("not_found", "Cannot open the file", null)
        if (bitmap == null) {
            throw FlutterError("invalid_input", "That file is not a decodable image", null)
        }
        return bitmap
    }

    /// Binary-searches JPEG quality for [targetBytes]. Returns the winning
    /// bytes (or null when even the lowest quality misses) together with
    /// the smallest encoding size seen, used for downscale estimates.
    private fun searchQuality(
        bitmap: Bitmap,
        targetBytes: Long,
    ): Pair<ByteArray?, Int> {
        var low = MIN_QUALITY
        var high = MAX_QUALITY
        var best: ByteArray? = null
        var smallest = Int.MAX_VALUE
        while (low <= high) {
            val mid = (low + high) / 2
            val bytes = encodeToMemory(bitmap, Bitmap.CompressFormat.JPEG, mid)
            if (bytes.size < smallest) smallest = bytes.size
            if (bytes.size <= targetBytes) {
                best = bytes
                low = mid + 1 // Try to keep more quality while fitting.
            } else {
                high = mid - 1
            }
        }
        return best to smallest
    }

    private fun encodeToMemory(bitmap: Bitmap, format: Bitmap.CompressFormat, quality: Int): ByteArray {
        val out = ByteArrayOutputStream()
        bitmap.compress(format, quality, out)
        return out.toByteArray()
    }

    private fun encodeTo(bitmap: Bitmap, format: Bitmap.CompressFormat, quality: Int, outputUri: String) {
        context.contentResolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
            bitmap.compress(format, quality, out)
        } ?: throw FlutterError("io_error", "Cannot write output", null)
    }

    private fun writeBytes(bytes: ByteArray, outputUri: String) {
        context.contentResolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
            out.write(bytes)
        } ?: throw FlutterError("io_error", "Cannot write output", null)
    }

    @Suppress("DEPRECATION")
    private fun compressFormat(format: String): Bitmap.CompressFormat = when (format) {
        "jpeg" -> Bitmap.CompressFormat.JPEG
        "png" -> Bitmap.CompressFormat.PNG
        "webp" -> Bitmap.CompressFormat.WEBP
        else -> throw FlutterError("invalid_input", "Unsupported format: $format", null)
    }

    private fun contentType(uri: Uri): String? = try {
        context.contentResolver.getType(uri)
    } catch (e: Exception) {
        null
    }

    private fun sizeOf(uri: Uri): Long = try {
        context.contentResolver.openFileDescriptor(uri, "r")?.use { it.statSize } ?: -1L
    } catch (e: Exception) {
        -1L
    }

    /// Maps document type / decoder hints onto a short format name.
    private fun formatForMime(documentMime: String?, decodedMime: String?): String {
        val mime = documentMime ?: decodedMime ?: return "unknown"
        return when {
            mime.contains("png", ignoreCase = true) -> "png"
            mime.contains("webp", ignoreCase = true) -> "webp"
            mime.contains("jpeg", ignoreCase = true) || mime.contains("jpg", ignoreCase = true) -> "jpeg"
            mime.contains("heic", ignoreCase = true) || mime.contains("heif", ignoreCase = true) -> "heic"
            else -> "unknown"
        }
    }

    private fun checkCancellation(cancelled: AtomicBoolean) {
        if (cancelled.get()) {
            throw FlutterError("cancelled", "Task cancelled", null)
        }
    }

    private fun mapFailure(e: Exception, cancelled: AtomicBoolean): Pair<String, String> {
        return when {
            cancelled.get() -> "cancelled" to "Task cancelled"
            e is FlutterError -> e.code to (e.message ?: "Failed")
            e is IOException -> "io_error" to (e.message ?: "I/O failure")
            else -> "io_error" to (e.message ?: "Processing failed")
        }
    }

    private fun postProgress(taskId: String, fraction: Double) {
        postEvent { events.onProgress(taskId, fraction) {} }
    }

    private fun postEvent(action: () -> Unit) {
        mainHandler.post(action)
    }

    companion object {
        private const val MAX_DIMENSION = 10_000
        private const val MIN_QUALITY = 5
        private const val MAX_QUALITY = 95
        private const val MAX_KB_ROUNDS = 4

        // Passport sheet: 4x6 inches at 300 dpi, 35x45 mm photos.
        private const val SHEET_W = 1200
        private const val SHEET_H = 1800
        private const val PHOTO_W = 413
        private const val PHOTO_H = 531
        private const val GRID_COLS = 2
        private const val GRID_ROWS = 3
        private const val MARGIN = 40
        private const val GAP = 30
        private const val MAX_COPIES = 6
        private const val MAX_WRITTEN_BYTES = 4 * 1024 * 1024
    }
}
