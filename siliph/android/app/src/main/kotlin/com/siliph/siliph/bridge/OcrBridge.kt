package com.siliph.siliph.bridge

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.pdmodel.PDPageContentStream
import com.tom_roush.pdfbox.pdmodel.common.PDRectangle
import com.tom_roush.pdfbox.pdmodel.font.PDType1Font
import com.tom_roush.pdfbox.pdmodel.graphics.image.PDImageXObject
import com.tom_roush.pdfbox.pdmodel.graphics.state.RenderingMode
import com.tom_roush.pdfbox.rendering.ImageType
import com.tom_roush.pdfbox.rendering.PDFRenderer
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * OCR engine boundary (sections 5, 192) backed by the bundled ML Kit
 * Latin text recognizer: no network, no Play-services model download.
 *
 * - recognizeImage: one bitmap in, normalized text blocks out.
 * - recognizePdf: each page rendered at 150 DPI and recognized in turn.
 * - searchablePdf: honest overlay output — every page becomes its
 *   rendered image plus an invisible text layer positioned from the
 *   recognizer's line boxes, so selection is approximate but real.
 *
 * Same worker-executor + typed-event contract as [PdfBridge].
 */
class OcrBridge(
    private val context: Context,
    private val events: TaskEventsApi,
) : OcrApi {

    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "siliph-ocr-worker")
    }
    private val cancellations = ConcurrentHashMap<String, AtomicBoolean>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val recognizer: TextRecognizer by lazy {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }

    override fun startRecognizeImage(uri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runRecognizeImage(uri, taskId, cancelled)
        }
    }

    override fun startRecognizePdf(uri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runRecognizePdf(uri, taskId, cancelled)
        }
    }

    override fun startSearchablePdf(uri: String, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runSearchablePdf(uri, outputUri, taskId, cancelled)
        }
    }

    override fun cancel(taskId: String) {
        cancellations[taskId]?.set(true)
    }

    fun shutdown() {
        cancellations.values.forEach { it.set(true) }
        executor.shutdownNow()
        recognizer.close()
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

    private fun runRecognizeImage(uri: String, taskId: String, cancelled: AtomicBoolean) {
        MemoryGuard.checkMemory("ocr-image")
        val bitmap = decodeBitmap(Uri.parse(uri), MAX_OCR_DIMENSION)
            ?: throw FlutterError("invalid_input", "Cannot decode the image", null)
        try {
            val blocks = recognize(bitmap, 0)
            checkCancellation(cancelled)
            postEvent { events.onOcrResult(taskId, blocks) {} }
        } finally {
            bitmap.recycle()
        }
    }

    private fun runRecognizePdf(uri: String, taskId: String, cancelled: AtomicBoolean) {
        MemoryGuard.checkMemory("ocr-pdf")
        val resolver = context.contentResolver
        resolver.openInputStream(Uri.parse(uri))?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly()).use { document ->
                if (document.isEncrypted) {
                    // The port exposes no password decrypt path here; be
                    // honest instead of producing an empty result.
                    throw FlutterError("invalid_pdf", "PDF is password protected", null)
                }
                val renderer = PDFRenderer(document)
                val pages = document.numberOfPages
                val all = mutableListOf<OcrBlock>()
                for (index in 0 until pages) {
                    checkCancellation(cancelled)
                    val bitmap = renderer.renderImageWithDPI(index, OCR_DPI, ImageType.RGB)
                    try {
                        all.addAll(recognize(bitmap, index))
                    } finally {
                        bitmap.recycle()
                    }
                    postProgress(taskId, (index + 1).toDouble() / pages)
                }
                postEvent { events.onOcrResult(taskId, all) {} }
            }
        } ?: throw FlutterError("not_found", "Cannot open $uri", null)
    }

    private fun runSearchablePdf(
        uri: String,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("searchable-pdf")
        val resolver = context.contentResolver
        resolver.openInputStream(Uri.parse(uri))?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly()).use { source ->
                if (source.isEncrypted) {
                    throw FlutterError("invalid_pdf", "PDF is password protected", null)
                }
                val renderer = PDFRenderer(source)
                val pages = source.numberOfPages
                val destination = PDDocument()
                try {
                    for (index in 0 until pages) {
                        checkCancellation(cancelled)
                        buildSearchablePage(destination, renderer, source, index, taskId)
                        postProgress(taskId, (index + 1).toDouble() / pages)
                    }
                    resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                        destination.save(out)
                    } ?: throw FlutterError("io_error", "Cannot write output", null)
                } finally {
                    destination.close()
                }
            }
        } ?: throw FlutterError("not_found", "Cannot open $uri", null)
    }

    /// One output page: the source page rendered as a full-page image,
    /// with an invisible text layer drawn from the recognizer's boxes.
    /// The output page carries no /Rotate — its media box already matches
    /// the rendered orientation, so text coordinates map 1:1.
    private fun buildSearchablePage(
        destination: PDDocument,
        renderer: PDFRenderer,
        source: PDDocument,
        index: Int,
        taskId: String,
    ) {
        val box = source.getPage(index).mediaBox
        val rotation = source.getPage(index).rotation
        val renderW = if (rotation == 90 || rotation == 270) box.height else box.width
        val renderH = if (rotation == 90 || rotation == 270) box.width else box.height

        // One render serves both the recognizer and the page image below.
        val bitmap = renderer.renderImageWithDPI(index, OCR_DPI, ImageType.RGB)
        val blocks = recognize(bitmap, index)

        // Stage the rendered page as JPEG, then rebuild it as an image page.
        val staged = File(context.cacheDir, "siliph-ocr-$taskId-$index.jpg")
        try {
            FileOutputStream(staged).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 82, out)
            }
            bitmap.recycle()
            val xobject = PDImageXObject.createFromFileByExtension(staged, destination)
            val page = PDPage(PDRectangle(renderW, renderH))
            destination.addPage(page)
            PDPageContentStream(destination, page).use { stream ->
                stream.drawImage(xobject, 0f, 0f, renderW, renderH)
                stream.setRenderingMode(RenderingMode.NEITHER) // invisible text layer
                stream.setFont(PDType1Font.HELVETICA, 10f)
                for (block in blocks) {
                    val pageW = renderW.toDouble()
                    val pageH = renderH.toDouble()
                    val fontSize = ((block.bottom - block.top) * pageH)
                        .coerceIn(2.0, pageH)
                    val x = (block.left * pageW).toFloat()
                    // PDF y grows upward; the recognizer's bottom edge sits
                    // close to the line baseline, so nudge up by ~0.8em.
                    val y = (pageH - block.bottom * pageH + fontSize * 0.8)
                        .toFloat()
                    val safe = winAnsiSafe(block.text)
                    if (safe.isBlank()) continue
                    stream.beginText()
                    stream.setFont(PDType1Font.HELVETICA, fontSize.toFloat())
                    stream.newLineAtOffset(x, y)
                    stream.showText(safe)
                    stream.endText()
                }
            }
        } finally {
            staged.delete()
        }
    }

    /// Runs the recognizer over [bitmap] and maps each text block to
    /// normalized bounds plus its [pageIndex].
    private fun recognize(bitmap: Bitmap, pageIndex: Int): List<OcrBlock> {
        val vision = try {
            Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, 0)))
        } catch (e: Exception) {
            throw FlutterError("io_error", "Text recognition failed: ${e.message}", null)
        }
        val w = bitmap.width.toFloat()
        val h = bitmap.height.toFloat()
        val out = mutableListOf<OcrBlock>()
        for (block in vision.textBlocks) {
            val rect = block.boundingBox ?: continue
            val text = block.text.trim()
            if (text.isEmpty()) continue
            out.add(
                OcrBlock(
                    text = text,
                    pageIndex = pageIndex.toLong(),
                    left = (rect.left / w).toDouble().coerceIn(0.0, 1.0),
                    top = (rect.top / h).toDouble().coerceIn(0.0, 1.0),
                    right = (rect.right / w).toDouble().coerceIn(0.0, 1.0),
                    bottom = (rect.bottom / h).toDouble().coerceIn(0.0, 1.0),
                )
            )
        }
        return out
    }

    /// Decodes [uri] downsampled so its longest side is at most [maxDim].
    private fun decodeBitmap(uri: Uri, maxDim: Int): Bitmap? {
        val resolver = context.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            ?: return null
        var sample = 1
        val largest = maxOf(bounds.outWidth, bounds.outHeight)
        while (largest / sample > maxDim) sample *= 2
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
    }

    /// Keeps only characters the standard Helvetica encoding can show;
    /// anything else becomes a space so showText never throws.
    private fun winAnsiSafe(text: String): String {
        val sb = StringBuilder(text.length)
        for (ch in text) {
            when {
                ch == '\n' || ch == '\r' || ch == '\t' -> sb.append(' ')
                ch.code in 0x20..0xFF -> sb.append(ch)
                else -> sb.append(' ')
            }
        }
        return sb.toString()
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
        private const val OCR_DPI = 150f
        private const val MAX_OCR_DIMENSION = 2000
    }
}
