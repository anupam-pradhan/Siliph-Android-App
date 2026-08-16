package com.siliph.siliph.bridge

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.multipdf.PDFMergerUtility
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.PDDocumentInformation
import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.pdmodel.PDPageContentStream
import com.tom_roush.pdfbox.pdmodel.common.PDRectangle
import com.tom_roush.pdfbox.pdmodel.encryption.AccessPermission
import com.tom_roush.pdfbox.pdmodel.encryption.InvalidPasswordException
import com.tom_roush.pdfbox.pdmodel.encryption.StandardProtectionPolicy
import com.tom_roush.pdfbox.pdmodel.font.PDType1Font
import com.tom_roush.pdfbox.pdmodel.graphics.image.PDImageXObject
import com.tom_roush.pdfbox.rendering.ImageType
import com.tom_roush.pdfbox.rendering.PDFRenderer
import com.tom_roush.pdfbox.util.Matrix
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Native PDF engine boundary (master prompt sections 5, 192).
 *
 * The merge implementation is adapted from Karna14314/Pdf_Tools
 * (Apache-2.0), file domain/operations/PdfMerger.kt at commit
 * bb4125bf89852527af4b74ace91c71fc87b8d7f3: coroutines were replaced by a
 * single worker executor + cancellation flags because pigeon-generated
 * Kotlin handlers reply synchronously on the platform thread. See
 * docs/reuse-records.md for the full source modification record.
 *
 * Only URIs cross the channel; bytes stay in the native layer.
 */
