package com.siliph.siliph.bridge

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import android.net.Uri
import android.os.Handler
import android.os.Looper
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
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

    override fun startRotateImage(uri: String, degrees: Long, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            val deg = degrees.toInt()
            if (deg != 90 && deg != 180 && deg != 270) {
                throw FlutterError("invalid_input", "Rotation must be 90, 180 or 270 degrees", null)
            }
            MemoryGuard.checkMemory("image-rotate")
            val bitmap = decodeBitmap(uri)
            try {
                checkCancellation(cancelled)
                postProgress(taskId, 0.4)
                val matrix = Matrix().apply { postRotate(deg.toFloat()) }
                val rotated = Bitmap.createBitmap(
                    bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true,
                )
                try {
                    encodeTo(rotated, Bitmap.CompressFormat.JPEG, 92, outputUri)
                } finally {
                    if (rotated !== bitmap) rotated.recycle()
                }
                postProgress(taskId, 1.0)
            } finally {
                bitmap.recycle()
            }
        }
    }

    override fun startFlipImage(
        uri: String,
        horizontal: Boolean,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            MemoryGuard.checkMemory("image-flip")
            val bitmap = decodeBitmap(uri)
            try {
                checkCancellation(cancelled)
                postProgress(taskId, 0.4)
                val matrix = Matrix().apply {
                    preScale(if (horizontal) -1f else 1f, if (horizontal) 1f else -1f)
                }
                val flipped = Bitmap.createBitmap(
                    bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true,
                )
                try {
                    encodeTo(flipped, Bitmap.CompressFormat.JPEG, 92, outputUri)
                } finally {
                    if (flipped !== bitmap) flipped.recycle()
                }
                postProgress(taskId, 1.0)
            } finally {
                bitmap.recycle()
            }
        }
    }

    /// Downscale + Sobel edge scan; returns the edge cluster's bounding
    /// quad as an approximate document outline. Empty when the image has
    /// no convincing document edges. Callers adjust the corners manually.
    override fun detectDocumentCorners(uri: String): List<Double> {
        val parsed = Uri.parse(uri)
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(parsed)?.use {
            BitmapFactory.decodeStream(it, null, bounds)
        } ?: throw FlutterError("not_found", "Cannot open the file", null)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > DETECT_DIMENSION) sample *= 2
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        val bitmap = context.contentResolver.openInputStream(parsed)?.use {
            BitmapFactory.decodeStream(it, null, options)
        } ?: throw FlutterError("not_found", "Cannot open the file", null)
        try {
            val w = bitmap.width
            val h = bitmap.height
            if (w < 16 || h < 16) return emptyList()
            val gray = IntArray(w * h)
            bitmap.getPixels(gray, 0, w, 0, 0, w, h)
            for (i in gray.indices) {
                val p = gray[i]
                gray[i] = (Color.red(p) * 299 + Color.green(p) * 587 + Color.blue(p) * 114) / 1000
            }
            // Sobel magnitude, thresholded at mean + deviation.
            var sum = 0.0
            var sumSq = 0.0
            val mag = FloatArray(w * h)
            for (y in 1 until h - 1) {
                for (x in 1 until w - 1) {
                    val gx = -gray[(y - 1) * w + x - 1] + gray[(y - 1) * w + x + 1] -
                        2 * gray[y * w + x - 1] + 2 * gray[y * w + x + 1] -
                        gray[(y + 1) * w + x - 1] + gray[(y + 1) * w + x + 1]
                    val gy = -gray[(y - 1) * w + x - 1] - 2 * gray[(y - 1) * w + x] -
                        gray[(y - 1) * w + x + 1] + gray[(y + 1) * w + x - 1] +
                        2 * gray[(y + 1) * w + x] + gray[(y + 1) * w + x + 1]
                    val m = sqrt((gx * gx + gy * gy).toFloat())
                    mag[y * w + x] = m
                    sum += m
                    sumSq += m.toDouble() * m
                }
            }
            val n = (w - 2) * (h - 2)
            val mean = sum / n
            val dev = sqrt(max(0.0, sumSq / n - mean * mean))
            val threshold = (mean + dev).toFloat()
            var minX = w; var minY = h; var maxX = -1; var maxY = -1
            var hits = 0
            for (y in 1 until h - 1) {
                for (x in 1 until w - 1) {
                    if (mag[y * w + x] > threshold) {
                        hits++
                        if (x < minX) minX = x
                        if (x > maxX) maxX = x
                        if (y < minY) minY = y
                        if (y > maxY) maxY = y
                    }
                }
            }
            // Too sparse (blank photo) or too dense (busy background): be
            // honest and report no detection instead of a wild guess.
            val density = hits.toDouble() / n
            if (hits < 200 || density < 0.01 || density > 0.45) return emptyList()
            val boxW = maxX - minX
            val boxH = maxY - minY
            if (boxW < w * 0.3 || boxH < h * 0.3) return emptyList()
            // Expand slightly so the document is not shaved, then clamp.
            val padX = (boxW * 0.02).toInt()
            val padY = (boxH * 0.02).toInt()
            val tlx = ((minX - padX).coerceAtLeast(0)).toDouble() / w
            val tly = ((minY - padY).coerceAtLeast(0)).toDouble() / h
            val brx = ((maxX + padX).coerceAtMost(w - 1)).toDouble() / w
            val bry = ((maxY + padY).coerceAtMost(h - 1)).toDouble() / h
            return listOf(tlx, tly, brx, tly, brx, bry, tlx, bry)
        } finally {
            bitmap.recycle()
        }
    }

    override fun startPerspectiveCrop(
        uri: String,
        corners: List<Double>,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            if (corners.size != 8) {
                throw FlutterError("invalid_input", "Four corners are required", null)
            }
            MemoryGuard.checkMemory("perspective-crop")
            val bitmap = decodeBitmap(uri)
            try {
                checkCancellation(cancelled)
                val w = bitmap.width
                val h = bitmap.height
                val src = FloatArray(8)
                for (i in 0 until 8 step 2) {
                    src[i] = (corners[i].coerceIn(0.0, 1.0) * w).toFloat()
                    src[i + 1] = (corners[i + 1].coerceIn(0.0, 1.0) * h).toFloat()
                }
                val topW = dist(src[0], src[1], src[2], src[3])
                val bottomW = dist(src[6], src[7], src[4], src[5])
                val leftH = dist(src[0], src[1], src[6], src[7])
                val rightH = dist(src[2], src[3], src[4], src[5])
                val outW = max(topW, bottomW).toInt().coerceIn(1, MAX_DIMENSION)
                val outH = max(leftH, rightH).toInt().coerceIn(1, MAX_DIMENSION)
                val dst = floatArrayOf(0f, 0f, outW.toFloat(), 0f, outW.toFloat(), outH.toFloat(), 0f, outH.toFloat())
                val matrix = Matrix()
                if (!matrix.setPolyToPoly(src, 0, dst, 0, 4)) {
                    throw FlutterError("invalid_input", "Invalid corner selection", null)
                }
                postProgress(taskId, 0.4)
                val out = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(out)
                canvas.drawColor(Color.WHITE)
                canvas.drawBitmap(bitmap, matrix, Paint(Paint.FILTER_BITMAP_FLAG))
                try {
                    encodeTo(out, Bitmap.CompressFormat.JPEG, 92, outputUri)
                } finally {
                    out.recycle()
                }
                postProgress(taskId, 1.0)
            } finally {
                bitmap.recycle()
            }
        }
    }

    override fun startEnhanceImage(uri: String, mode: String, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            MemoryGuard.checkMemory("image-enhance")
            val bitmap = decodeBitmap(uri)
            try {
                checkCancellation(cancelled)
                postProgress(taskId, 0.3)
                when (mode) {
                    "bw" -> {
                        val gray = toGrayscale(bitmap)
                        try {
                            // Otsu-style fixed midpoint threshold: honest
                            // black & white for text documents.
                            val pixels = IntArray(gray.width * gray.height)
                            gray.getPixels(pixels, 0, gray.width, 0, 0, gray.width, gray.height)
                            var mean = 0L
                            for (p in pixels) mean += Color.red(p)
                            mean /= pixels.size
                            val threshold = mean.coerceIn(80, 180).toInt()
                            for (i in pixels.indices) {
                                val v = if (Color.red(pixels[i]) >= threshold) 255 else 0
                                pixels[i] = Color.rgb(v, v, v)
                            }
                            val bw = Bitmap.createBitmap(gray.width, gray.height, Bitmap.Config.ARGB_8888)
                            bw.setPixels(pixels, 0, gray.width, 0, 0, gray.width, gray.height)
                            try {
                                encodeTo(bw, Bitmap.CompressFormat.JPEG, 95, outputUri)
                            } finally {
                                bw.recycle()
                            }
                        } finally {
                            if (gray !== bitmap) gray.recycle()
                        }
                    }
                    "grayscale" -> {
                        val gray = toGrayscale(bitmap)
                        try {
                            encodeTo(gray, Bitmap.CompressFormat.JPEG, 92, outputUri)
                        } finally {
                            if (gray !== bitmap) gray.recycle()
                        }
                    }
                    "color", "magic" -> {
                        val contrast = if (mode == "magic") 1.35f else 1.15f
                        val saturation = if (mode == "magic") 0f else 1f
                        val translate = (1 - contrast) * 128 + if (mode == "magic") 8f else 5f
                        val matrix = ColorMatrix()
                        matrix.setSaturation(saturation)
                        val contrastMatrix = ColorMatrix(
                            floatArrayOf(
                                contrast, 0f, 0f, 0f, translate,
                                0f, contrast, 0f, 0f, translate,
                                0f, 0f, contrast, 0f, translate,
                                0f, 0f, 0f, 1f, 0f,
                            )
                        )
                        matrix.preConcat(contrastMatrix)
                        val out = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
                        val paint = Paint(Paint.FILTER_BITMAP_FLAG).apply {
                            colorFilter = ColorMatrixColorFilter(matrix)
                        }
                        Canvas(out).drawBitmap(bitmap, 0f, 0f, paint)
                        try {
                            encodeTo(out, Bitmap.CompressFormat.JPEG, 92, outputUri)
                        } finally {
                            out.recycle()
                        }
                    }
                    else -> throw FlutterError("invalid_input", "Unknown enhancement mode", null)
                }
                postProgress(taskId, 1.0)
            } finally {
                bitmap.recycle()
            }
        }
    }

    /// Grayscale copy of [bitmap] via luminance colour matrix.
    private fun toGrayscale(bitmap: Bitmap): Bitmap {
        val out = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
        val matrix = ColorMatrix()
        matrix.setSaturation(0f)
        Canvas(out).drawBitmap(bitmap, 0f, 0f, Paint().apply {
            colorFilter = ColorMatrixColorFilter(matrix)
        })
        return out
    }

    private fun dist(x1: Float, y1: Float, x2: Float, y2: Float): Float {
        val dx = x2 - x1
        val dy = y2 - y1
        return sqrt(dx * dx + dy * dy)
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
        private const val DETECT_DIMENSION = 320
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
