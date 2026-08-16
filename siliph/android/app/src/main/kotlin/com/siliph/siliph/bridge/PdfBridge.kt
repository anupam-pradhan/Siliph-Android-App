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
import com.tom_roush.pdfbox.pdmodel.graphics.state.PDExtendedGraphicsState
import com.tom_roush.pdfbox.pdmodel.interactive.form.PDCheckBox
import com.tom_roush.pdfbox.pdmodel.interactive.form.PDChoice
import com.tom_roush.pdfbox.pdmodel.interactive.form.PDComboBox
import com.tom_roush.pdfbox.pdmodel.interactive.form.PDListBox
import com.tom_roush.pdfbox.pdmodel.interactive.form.PDRadioButton
import com.tom_roush.pdfbox.pdmodel.interactive.form.PDSignatureField
import com.tom_roush.pdfbox.pdmodel.interactive.form.PDTextField
import com.tom_roush.pdfbox.rendering.ImageType
import com.tom_roush.pdfbox.rendering.PDFRenderer
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.util.Matrix
import java.io.ByteArrayOutputStream
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

    override fun startInsertPages(
        uri: String,
        insertUri: String,
        afterPage: Long,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            runInsertPages(uri, insertUri, afterPage.toInt(), outputUri, taskId, cancelled)
        }
    }

    override fun startReplacePages(
        uri: String,
        replaceUri: String,
        startPage: Long,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            runReplacePages(uri, replaceUri, startPage.toInt(), outputUri, taskId, cancelled)
        }
    }

    override fun startExtractText(uri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runExtractText(uri, taskId, cancelled)
        }
    }

    override fun listFormFields(uri: String): List<FormField> {
        val parsed = Uri.parse(uri)
        try {
            context.contentResolver.openInputStream(parsed)?.use { input ->
                PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly())
                    .use { document ->
                        if (document.isEncrypted) {
                            throw FlutterError(
                                "invalid_pdf", "PDF is password protected", null
                            )
                        }
                        val acroForm = document.documentCatalog.acroForm
                            ?: return emptyList()
                        return acroForm.fields.map { field ->
                            val type = when (field) {
                                is PDTextField -> "text"
                                is PDCheckBox -> "checkbox"
                                is PDRadioButton -> "radio"
                                is PDComboBox -> "choice"
                                is PDListBox -> "choice"
                                is PDSignatureField -> "signature"
                                else -> "other"
                            }
                            val options = (field as? PDChoice)?.options ?: emptyList()
                            FormField(
                                name = field.fullyQualifiedName ?: field.partialName ?: "",
                                type = type,
                                value = try {
                                    field.value ?: ""
                                } catch (e: Exception) {
                                    ""
                                },
                                options = options,
                                readOnly = field.isReadOnly,
                            )
                        }
                    }
            }
            throw FlutterError("not_found", "Cannot open $uri", null)
        } catch (e: FlutterError) {
            throw e
        } catch (e: IOException) {
            throw FlutterError("invalid_pdf", "Not a readable PDF: ${e.message}", null)
        } catch (e: Exception) {
            throw FlutterError("io_error", e.message ?: "Form read failed", null)
        }
    }

    override fun startFillForm(
        uri: String,
        values: List<FormFieldValue>,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            runFillForm(uri, values, outputUri, taskId, cancelled)
        }
    }

    override fun startFlattenForm(uri: String, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runFlattenForm(uri, outputUri, taskId, cancelled)
        }
    }

    override fun startWatermarkImage(
        uri: String,
        imageUri: String,
        position: String,
        widthFraction: Double,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            runWatermarkImage(
                uri, imageUri, position, widthFraction.toFloat(),
                outputUri, taskId, cancelled,
            )
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

    override fun startRenderPage(uri: String, pageIndex: Long, dpi: Long, taskId: String) {
        runTask(taskId) { cancelled ->
            runRenderPage(uri, pageIndex.toInt(), dpi.toInt(), taskId, cancelled)
        }
    }

    override fun startStampImage(
        uri: String,
        imageUri: String,
        pageNumber: Long,
        x: Double,
        y: Double,
        widthFraction: Double,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            runStampImage(
                uri, imageUri, pageNumber.toInt(),
                x.toFloat(), y.toFloat(), widthFraction.toFloat(),
                outputUri, taskId, cancelled,
            )
        }
    }

    override fun startAnnotate(
        uri: String,
        pageNumber: Long,
        strokes: List<InkStroke>,
        rects: List<RectMark>,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            runAnnotate(uri, pageNumber.toInt(), strokes, rects, outputUri, taskId, cancelled)
        }
    }

    override fun startRedact(
        uri: String,
        marks: List<RedactionMark>,
        outputUri: String,
        taskId: String,
    ) {
        runTask(taskId) { cancelled ->
            runRedact(uri, marks, outputUri, taskId, cancelled)
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

    /// Rebuilds [uri] with every page of [insertUri] spliced in after
    /// one-based [afterPage] (0 = before the first page).
    private fun runInsertPages(
        uri: String,
        insertUri: String,
        afterPage: Int,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("insert-pages")
        val resolver = context.contentResolver
        val source = openDocument(uri)
        val insertDoc = try {
            openDocument(insertUri)
        } catch (e: Exception) {
            try { source.close() } catch (ignored: Exception) { }
            throw e
        }
        val destination = PDDocument()
        try {
            val pageCount = source.numberOfPages
            if (afterPage < 0 || afterPage > pageCount) {
                throw FlutterError("invalid_input", "Insert position out of range", null)
            }
            val insertCount = insertDoc.numberOfPages
            if (insertCount == 0) {
                throw FlutterError("invalid_input", "The insert source has no pages", null)
            }
            // importPage shares source resources, so both documents must
            // stay open until the destination is saved.
            val total = pageCount + insertCount
            var placed = 0
            for (index in 0 until pageCount) {
                checkCancellation(cancelled)
                if (index == afterPage) {
                    for (j in 0 until insertCount) {
                        destination.importPage(insertDoc.getPage(j))
                        placed++
                        postProgress(taskId, placed.toDouble() / (total + 1))
                    }
                }
                destination.importPage(source.getPage(index))
                placed++
                postProgress(taskId, placed.toDouble() / (total + 1))
            }
            if (afterPage == pageCount) {
                for (j in 0 until insertCount) {
                    checkCancellation(cancelled)
                    destination.importPage(insertDoc.getPage(j))
                    placed++
                    postProgress(taskId, placed.toDouble() / (total + 1))
                }
            }
            checkCancellation(cancelled)
            saveTo(resolver, destination, outputUri)
            postProgress(taskId, 1.0)
        } finally {
            closeQuietly(destination)
            closeQuietly(source)
            closeQuietly(insertDoc)
        }
    }

    /// Replaces pages of [uri] starting at one-based [startPage] with
    /// every page of [replaceUri]; the replacement run must fit inside
    /// the source document.
    private fun runReplacePages(
        uri: String,
        replaceUri: String,
        startPage: Int,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("replace-pages")
        val resolver = context.contentResolver
        val source = openDocument(uri)
        val replaceDoc = try {
            openDocument(replaceUri)
        } catch (e: Exception) {
            try { source.close() } catch (ignored: Exception) { }
            throw e
        }
        val destination = PDDocument()
        try {
            val pageCount = source.numberOfPages
            val replaceCount = replaceDoc.numberOfPages
            if (startPage < 1 || startPage > pageCount) {
                throw FlutterError("invalid_input", "Start page out of range", null)
            }
            if (replaceCount == 0) {
                throw FlutterError("invalid_input", "The replacement has no pages", null)
            }
            if (startPage + replaceCount - 1 > pageCount) {
                throw FlutterError(
                    "invalid_input",
                    "The replacement has more pages than the run it covers",
                    null,
                )
            }
            val total = pageCount
            var placed = 0
            for (index in 0 until pageCount) {
                checkCancellation(cancelled)
                when {
                    index < startPage - 1 -> destination.importPage(source.getPage(index))
                    index == startPage - 1 -> {
                        for (j in 0 until replaceCount) {
                            destination.importPage(replaceDoc.getPage(j))
                        }
                    }
                    index < startPage - 1 + replaceCount -> { /* replaced away */ }
                    else -> destination.importPage(source.getPage(index))
                }
                placed++
                postProgress(taskId, placed.toDouble() / (total + 1))
            }
            checkCancellation(cancelled)
            saveTo(resolver, destination, outputUri)
            postProgress(taskId, 1.0)
        } finally {
            closeQuietly(destination)
            closeQuietly(source)
            closeQuietly(replaceDoc)
        }
    }

    /// Extracts every page's text with PDFTextStripper and ships the list
    /// to Flutter, where the reader runs the actual search.
    private fun runExtractText(uri: String, taskId: String, cancelled: AtomicBoolean) {
        MemoryGuard.checkMemory("extract-text")
        val parsed = Uri.parse(uri)
        context.contentResolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly()).use { doc ->
                if (doc.isEncrypted) {
                    throw FlutterError("invalid_pdf", "PDF is password protected", null)
                }
                val stripper = PDFTextStripper()
                val pages = mutableListOf<PageText>()
                val pageCount = doc.numberOfPages
                for (index in 0 until pageCount) {
                    checkCancellation(cancelled)
                    stripper.startPage = index + 1
                    stripper.endPage = index + 1
                    pages.add(PageText(pageIndex = index.toLong(), text = stripper.getText(doc)))
                    postProgress(taskId, (index + 1).toDouble() / (pageCount + 1))
                }
                postEvent { events.onTextResult(taskId, pages) {} }
            }
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
    }

    /// Writes [values] into the AcroForm of [uri]; unknown names are
    /// skipped, and an empty intersection is reported honestly.
    private fun runFillForm(
        uri: String,
        values: List<FormFieldValue>,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("fill-form")
        if (values.isEmpty()) {
            throw FlutterError("invalid_input", "No field values supplied", null)
        }
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly()).use { doc ->
                if (doc.isEncrypted) {
                    throw FlutterError("invalid_pdf", "PDF is password protected", null)
                }
                checkCancellation(cancelled)
                val acroForm = doc.documentCatalog.acroForm
                    ?: throw FlutterError("invalid_input", "This PDF has no form fields", null)
                var applied = 0
                for (entry in values) {
                    val field = acroForm.getField(entry.name) ?: continue
                    try {
                        when (field) {
                            is PDCheckBox -> {
                                if (entry.value.isEmpty()) field.unCheck()
                                else field.setValue(entry.value)
                            }
                            is PDRadioButton -> field.setValue(entry.value)
                            is PDChoice -> field.setValue(listOf(entry.value))
                            is PDTextField -> field.setValue(entry.value)
                            else -> continue
                        }
                        applied++
                    } catch (ignored: Exception) {
                        // A field that refuses one value must not sink the
                        // whole fill; the count below reports what landed.
                    }
                }
                if (applied == 0) {
                    throw FlutterError(
                        "invalid_input", "None of the values matched a form field", null
                    )
                }
                acroForm.needAppearances = true
                resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                    doc.save(out)
                } ?: throw FlutterError("io_error", "Cannot write output", null)
                postProgress(taskId, 1.0)
            }
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
    }

    /// Bakes the AcroForm values into the page content and removes the
    /// interactive form (section 217 flatten gate).
    private fun runFlattenForm(
        uri: String,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("flatten-form")
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly()).use { doc ->
                if (doc.isEncrypted) {
                    throw FlutterError("invalid_pdf", "PDF is password protected", null)
                }
                checkCancellation(cancelled)
                val acroForm = doc.documentCatalog.acroForm
                    ?: throw FlutterError("invalid_input", "This PDF has no form fields", null)
                try {
                    acroForm.flatten()
                } catch (e: Exception) {
                    throw FlutterError(
                        "io_error", "Could not flatten this form: ${e.message}", null
                    )
                }
                resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                    doc.save(out)
                } ?: throw FlutterError("io_error", "Cannot write output", null)
                postProgress(taskId, 1.0)
            }
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
    }

    /// Image watermark: stamps one image on every page at half opacity.
    private fun runWatermarkImage(
        uri: String,
        imageUri: String,
        position: String,
        widthFraction: Float,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("watermark-image")
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        val source = resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly())
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
        val staged = stageImage(Uri.parse(imageUri), 0)
        try {
            val xobject = PDImageXObject.createFromFileByExtension(staged, source)
            val pageCount = source.numberOfPages
            val fraction = widthFraction.coerceIn(0.05f, 1f)
            for (index in 0 until pageCount) {
                checkCancellation(cancelled)
                val page = source.getPage(index)
                val rotation = ((page.rotation % 360) + 360) % 360
                val box = page.mediaBox
                val (renderW, renderH) = renderedSize(box, rotation)

                var stampW = fraction * renderW
                var stampH = stampW * xobject.height / xobject.width
                if (stampH > renderH * 0.9f) {
                    stampW = stampW * (renderH * 0.9f) / stampH
                    stampH = renderH * 0.9f
                }
                val (rx0, ry0) = when (position) {
                    "top" -> (renderW - stampW) / 2 to 12f
                    "bottom" -> (renderW - stampW) / 2 to (renderH - stampH - 12f)
                    else -> (renderW - stampW) / 2 to (renderH - stampH) / 2
                }

                PDPageContentStream(
                    source, page, PDPageContentStream.AppendMode.APPEND, true, true
                ).use { stream ->
                    val state = PDExtendedGraphicsState()
                    state.nonStrokingAlphaConstant = 0.5f
                    stream.setGraphicsStateParameters(state)
                    // Unit square -> render space (top-left origin, y down).
                    val unitToRender = Matrix(stampW, 0f, 0f, -stampH, rx0, ry0 + stampH)
                    var placement = unitToRender
                    if (position == "diagonal") {
                        // Rotate around the stamp centre in render space.
                        val cx = rx0 + stampW / 2
                        val cy = ry0 + stampH / 2
                        val cos = kotlin.math.cos(Math.toRadians(45.0)).toFloat()
                        val sin = kotlin.math.sin(Math.toRadians(45.0)).toFloat()
                        val rotate = Matrix(cos, sin, -sin, cos, cx - cx * cos + cy * sin, cy - cx * sin - cy * cos)
                        placement = unitToRender.multiply(rotate)
                    }
                    stream.transform(placement.multiply(renderToUser(rotation, box)))
                    stream.drawImage(xobject, 0f, 0f, 1f, 1f)
                    val solid = PDExtendedGraphicsState()
                    solid.nonStrokingAlphaConstant = 1f
                    stream.setGraphicsStateParameters(solid)
                }
                postProgress(taskId, (index + 1).toDouble() / (pageCount + 1))
            }
            checkCancellation(cancelled)
            saveTo(resolver, source, outputUri)
            postProgress(taskId, 1.0)
        } finally {
            staged.delete()
            closeQuietly(source)
        }
    }

    /// Loads a PDF from a content URI into a temp-file-backed document.
    private fun openDocument(uri: String): PDDocument {
        return context.contentResolver.openInputStream(Uri.parse(uri))?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly())
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
    }

    private fun saveTo(resolver: android.content.ContentResolver, doc: PDDocument, outputUri: String) {
        resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
            doc.save(out)
        } ?: throw FlutterError("io_error", "Cannot write output", null)
    }

    private fun closeQuietly(doc: PDDocument?) {
        try {
            doc?.close()
        } catch (ignored: Exception) {
            // Cleanup only.
        }
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

    /// Renders one zero-based page and ships the JPEG bytes to Flutter.
    private fun runRenderPage(
        uri: String,
        pageIndex: Int,
        dpi: Int,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("render-page")
        val clampedDpi = dpi.coerceIn(48, 300)
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly()).use { doc ->
                checkCancellation(cancelled)
                if (pageIndex < 0 || pageIndex >= doc.numberOfPages) {
                    throw FlutterError("invalid_input", "Page out of range", null)
                }
                val bitmap = PDFRenderer(doc).renderImageWithDPI(
                    pageIndex, clampedDpi.toFloat(), ImageType.RGB
                )
                val out = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
                bitmap.recycle()
                postEvent { events.onImageResult(taskId, out.toByteArray()) {} }
            }
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
    }

    /// Stamps [imageUri] onto one-based [pageNumber] at normalized (x, y)
    /// with [widthFraction] of the rendered page width.
    private fun runStampImage(
        uri: String,
        imageUri: String,
        pageNumber: Int,
        x: Float,
        y: Float,
        widthFraction: Float,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("stamp-image")
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        val source = resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly())
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
        val staged = stageImage(Uri.parse(imageUri), 0)
        try {
            val pageCount = source.numberOfPages
            if (pageNumber < 1 || pageNumber > pageCount) {
                throw FlutterError("invalid_input", "Page out of range", null)
            }
            checkCancellation(cancelled)
            val page = source.getPage(pageNumber - 1)
            val rotation = ((page.rotation % 360) + 360) % 360
            val box = page.mediaBox
            val (renderW, renderH) = renderedSize(box, rotation)

            val xobject = PDImageXObject.createFromFileByExtension(staged, source)
            var stampW = widthFraction.coerceIn(0.01f, 1f) * renderW
            val stampH = stampW * xobject.height / xobject.width
            // Keep the stamp fully on the page.
            if (stampH > renderH) {
                stampW = stampW * renderH / stampH
            }
            val clamped = clampedSize(stampW, stampH.coerceAtMost(renderH), renderW, renderH, x, y)
            val rx0 = clamped.first
            val ry0 = clamped.second
            val finalH = stampW * xobject.height / xobject.width

            PDPageContentStream(
                source, page, PDPageContentStream.AppendMode.APPEND, true, true
            ).use { stream ->
                // Map the image's unit square through render space (top-left
                // origin, y down) into PDF user space, honoring page rotation.
                val unitToRender = Matrix(
                    stampW, 0f, 0f, -finalH, rx0, ry0 + finalH
                )
                stream.transform(unitToRender.multiply(renderToUser(rotation, box)))
                stream.drawImage(xobject, 0f, 0f, 1f, 1f)
            }
            checkCancellation(cancelled)
            resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                source.save(out)
            } ?: throw FlutterError("io_error", "Cannot write output", null)
            postProgress(taskId, 1.0)
        } finally {
            staged.delete()
            try {
                source.close()
            } catch (ignored: Exception) {
                // Cleanup only.
            }
        }
    }

    /// Draws ink strokes and rectangle marks into one-based [pageNumber]'s
    /// content stream; coordinates are normalized against the rendered page.
    private fun runAnnotate(
        uri: String,
        pageNumber: Int,
        strokes: List<InkStroke>,
        rects: List<RectMark>,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("annotate")
        if (strokes.isEmpty() && rects.isEmpty()) {
            throw FlutterError("invalid_input", "Nothing to draw", null)
        }
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly()).use { doc ->
                val pageCount = doc.numberOfPages
                if (pageNumber < 1 || pageNumber > pageCount) {
                    throw FlutterError("invalid_input", "Page out of range", null)
                }
                checkCancellation(cancelled)
                val page = doc.getPage(pageNumber - 1)
                val rotation = ((page.rotation % 360) + 360) % 360
                val box = page.mediaBox
                val (renderW, renderH) = renderedSize(box, rotation)

                PDPageContentStream(
                    doc, page, PDPageContentStream.AppendMode.APPEND, true, true
                ).use { stream ->
                    stream.setLineCapStyle(1) // round caps
                    for (stroke in strokes) {
                        checkCancellation(cancelled)
                        if (stroke.points.size < 4) continue
                        val (r, g, b) = rgb(stroke.colorRgb.toInt())
                        stream.setStrokingColor(r, g, b)
                        stream.setLineWidth(
                            (stroke.width.toFloat() * minOf(renderW, renderH))
                                .coerceIn(0.5f, 40f)
                        )
                        var first = true
                        for (i in stroke.points.indices step 2) {
                            if (i + 1 >= stroke.points.size) break
                            val (ux, uy) = toUserSpace(
                                stroke.points[i].toFloat() * renderW,
                                stroke.points[i + 1].toFloat() * renderH,
                                rotation, box,
                            )
                            if (first) {
                                stream.moveTo(ux, uy)
                                first = false
                            } else {
                                stream.lineTo(ux, uy)
                            }
                        }
                        stream.stroke()
                    }
                    for (rect in rects) {
                        checkCancellation(cancelled)
                        val (r, g, b) = rgb(rect.colorRgb.toInt())
                        val corners = listOf(
                            toUserSpace(rect.left.toFloat() * renderW, rect.top.toFloat() * renderH, rotation, box),
                            toUserSpace(rect.right.toFloat() * renderW, rect.top.toFloat() * renderH, rotation, box),
                            toUserSpace(rect.right.toFloat() * renderW, rect.bottom.toFloat() * renderH, rotation, box),
                            toUserSpace(rect.left.toFloat() * renderW, rect.bottom.toFloat() * renderH, rotation, box),
                        )
                        val minX = corners.minOf { it.first }
                        val maxX = corners.maxOf { it.first }
                        val minY = corners.minOf { it.second }
                        val maxY = corners.maxOf { it.second }
                        if (rect.mode == "highlight") {
                            val state = PDExtendedGraphicsState()
                            state.nonStrokingAlphaConstant = 0.35f
                            stream.setGraphicsStateParameters(state)
                            stream.setNonStrokingColor(r, g, b)
                            stream.addRect(minX, minY, maxX - minX, maxY - minY)
                            stream.fill()
                            val solid = PDExtendedGraphicsState()
                            solid.nonStrokingAlphaConstant = 1f
                            stream.setGraphicsStateParameters(solid)
                        } else {
                            stream.setStrokingColor(r, g, b)
                            stream.setLineWidth(1.5f)
                            stream.addRect(minX, minY, maxX - minX, maxY - minY)
                            stream.stroke()
                        }
                    }
                }
                checkCancellation(cancelled)
                resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
                    doc.save(out)
                } ?: throw FlutterError("io_error", "Cannot write output", null)
                postProgress(taskId, 1.0)
            }
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)
    }

    /// True redaction: marked pages are re-rendered, the rectangles burned
    /// in as solid black, and the page replaced by that raster. Untouched
    /// pages are copied through unchanged.
    private fun runRedact(
        uri: String,
        marks: List<RedactionMark>,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("redact")
        if (marks.isEmpty()) {
            throw FlutterError("invalid_input", "No areas selected", null)
        }
        val resolver = context.contentResolver
        val parsed = Uri.parse(uri)
        val source = resolver.openInputStream(parsed)?.use { input ->
            PDDocument.load(input, MemoryUsageSetting.setupTempFileOnly())
        } ?: throw FlutterError("not_found", "Cannot open file: $uri", null)

        val destination = PDDocument()
        val temp = File(context.cacheDir, "siliph-redact-$taskId.jpg")
        try {
            val pageCount = source.numberOfPages
            val byPage = marks.groupBy { it.pageIndex.toInt() }
            val renderer = PDFRenderer(source)
            for (index in 0 until pageCount) {
                checkCancellation(cancelled)
                val pageMarks = byPage[index]
                if (pageMarks.isNullOrEmpty()) {
                    // importPage shares resources: source stays open till save.
                    destination.importPage(source.getPage(index))
                    postProgress(taskId, (index + 1).toDouble() / (pageCount + 1))
                    continue
                }
                val bitmap = renderer.renderImageWithDPI(index, 200f, ImageType.RGB)
                val canvas = Canvas(bitmap)
                val paint = Paint().apply { color = Color.BLACK }
                for (mark in pageMarks) {
                    val left = (mark.left.toFloat().coerceIn(0f, 1f)) * bitmap.width
                    val top = (mark.top.toFloat().coerceIn(0f, 1f)) * bitmap.height
                    val right = (mark.right.toFloat().coerceIn(0f, 1f)) * bitmap.width
                    val bottom = (mark.bottom.toFloat().coerceIn(0f, 1f)) * bitmap.height
                    canvas.drawRect(
                        minOf(left, right), minOf(top, bottom),
                        maxOf(left, right), maxOf(top, bottom), paint,
                    )
                }
                FileOutputStream(temp).use { out ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
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

    /// Rendered page size in points for a given /Rotate value.
    private fun renderedSize(box: PDRectangle, rotation: Int): Pair<Float, Float> {
        return if (rotation == 90 || rotation == 270) {
            box.height to box.width
        } else {
            box.width to box.height
        }
    }

    /// Maps a render-space point (top-left origin, y down, points) into PDF
    /// user space, honoring the page's /Rotate.
    private fun toUserSpace(
        rx: Float,
        ry: Float,
        rotation: Int,
        box: PDRectangle,
    ): Pair<Float, Float> {
        val w = box.width
        val h = box.height
        return when (rotation) {
            90 -> ry to rx
            180 -> (w - rx) to ry
            270 -> (w - ry) to (h - rx)
            else -> rx to (h - ry)
        }
    }

    /// Render-space -> user-space matrix (used for image stamps).
    private fun renderToUser(rotation: Int, box: PDRectangle): Matrix {
        val w = box.width
        val h = box.height
        return when (rotation) {
            90 -> Matrix(0f, 1f, 1f, 0f, 0f, 0f)
            180 -> Matrix(-1f, 0f, 0f, 1f, w, 0f)
            270 -> Matrix(0f, -1f, -1f, 0f, w, h)
            else -> Matrix(1f, 0f, 0f, -1f, 0f, h)
        }
    }

    /// Clamps a stamp's top-left so the whole stamp stays on the page.
    private fun clampedSize(
        stampW: Float,
        stampH: Float,
        renderW: Float,
        renderH: Float,
        x: Float,
        y: Float,
    ): Pair<Float, Float> {
        val rx = (x.coerceIn(0f, 1f) * renderW).coerceAtMost((renderW - stampW).coerceAtLeast(0f))
        val ry = (y.coerceIn(0f, 1f) * renderH).coerceAtMost((renderH - stampH).coerceAtLeast(0f))
        return rx to ry
    }

    private fun rgb(colorRgb: Int): Triple<Float, Float, Float> {
        return Triple(
            Color.red(colorRgb) / 255f,
            Color.green(colorRgb) / 255f,
            Color.blue(colorRgb) / 255f,
        )
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
