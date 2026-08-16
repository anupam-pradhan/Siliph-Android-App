package com.siliph.siliph.bridge

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * SAF + Photo Picker file intake/export (master prompt sections 60, 180).
 *
 * Picker calls launch system UIs and resolve through [FileResultsApi];
 * nothing here blocks the platform thread. No broad storage permissions
 * are requested: SAF grants per-document URIs and the Photo Picker needs
 * no permission at all.
 *
 * FlutterActivity extends plain [Activity] (not androidx ComponentActivity),
 * so pickers use classic request codes routed through [handleActivityResult].
 */
class FileAccessBridge(
    private val activity: FlutterActivity,
    private val results: FileResultsApi,
) : FileAccessApi {

    override fun requestOpenDocuments(mimeTypes: List<String>) {
        val types = mimeTypes.ifEmpty { listOf("*/*") }.toTypedArray()
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = if (types.size == 1) types[0] else "*/*"
            if (types.size > 1) putExtra(Intent.EXTRA_MIME_TYPES, types)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        }
        activity.startActivityForResult(intent, REQ_OPEN_DOCUMENTS)
    }

    override fun requestPickImages(maxItems: Long) {
        val capped = maxItems.toInt().coerceIn(1, MAX_IMAGES)
        val intent = if (Build.VERSION.SDK_INT >= 33) {
            // System Photo Picker: no storage permission needed.
            Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                if (capped > 1) {
                    putExtra(
                        MediaStore.EXTRA_PICK_IMAGES_MAX,
                        capped.coerceAtMost(MediaStore.getPickImagesMaxLimit()),
                    )
                }
            }
        } else {
            // Pre-33 fallback without broad storage permissions.
            Intent(Intent.ACTION_GET_CONTENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "image/*"
                if (capped > 1) putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }
        }
        activity.startActivityForResult(intent, REQ_PICK_IMAGES)
    }

    override fun requestCreateDocument(mimeType: String, displayName: String) {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, displayName)
        }
        activity.startActivityForResult(intent, REQ_CREATE_DOCUMENT)
    }

    override fun requestPickFolder() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        }
        activity.startActivityForResult(intent, REQ_PICK_FOLDER)
    }

    override fun getMetadata(uri: String): FileMeta {
        return metaFor(Uri.parse(uri))
            ?: throw FlutterError("not_found", "Cannot read metadata for $uri", null)
    }

    override fun renameDocument(uri: String, newDisplayName: String): FileMeta {
        val name = newDisplayName.trim()
        if (name.isEmpty() || name.contains('/') || name.contains('\u0000')) {
            throw FlutterError("invalid_input", "Invalid file name", null)
        }
        val parsed = Uri.parse(uri)
        val renamed = try {
            DocumentsContract.renameDocument(activity.contentResolver, parsed, name)
        } catch (e: Exception) {
            throw FlutterError("io_error", e.message ?: "Rename failed", null)
        }
        if (renamed == null) {
            // Providers return null when rename is unsupported or refused.
            throw FlutterError(
                "not_supported",
                "This file cannot be renamed from Siliph",
                null,
            )
        }
        if (renamed != parsed) {
            // Some providers issue a fresh URI after rename; persist again.
            persistPermissions(renamed)
        }
        return metaFor(renamed)
            ?: throw FlutterError("not_found", "Renamed file is unreadable", null)
    }

    override fun deleteDocument(uri: String): Boolean {
        return try {
            DocumentsContract.deleteDocument(activity.contentResolver, Uri.parse(uri))
        } catch (e: Exception) {
            throw FlutterError("io_error", e.message ?: "Delete failed", null)
        }
    }

    override fun copyDocument(uri: String, targetTreeUri: String): FileMeta {
        val copied = try {
            DocumentsContract.copyDocument(
                activity.contentResolver, Uri.parse(uri), Uri.parse(targetTreeUri)
            )
        } catch (e: Exception) {
            throw FlutterError("io_error", e.message ?: "Copy failed", null)
        }
        if (copied == null) {
            throw FlutterError(
                "not_supported",
                "This provider cannot copy the file from Siliph",
                null,
            )
        }
        persistPermissions(copied)
        return metaFor(copied)
            ?: throw FlutterError("not_found", "Copied file is unreadable", null)
    }

    override fun moveDocument(uri: String, targetTreeUri: String): FileMeta {
        val resolver = activity.contentResolver
        val docUri = Uri.parse(uri)
        val parentUri = try {
            parentOf(docUri) ?: throw FlutterError(
                "not_supported",
                "This provider cannot move the file from Siliph. " +
                    "Copy it instead, then delete the original.",
                null,
            )
        } catch (e: FlutterError) {
            throw e
        } catch (e: Exception) {
            throw FlutterError(
                "not_supported",
                "This provider cannot move the file from Siliph. " +
                    "Copy it instead, then delete the original.",
                null,
            )
        }
        val moved = try {
            DocumentsContract.moveDocument(
                resolver, docUri, parentUri, Uri.parse(targetTreeUri)
            )
        } catch (e: Exception) {
            throw FlutterError("io_error", e.message ?: "Move failed", null)
        }
        if (moved == null) {
            throw FlutterError(
                "not_supported",
                "This provider refused the move. Copy it instead, " +
                    "then delete the original.",
                null,
            )
        }
        persistPermissions(moved)
        return metaFor(moved)
            ?: throw FlutterError("not_found", "Moved file is unreadable", null)
    }

    override fun shareDocument(uri: String, mimeType: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType.ifEmpty { "*/*" }
            putExtra(Intent.EXTRA_STREAM, Uri.parse(uri))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(intent, null))
    }

    override fun releasePersistablePermission(uri: String): Boolean {
        return try {
            activity.contentResolver.releasePersistableUriPermission(
                Uri.parse(uri), Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
            true
        } catch (e: SecurityException) {
            false
        }
    }

    override fun requestTakePhoto() {
        val dir = File(activity.cacheDir, "captures")
        if (!dir.exists() && !dir.mkdirs()) {
            throw FlutterError("io_error", "Cannot prepare capture storage", null)
        }
        val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
        val target = File(dir, "capture-$stamp.jpg")
        val shared = FileProvider.getUriForFile(
            activity, "${activity.packageName}.fileprovider", target
        )
        pendingCaptureFile = target
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, shared)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        if (intent.resolveActivity(activity.packageManager) == null) {
            pendingCaptureFile = null
            throw FlutterError(
                "not_supported", "No camera app is available on this device", null
            )
        }
        activity.startActivityForResult(intent, REQ_TAKE_PHOTO)
    }

    override fun tempDirectory(): String {
        val dir = File(activity.cacheDir, "workspace")
        if (!dir.exists() && !dir.mkdirs()) {
            throw FlutterError("io_error", "Cannot create temp workspace", null)
        }
        return dir.absolutePath
    }

    /** Forwards onActivityResult from [com.siliph.siliph.MainActivity]. */
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            REQ_OPEN_DOCUMENTS -> {
                val uris = extractUris(resultCode, data)
                val files = uris.mapNotNull { uri ->
                    persistPermissions(uri)
                    metaFor(uri)
                }
                results.onOpenResult(files) {}
            }
            REQ_PICK_IMAGES -> {
                val files = extractUris(resultCode, data).mapNotNull { metaFor(it) }
                results.onPickImagesResult(files) {}
            }
            REQ_CREATE_DOCUMENT -> {
                val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
                results.onCreateDocumentResult(uri?.let { metaFor(it) }) {}
            }
            REQ_PICK_FOLDER -> {
                val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
                if (uri != null) persistPermissions(uri)
                results.onPickFolderResult(uri?.toString()) {}
            }
            REQ_TAKE_PHOTO -> {
                val target = pendingCaptureFile
                pendingCaptureFile = null
                if (resultCode != Activity.RESULT_OK || target == null) {
                    target?.delete()
                    results.onCameraResult(null) {}
                    return
                }
                // Most cameras honor EXTRA_OUTPUT; a few return the shot
                // in the result instead — copy that stream into our file.
                if (!target.exists() || target.length() == 0L) {
                    val returned = data?.data
                    if (returned != null) {
                        try {
                            activity.contentResolver.openInputStream(returned)
                                ?.use { input ->
                                    target.outputStream().use { input.copyTo(it) }
                                }
                        } catch (e: Exception) {
                            Log.w(TAG, "Camera result copy failed", e)
                        }
                    }
                }
                if (!target.exists() || target.length() == 0L) {
                    target.delete()
                    results.onCameraResult(null) {}
                    return
                }
                val uri = FileProvider.getUriForFile(
                    activity, "${activity.packageName}.fileprovider", target
                )
                results.onCameraResult(metaFor(uri)) {}
            }
        }
    }

    private fun extractUris(resultCode: Int, data: Intent?): List<Uri> {
        if (resultCode != Activity.RESULT_OK || data == null) return emptyList()
        val single = data.data
        if (single != null) return listOf(single)
        val clip = data.clipData ?: return emptyList()
        return (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri }
    }

    private var pendingCaptureFile: File? = null

    /// Resolves the parent document URI of [docUri] via findDocumentPath.
    /// Returns null when the provider cannot describe the path.
    private fun parentOf(docUri: Uri): Uri? {
        if (Build.VERSION.SDK_INT < 26) return null
        val path = DocumentsContract.findDocumentPath(
            activity.contentResolver, docUri
        ) ?: return null
        val ids = path.path
        if (ids == null || ids.size < 2) return null
        // Path runs root -> ... -> doc; the parent is second to last.
        val parentId = ids[ids.size - 2]
        return Uri.Builder()
            .scheme("content")
            .authority(docUri.authority)
            .appendPath("document")
            .appendPath(parentId)
            .build()
    }

    private fun persistPermissions(uri: Uri) {
        val resolver = activity.contentResolver
        try {
            // Prefer read + write (needed for rename/delete later).
            resolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (e: SecurityException) {
            try {
                resolver.takePersistableUriPermission(
                    uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            } catch (e2: SecurityException) {
                // Photo Picker / provider URIs may not support persistence;
                // the in-process grant still covers immediate use.
                Log.d(TAG, "Persistable permission unavailable for $uri")
            }
        }
    }

    private fun metaFor(uri: Uri): FileMeta? {
        val resolver = activity.contentResolver
        return try {
            var displayName = uri.lastPathSegment ?: "file"
            var sizeBytes = -1L
            resolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (cursor.moveToFirst()) {
                    if (nameIndex >= 0 && !cursor.isNull(nameIndex)) {
                        displayName = cursor.getString(nameIndex)
                    }
                    if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                        sizeBytes = cursor.getLong(sizeIndex)
                    }
                }
            }
            FileMeta(
                uri = uri.toString(),
                displayName = displayName,
                mimeType = resolver.getType(uri),
                sizeBytes = sizeBytes,
                lastModifiedMillis = lastModifiedFor(uri),
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read metadata for $uri", e)
            null
        }
    }

    /// Last-modified timestamp from the documents provider; 0 when unknown.
    private fun lastModifiedFor(uri: Uri): Long {
        return try {
            activity.contentResolver.query(
                uri,
                arrayOf(DocumentsContract.Document.COLUMN_LAST_MODIFIED),
                null, null, null,
            )?.use { cursor ->
                if (cursor.moveToFirst() && !cursor.isNull(0)) {
                    cursor.getLong(0)
                } else {
                    0L
                }
            } ?: 0L
        } catch (e: Exception) {
            0L
        }
    }

    companion object {
        private const val TAG = "FileAccessBridge"
        private const val MAX_IMAGES = 10
        private const val REQ_OPEN_DOCUMENTS = 4101
        private const val REQ_PICK_IMAGES = 4102
        private const val REQ_CREATE_DOCUMENT = 4103
        private const val REQ_PICK_FOLDER = 4104
        private const val REQ_TAKE_PHOTO = 4105
    }
}
