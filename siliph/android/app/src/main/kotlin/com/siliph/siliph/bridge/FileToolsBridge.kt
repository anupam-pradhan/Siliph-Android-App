package com.siliph.siliph.bridge

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

/**
 * File utilities built on platform APIs only (sections 5, 60): ZIP
 * create/extract via java.util.zip, QR generation on the bundled
 * [QrEncoder], duplicate finding by SHA-256 and storage analysis by SAF
 * tree walk. Same worker-executor + typed-event contract as [PdfBridge].
 */
class FileToolsBridge(
    private val context: Context,
    private val events: TaskEventsApi,
) : FileToolsApi {

    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "siliph-file-tools-worker")
    }
    private val cancellations = ConcurrentHashMap<String, AtomicBoolean>()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun startZipCreate(inputUris: List<String>, outputUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runZipCreate(inputUris, outputUri, taskId, cancelled)
        }
    }

    override fun startZipExtract(zipUri: String, folderTreeUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runZipExtract(zipUri, folderTreeUri, taskId, cancelled)
        }
    }

    override fun startFindDuplicates(folderTreeUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runFindDuplicates(folderTreeUri, taskId, cancelled)
        }
    }

    override fun startAnalyzeStorage(folderTreeUri: String, taskId: String) {
        runTask(taskId) { cancelled ->
            runAnalyzeStorage(folderTreeUri, taskId, cancelled)
        }
    }

    override fun generateQr(content: String, ecLevel: Long, outputUri: String) {
        val text = content.trim()
        if (text.isEmpty()) {
            throw FlutterError("invalid_input", "QR content is empty", null)
        }
        val ecl = when (ecLevel.toInt()) {
            0 -> QrEncoder.Ecc.LOW
            1 -> QrEncoder.Ecc.MEDIUM
            2 -> QrEncoder.Ecc.QUARTILE
            else -> QrEncoder.Ecc.HIGH
        }
        val matrix = try {
            QrEncoder.encode(text, ecl)
        } catch (e: QrEncoder.DataTooLongException) {
            throw FlutterError("invalid_input", "Content is too long for a QR code", null)
        }

        // 10 px per module with a 4-module quiet zone.
        val scale = 10
        val quiet = 4
        val dim = (matrix.size + quiet * 2) * scale
        val bitmap = Bitmap.createBitmap(dim, dim, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)
        val paint = Paint().apply { color = Color.BLACK }
        for (y in 0 until matrix.size) {
            for (x in 0 until matrix.size) {
                if (matrix.isDark(x, y)) {
                    val left = ((x + quiet) * scale).toFloat()
                    val top = ((y + quiet) * scale).toFloat()
                    canvas.drawRect(left, top, left + scale, top + scale, paint)
                }
            }
        }
        context.contentResolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        } ?: throw FlutterError("io_error", "Cannot write output", null)
        bitmap.recycle()
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

    private fun runZipCreate(
        inputUris: List<String>,
        outputUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("zip-create")
        if (inputUris.isEmpty()) {
            throw FlutterError("invalid_input", "No files selected", null)
        }
        val resolver = context.contentResolver
        val used = mutableSetOf<String>()
        resolver.openOutputStream(Uri.parse(outputUri))?.use { out ->
            ZipOutputStream(out).use { zip ->
                inputUris.forEachIndexed { index, raw ->
                    checkCancellation(cancelled)
                    val uri = Uri.parse(raw)
                    val base = displayNameFor(uri).ifEmpty { "file-${index + 1}" }
                    zip.putNextEntry(ZipEntry(uniqueName(base, used)))
                    resolver.openInputStream(uri)?.use { input -> input.copyTo(zip) }
                        ?: throw FlutterError("not_found", "Cannot open file: $raw", null)
                    zip.closeEntry()
                    postProgress(taskId, (index + 1).toDouble() / inputUris.size)
                }
            }
        } ?: throw FlutterError("io_error", "Cannot write output", null)
        postProgress(taskId, 1.0)
    }

    private fun runZipExtract(
        zipUri: String,
        folderTreeUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("zip-extract")
        val resolver = context.contentResolver
        // ZipFile needs random access, so stage the archive in cache first.
        val staged = File(context.cacheDir, "siliph-unzip-$taskId.zip")
        try {
            resolver.openInputStream(Uri.parse(zipUri))?.use { input ->
                FileOutputStream(staged).use { out -> input.copyTo(out) }
            } ?: throw FlutterError("not_found", "Cannot open file: $zipUri", null)

            val treeUri = Uri.parse(folderTreeUri)
            val created = mutableListOf<String>()
            val dirCache = HashMap<String, Uri>()
            ZipFile(staged).use { zip ->
                val total = maxOf(zip.size(), 1)
                val entries = zip.entries()
                var index = 0
                while (entries.hasMoreElements()) {
                    checkCancellation(cancelled)
                    val entry = entries.nextElement()
                    index++
                    val segments = sanitizeEntryPath(entry.name)
                    if (segments != null) {
                        if (entry.isDirectory) {
                            resolveDirectory(treeUri, segments, dirCache)
                        } else {
                            val parent = resolveDirectory(treeUri, segments.dropLast(1), dirCache)
                            val name = segments.last()
                            val docUri = DocumentsContract.createDocument(
                                resolver, parent, mimeFor(name), name
                            ) ?: throw FlutterError("io_error", "Could not create $name", null)
                            resolver.openOutputStream(docUri)?.use { out ->
                                zip.getInputStream(entry).use { input -> input.copyTo(out) }
                            } ?: throw FlutterError("io_error", "Cannot write $name", null)
                            created.add(docUri.toString())
                        }
                    }
                    postProgress(taskId, index.toDouble() / total)
                }
            }
            postEvent { events.onFilesResult(taskId, created) {} }
        } finally {
            staged.delete()
        }
    }

    private fun runFindDuplicates(
        folderTreeUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("duplicate-finder")
        val treeUri = Uri.parse(folderTreeUri)

        // Pass 1: collect every file in the tree.
        val files = mutableListOf<DocEntry>()
        val pending = ArrayDeque<String>()
        pending.addLast(DocumentsContract.getTreeDocumentId(treeUri))
        while (pending.isNotEmpty()) {
            checkCancellation(cancelled)
            for (child in queryChildren(treeUri, pending.removeLast())) {
                if (child.isDir) {
                    pending.addLast(DocumentsContract.getDocumentId(child.uri))
                } else {
                    files.add(child)
                    if (files.size > MAX_SCAN_FILES) {
                        throw FlutterError(
                            "invalid_input",
                            "This folder has more than $MAX_SCAN_FILES files; " +
                                "scan a smaller folder instead.",
                            null,
                        )
                    }
                }
            }
        }
        postProgress(taskId, 0.2)

        // Pass 2: hash only files that share a size with another file.
        val candidates = files.groupBy { it.size }.values
            .filter { it.size >= 2 }
            .flatten()
        val digest = MessageDigest.getInstance("SHA-256")
        val resolver = context.contentResolver
        val byHash = HashMap<String, MutableList<DocEntry>>()
        candidates.forEachIndexed { index, entry ->
            checkCancellation(cancelled)
            digest.reset()
            if (hashInto(resolver.openInputStream(entry.uri), digest)) {
                val key = digest.digest().joinToString(separator = "") { "%02x".format(it) }
                byHash.getOrPut(key) { mutableListOf() }.add(entry)
            }
            postProgress(taskId, 0.2 + 0.8 * (index + 1) / candidates.size)
        }

        val groups = byHash.values
            .filter { it.size >= 2 }
            .map { group ->
                DuplicateGroup(
                    sizeBytes = group.first().size,
                    uris = group.map { it.uri.toString() },
                )
            }
            .sortedByDescending { it.sizeBytes }
        postEvent { events.onDuplicatesResult(taskId, groups) {} }
        postProgress(taskId, 1.0)
    }

    private fun runAnalyzeStorage(
        folderTreeUri: String,
        taskId: String,
        cancelled: AtomicBoolean,
    ) {
        MemoryGuard.checkMemory("storage-analyzer")
        val treeUri = Uri.parse(folderTreeUri)
        val children = queryChildren(treeUri, DocumentsContract.getTreeDocumentId(treeUri))
        val entries = mutableListOf<StorageEntry>()
        children.forEachIndexed { index, child ->
            checkCancellation(cancelled)
            if (child.isDir) {
                var totalSize = 0L
                var totalCount = 0L
                val pending = ArrayDeque<String>()
                pending.addLast(DocumentsContract.getDocumentId(child.uri))
                while (pending.isNotEmpty()) {
                    checkCancellation(cancelled)
                    for (descendant in queryChildren(treeUri, pending.removeLast())) {
                        if (descendant.isDir) {
                            pending.addLast(DocumentsContract.getDocumentId(descendant.uri))
                        } else {
                            totalSize += descendant.size
                            totalCount++
                        }
                    }
                }
                entries.add(
                    StorageEntry(
                        name = child.name,
                        uri = child.uri.toString(),
                        sizeBytes = totalSize,
                        fileCount = totalCount,
                        folder = true,
                    )
                )
            } else {
                entries.add(
                    StorageEntry(
                        name = child.name,
                        uri = child.uri.toString(),
                        sizeBytes = child.size,
                        fileCount = 1L,
                        folder = false,
                    )
                )
            }
            postProgress(taskId, (index + 1).toDouble() / maxOf(children.size, 1))
        }
        val top = entries.sortedByDescending { it.sizeBytes }.take(MAX_ANALYZED_ENTRIES)
        postEvent { events.onStorageResult(taskId, top) {} }
    }

    /// Children of a directory document inside [treeUri]; unreadable
    /// directories resolve to an empty list rather than failing the scan.
    private fun queryChildren(treeUri: Uri, parentDocId: String): List<DocEntry> {
        val resolver = context.contentResolver
        val childrenUri =
            DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocId)
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
        )
        val out = mutableListOf<DocEntry>()
        try {
            resolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
                val idCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val nameCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val mimeCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
                val sizeCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
                if (idCol < 0) return out
                while (cursor.moveToNext()) {
                    val docId = cursor.getString(idCol) ?: continue
                    val mime = if (mimeCol >= 0) cursor.getString(mimeCol) ?: "" else ""
                    val isDir = mime == DocumentsContract.Document.MIME_TYPE_DIR
                    val size = if (!isDir && sizeCol >= 0 && !cursor.isNull(sizeCol)) {
                        cursor.getLong(sizeCol)
                    } else {
                        0L
                    }
                    val name = if (nameCol >= 0) cursor.getString(nameCol) ?: docId else docId
                    out.add(
                        DocEntry(
                            uri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId),
                            name = name,
                            size = size,
                            isDir = isDir,
                        )
                    )
                }
            }
        } catch (e: Exception) {
            // Some providers throw on unreadable children; skip them honestly.
        }
        return out
    }

    /// Walks [segments] under [treeUri], creating missing directories, and
    /// returns the deepest directory URI. Cached per normalized path.
    private fun resolveDirectory(
        treeUri: Uri,
        segments: List<String>,
        cache: MutableMap<String, Uri>,
    ): Uri {
        var parent = treeUri
        var path = ""
        for (segment in segments) {
            path = if (path.isEmpty()) segment else "$path/$segment"
            val cached = cache[path]
            if (cached != null) {
                parent = cached
                continue
            }
            val created = DocumentsContract.createDocument(
                context.contentResolver, parent,
                DocumentsContract.Document.MIME_TYPE_DIR, segment,
            ) ?: throw FlutterError("io_error", "Could not create folder $segment", null)
            cache[path] = created
            parent = created
        }
        return parent
    }

    /// Entry name -> safe path segments, or null when the entry must be
    /// skipped (absolute paths, traversal, empty names).
    private fun sanitizeEntryPath(raw: String): List<String>? {
        val normalized = raw.replace('\\', '/')
        val segments = normalized.split('/').filter { it.isNotEmpty() && it != "." }
        if (segments.isEmpty()) return null
        if (segments.any { it == ".." }) return null
        return segments
    }

    private fun mimeFor(name: String): String {
        val ext = name.substringAfterLast('.', "")
        if (ext.isNotEmpty()) {
            MimeTypeMap.getSingleton()
                .getMimeTypeFromExtension(ext.lowercase())
                ?.let { return it }
        }
        return "application/octet-stream"
    }

    private fun uniqueName(name: String, used: MutableSet<String>): String {
        if (used.add(name)) return name
        val dot = name.lastIndexOf('.')
        val base = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var counter = 2
        while (true) {
            val candidate = "$base ($counter)$ext"
            if (used.add(candidate)) return candidate
            counter++
        }
    }

    /// Streams [input] into [digest]; false when the stream is null.
    private fun hashInto(input: InputStream?, digest: MessageDigest): Boolean {
        input?.use { stream ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = stream.read(buffer)
                if (read <= 0) break
                digest.update(buffer, 0, read)
            }
            return true
        }
        return false
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
            else -> "io_error" to (e.message ?: "Processing failed")
        }
    }

    private fun postProgress(taskId: String, fraction: Double) {
        postEvent { events.onProgress(taskId, fraction) {} }
    }

    private fun postEvent(action: () -> Unit) {
        mainHandler.post(action)
    }

    private data class DocEntry(
        val uri: Uri,
        val name: String,
        val size: Long,
        val isDir: Boolean,
    )

    companion object {
        private const val MAX_SCAN_FILES = 30_000
        private const val MAX_ANALYZED_ENTRIES = 50
    }
}