class PdfBridge(
    private val context: Context,
    private val events: TaskEventsApi,
) : PdfApi {

    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "siliph-pdf-worker")
    }
    private val cancellations = ConcurrentHashMap<String, AtomicBoolean>()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun inspect(uri: String): PdfInfo {
        val parsed = Uri.parse(uri)
        try {
            context.contentResolver.openInputStream(parsed)?.use { input ->
                PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly())
                    .use { document ->
                        return PdfInfo(
                            uri = uri,
                            pageCount = document.numberOfPages.toLong(),
                            encrypted = document.isEncrypted,
                        )
                    }
            }
            throw FlutterError("not_found", "Cannot open $uri", null)
        } catch (e: FlutterError) {
            throw e
        } catch (e: IOException) {
            throw FlutterError("invalid_pdf", "Not a readable PDF: ${e.message}", null)
        } catch (e: Exception) {
            throw FlutterError("io_error", e.message ?: "Inspect failed", null)
        }
    }

    override fun startMerge(inputUris: List<String>, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runMerge(inputUris, outputUri, taskId, cancelled)
        }
    }

    override fun startRearrangePages(
        uri: String,
        pageOrder: List<Long>,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            runRearrange(uri, pageOrder, outputUri, taskId, cancelled)
        }
    }

    override fun startRotatePages(
        uri: String,
        firstPage: Long,
        lastPage: Long,
        rotationDelta: Long,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            runRotate(uri, firstPage, lastPage, rotationDelta, outputUri, taskId, cancelled)
        }
    }

    override fun readMetadata(uri: String): PdfMetadata {
        val parsed = Uri.parse(uri)
        try {
            context.contentResolver.openInputStream(parsed)?.use { input ->
                PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly())
                    .use { document ->
                        val info = document.documentInformation
                        return PdfMetadata(
                            title = info.title,
                            author = info.author,
                            subject = info.subject,
                            keywords = info.keywords,
                            creator = info.creator,
                            producer = info.producer,
                        )
                    }
            }
            throw FlutterError("not_found", "Cannot open $uri", null)
        } catch (e: FlutterError) {
            throw e
        } catch (e: IOException) {
            throw FlutterError("invalid_pdf", "Not a readable PDF: ${e.message}", null)
        } catch (e: Exception) {
            throw FlutterError("io_error", e.message ?: "Metadata read failed", null)
        }
    }

    override fun startWriteMetadata(
        uri: String,
        metadata: PdfMetadata,
        removeAll: Boolean,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            runWriteMetadata(uri, metadata, removeAll, outputUri, taskId, cancelled)
        }
    }

    override fun startCompress(uri: String, level: Long, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runCompress(uri, level.toInt(), outputUri, taskId, cancelled)
        }
    }

    override fun startImagesToPdf(imageUris: List<String>, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runImagesToPdf(imageUris, outputUri, taskId, cancelled)
        }
    }

    override fun startPdfToImages(
        uri: String,
        dpi: Long,
        folderTreeUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            runPdfToImages(uri, dpi.toInt(), folderTreeUri, taskId, cancelled)
        }
    }

    override fun startWatermark(
        uri: String,
        text: String,
        position: String,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            runWatermark(uri, text, position, outputUri, taskId, cancelled)
        }
    }

    override fun startProtect(uri: String, password: String, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runProtect(uri, password, outputUri, taskId, cancelled)
        }
    }

    override fun startUnlock(uri: String, password: String, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runUnlock(uri, password, outputUri, taskId, cancelled)
        }
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

    private fun runMerge(
        inputUris: List<String>,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("merge")
        if (inputUris.size < 2) {
            throw FlutterError("invalid_input", "At least 2 PDFs are required", null)
        }

        val resolver = context.contentResolver
        val merger = PDFMergerUtility()
        val destination = PDDocument()
        try {
            inputUris.forEachIndexed { index, raw ->
                checkCancellation(cancelled)
                val uri = Uri.parse(raw)
                resolver.openInputStream(uri)?.use { input ->
                    PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly())
                        .use { source ->
                            merger.appendDocument(destination, source)
                        }
                } ?: throw FlutterError("not_found", "Cannot open file: $raw", null)
                postProgress(taskId, (index + 1).toDouble() / (inputUris.size + 1))
            }
            checkCancellation(cancelled)
            resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                destination.save(out)
            } ?: throw FlutterError("io_error", "Cannot write output", null)
            postProgress(taskId, 1.0)
        } finally {
            try {
                destination.close()
            } catch (ignored: Exception) {
                // Cleanup only.
            }
        }
    }

    private fun runRearrange(
        uri: String,
        pageOrder: List<Long>,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("rearrange")
        if (pageOrder.isEmpty()) {
            throw FlutterError("invalid_input", "No pages selected", null)
        }

        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        val source = resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly())
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)

        // importPage shares source resources, so [source] must stay open
        // until the destination is saved.
        val destination = PDDocument()
        try {
            val pageCount = source.numberOfPages
            pageOrder.forEachIndexed { index, raw ->
                checkCancellation(cancelled)
                val pageIndex = raw.toInt()
                if (pageIndex < 0 || pageIndex >= pageCount) {
                    throw FlutterError("invalid_input", "Page out of range: $raw", null)
                }
                destination.importPage(source.getPage(pageIndex))
                postProgress(taskId, (index + 1).toDouble() / (pageOrder.size + 1))
            }
            checkCancellation(cancelled)
            resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                destination.save(out)
            } ?: throw FlutterError("io_error", "Cannot write output", null)
            postProgress(taskId, 1.0)
        } finally {
            try {
                destination.close()
            } catch (ignored: Exception) {
                // Cleanup only.
            }
            try {
                source.close()
            } catch (ignored: Exception) {
                // Cleanup only.
            }
        }
    }

    private fun runRotate(
        uri: String,
        firstPage: Long,
        lastPage: Long,
        rotationDelta: Long,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("rotate")
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly()).use { doc ->
                val pageCount = doc.numberOfPages
                val first = firstPage.toInt()
                val last = lastPage.toInt()
                if (first < 1 || last > pageCount || first > last) {
                    throw FlutterError("invalid_input", "Page range out of bounds", null)
                }
                val steps = last - first + 1
                for (i in first..last) {
                    checkCancellation(cancelled)
                    val page = doc.getPage(i - 1)
                    page.rotation = ((page.rotation + rotationDelta.toInt()) % 360 + 360) % 360
                    postProgress(taskId, (i - first + 1).toDouble() / (steps + 1))
                }
                checkCancellation(cancelled)
                resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                    doc.save(out)
                } ?: throw FlutterError("io_error", "Cannot write output", null)
                postProgress(taskId, 1.0)
            }
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
    }

    private fun runWriteMetadata(
        uri: String,
        metadata: PdfMetadata,
        removeAll: Boolean,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("write-metadata")
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly()).use { doc ->
                checkCancellation(cancelled)
                if (removeAll) {
                    doc.documentInformation = PDDocumentInformation()
                } else {
                    val info = doc.documentInformation
                    info.title = metadata.title
                    info.author = metadata.author
                    info.subject = metadata.subject
                    info.keywords = metadata.keywords
                    info.creator = metadata.creator
                    info.producer = metadata.producer
                }
                resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                    doc.save(out)
                } ?: throw FlutterError("io_error", "Cannot write output", null)
                postProgress(taskId, 1.0)
            }
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
    }

    /// Honest rasterized compression: render each page, re-encode as JPEG,
    /// rebuild. Output pages become images (text non-selectable).
    private fun runCompress(
        uri: String,
        level: Int,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("compress")
        val (dpi, quality) = when (level) {
            0 -> 150 to 80
            1 -> 110 to 65
            else -> 80 to 45
        }
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        val source = resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly())
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)

        val destination = PDDocument()
        val temp = File(context.cacheDir, "siliph-compress-$taskId.jpg")
        try {
            val renderer = PDFRenderer(source)
            val pageCount = source.numberOfPages
            for (index in 0 until pageCount) {
                checkCancellation(cancelled)
                val bitmap = renderer.renderImageWithDPI(index, dpi.toFloat(), ImageType.RGB)
                FileOutputStream(temp).use { out ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
                }
                bitmap.recycle()
                val xobject = PDImageXObject.createFromFileByExtension(temp, destination)
                val page = PDPage(
                    PDRectangle(xobject.width.toFloat(), xobject.height.toFloat())
                )
                destination.addPage(page)
                PDPageContentStream(destination, page).use { stream ->
                    stream.drawImage(
                        xobject, 0f, 0f,
                        xobject.width.toFloat(), xobject.height.toFloat(),
                    )
                }
                postProgress(taskId, (index + 1).toDouble() / (pageCount + 1))
            }
            checkCancellation(cancelled)
            resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                destination.save(out)
            } ?: throw FlutterError("io_error", "Cannot write output", null)
            postProgress(taskId, 1.0)
        } finally {
            temp.delete()
            try {
                destination.close()
            } catch (ignored: Exception) {
                // Cleanup only.
            }
            try {
                source.close()
            } catch (ignored: Exception) {
                // Cleanup only.
            }
        }
    }

    private fun runImagesToPdf(
        imageUris: List<String>,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("images-to-pdf")
        if (imageUris.isEmpty()) {
            throw FlutterError("invalid_input", "At least one image is required", null)
        }
        val resolver = context.contentResolver
        val doc = PDDocument()
        val temps = mutableListOf<File>()
        try {
            imageUris.forEachIndexed { index, raw ->
                checkCancellation(cancelled)
                val temp = stageImage(Uri.parse(raw), index)
                temps.add(temp)
                val xobject = PDImageXObject.createFromFileByExtension(temp, doc)
                val page = PDPage(
                    PDRectangle(xobject.width.toFloat(), xobject.height.toFloat())
                )
                doc.addPage(page)
                PDPageContentStream(doc, page).use { stream ->
                    stream.drawImage(
                        xobject, 0f, 0f,
                        xobject.width.toFloat(), xobject.height.toFloat(),
                    )
                }
                postProgress(taskId, (index + 1).toDouble() / (imageUris.size + 1))
            }
            checkCancellation(cancelled)
            resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                doc.save(out)
            } ?: throw FlutterError("io_error", "Cannot write output", null)
            postProgress(taskId, 1.0)
        } finally {
            temps.forEach { it.delete() }
            try {
                doc.close()
            } catch (ignored: Exception) {
                // Cleanup only.
            }
        }
    }

    /// Copies an image URI to a cache file with a real extension so the
    /// PDF engine can embed it; unknown formats are decoded and re-encoded
    /// as PNG.
    private fun stageImage(uri: Uri, index: Int): File {
        val resolver = context.contentResolver
        val mime = (resolver.getType(uri) ?: "").lowercase()
        val ext = when {
            mime.contains("jpeg") || mime.contains("jpg") -> "jpg"
            mime.contains("png") -> "png"
            else -> ""
        }
        if (ext.isNotEmpty()) {
            val temp = File(context.cacheDir, "siliph-img-$index.$ext")
            resolver.openInputStream(uri)?.use { input ->
                FileOutputStream(temp).use { out -> input.copyTo(out) }
            } ?: throw FlutterError("not_found", "Cannot open image: $uri", null)
            return temp
        }
        val temp = File(context.cacheDir, "siliph-img-$index.png")
        val bitmap = resolver.openInputStream(uri)?.use { input ->
            BitmapFactory.decodeStream(input)
        } ?: throw FlutterError(
            "invalid_input", "Unsupported image: $uri", null
        )
        FileOutputStream(temp).use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
        bitmap.recycle()
        return temp
    }

    private fun runPdfToImages(
        uri: String,
        dpi: Int,
        folderTreeUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("pdf-to-images")
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        val base = displayNameFor(parsed)
            .lowercase()
            .removeSuffix(".pdf")
            .ifEmpty { "document" }
        resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly()).use { doc ->
                val renderer = PDFRenderer(doc)
                val treeUri = Uri.parse(folderTreeUri)
                val created = mutableListOf<String>()
                val pageCount = doc.numberOfPages
                for (index in 0 until pageCount) {
                    checkCancellation(cancelled)
                    val bitmap = renderer.renderImageWithDPI(index, dpi.toFloat(), ImageType.RGB)
                    val name = "$base-page-${index + 1}.png"
                    val docUri = DocumentsContract.createDocument(
                        resolver, treeUri, "image/png", name
                    ) ?: throw FlutterError("io_error", "Could not create $name", null)
                    resolver.openOutputStream(docUri)?.use { out ->
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                    } ?: throw FlutterError("io_error", "Cannot write $name", null)
                    bitmap.recycle()
                    created.add(docUri.toString())
                    postProgress(taskId, (index + 1).toDouble() / pageCount)
                }
                postEvent { events.onFilesResult(taskId, created) {} }
            }
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
    }

    private fun runWatermark(
        uri: String,
        text: String,
        position: String,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("watermark")
        val stamp = text.trim()
        if (stamp.isEmpty()) {
            throw FlutterError("invalid_input", "Watermark text is empty", null)
        }
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly()).use { doc ->
                val pageCount = doc.numberOfPages
                for (index in 0 until pageCount) {
                    checkCancellation(cancelled)
                    val page = doc.getPage(index)
                    val box = page.mediaBox
                    val fontSize = if (position == "diagonal") box.width / 18 else 12f
                    val approxWidth = fontSize * stamp.length * 0.5f
                    PDPageContentStream(
                        doc, page, PDPageContentStream.AppendMode.APPEND, true, true
                    ).use { stream ->
                        stream.setFont(PDType1Font.HELVETICA_BOLD, fontSize)
                        stream.setNonStrokingColor(0.45f, 0.45f, 0.45f)
                        stream.beginText()
                        when (position) {
                            "top" -> stream.setTextMatrix(
                                Matrix.getTranslateInstance(
                                    (box.width - approxWidth) / 2,
                                    box.height - fontSize - 12,
                                )
                            )
                            "bottom" -> stream.setTextMatrix(
                                Matrix.getTranslateInstance(
                                    (box.width - approxWidth) / 2, 12f
                                )
                            )
                            else -> stream.setTextMatrix(
                                Matrix.getRotateInstance(
                                    Math.toRadians(45.0),
                                    (box.width - approxWidth) / 2,
                                    box.height / 3,
                                )
                            )
                        }
                        stream.showText(stamp)
                        stream.endText()
                    }
                    postProgress(taskId, (index + 1).toDouble() / (pageCount + 1))
                }
                checkCancellation(cancelled)
                resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                    doc.save(out)
                } ?: throw FlutterError("io_error", "Cannot write output", null)
                postProgress(taskId, 1.0)
            }
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
    }

    private fun runProtect(
        uri: String,
        password: String,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("protect")
        if (password.isEmpty()) {
            throw FlutterError("invalid_input", "Password is empty", null)
        }
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly()).use { doc ->
                checkCancellation(cancelled)
                doc.protect(StandardProtectionPolicy(password, password, AccessPermission()))
                resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                    doc.save(out)
                } ?: throw FlutterError("io_error", "Cannot write output", null)
                postProgress(taskId, 1.0)
            }
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
    }

    private fun runUnlock(
        uri: String,
        password: String,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("unlock")
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        val doc = try {
            resolver.openInputStream(parsed)?.use { input ->
                PDDocument.load(input, password, MemoryUsageSetting.setupTempFileOnly())
            }
        } catch (e: InvalidPasswordException) {
            throw FlutterError("invalid_input", "Wrong password", null)
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
        doc.use {
            checkCancellation(cancelled)
            it.setAllSecurityToBeRemoved(true)
            resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                it.save(out)
            } ?: throw FlutterError("io_error", "Cannot write output", null)
            postProgress(taskId, 1.0)
        }
    }

    /// Display name for output naming; empty when unreadable.
    private fun displayNameFor(uri: Uri): String {
        return try {
            context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (cursor.moveToFirst() && index >= 0 && !cursor.isNull(index)) {
                    cursor.getString(index) ?: ""
                } else {
                    ""
                }
            } ?: ""
        } catch (e: Exception) {
            ""
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
            else -> "invalid_pdf" to (e.message ?: "Processing failed")
        }
    }

    private fun postProgress(taskId: String, fraction: Double) {
        postEvent { events.onProgress(taskId, fraction) {} }
    }

    private fun postEvent(action: () -> Unit) {
        mainHandler.post(action)
    }
}
