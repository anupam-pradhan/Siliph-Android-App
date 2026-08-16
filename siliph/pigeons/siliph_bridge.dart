/// Siliph native bridge schema (master prompt sections 5, 60, 180).
///
/// Regenerate with:
///   dart run pigeon --input pigeons/siliph_bridge.dart
///
/// Design rules honored here:
/// - Small, versionable typed APIs.
/// - Only URIs and metadata cross the channel; never binary payloads.
/// - Anything that waits on an Activity result or long processing is
///   request + event based (Kotlin generated handlers reply synchronously
///   on the platform thread, so they must never block):
///   Dart calls `requestX` / `startX`, Kotlin replies with events through
///   [FileResultsApi] / [TaskEventsApi].
/// - Typed error codes: `cancelled`, `invalid_pdf`, `io_error`, `not_found`,
///   `picker_unavailable`.
library;

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'siliph',
    dartOut: 'lib/generated/siliph_bridge.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/siliph/siliph/bridge/SiliphBridge.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.siliph.siliph.bridge'),
  ),
)

/// Metadata for a document addressed by a content URI.
///
/// [sizeBytes] is -1 when unknown; [lastModifiedMillis] is 0 when unknown.
class FileMeta {
  FileMeta({
    required this.uri,
    required this.displayName,
    this.mimeType,
    this.sizeBytes = -1,
    this.lastModifiedMillis = 0,
  });

  String uri;
  String displayName;
  String? mimeType;
  int sizeBytes;
  int lastModifiedMillis;
}

/// Lightweight PDF inspection result.
class PdfInfo {
  PdfInfo({
    required this.uri,
    required this.pageCount,
    required this.encrypted,
  });

  String uri;
  int pageCount;
  bool encrypted;
}

/// Editable document-information fields (section 15).
class PdfMetadata {
  PdfMetadata({
    this.title,
    this.author,
    this.subject,
    this.keywords,
    this.creator,
    this.producer,
  });

  String? title;
  String? author;
  String? subject;
  String? keywords;
  String? creator;
  String? producer;
}

/// One group of byte-identical files discovered by the duplicate finder.
class DuplicateGroup {
  DuplicateGroup({required this.sizeBytes, required this.uris});

  int sizeBytes;
  List<String> uris;
}

/// Size breakdown entry reported by the storage analyzer.
class StorageEntry {
  StorageEntry({
    required this.name,
    required this.uri,
    required this.sizeBytes,
    required this.fileCount,
    required this.folder,
  });

  String name;
  String uri;
  int sizeBytes;
  int fileCount;
  bool folder;
}

/// Image inspection result (named to avoid clashing with Flutter's own
/// ImageInfo). [format] is 'jpeg', 'png', 'webp' or 'unknown'.
class ImageFacts {
  ImageFacts({
    required this.width,
    required this.height,
    required this.format,
    this.sizeBytes = -1,
  });

  int width;
  int height;
  String format;
  int sizeBytes;
}

/// SAF / Photo Picker file intake and export (sections 60, 180).
///
/// Picker methods launch a system UI and resolve through [FileResultsApi];
/// they never block the platform thread.
@HostApi()
abstract class FileAccessApi {
  /// ACTION_OPEN_DOCUMENT with multi-select; result via
  /// [FileResultsApi.onOpenResult] (empty list when the user cancels).
  void requestOpenDocuments(List<String> mimeTypes);

  /// Android Photo Picker; result via [FileResultsApi.onPickImagesResult].
  void requestPickImages(int maxItems);

  /// ACTION_CREATE_DOCUMENT; result via [FileResultsApi.onCreateDocumentResult].
  void requestCreateDocument(String mimeType, String displayName);

  /// Metadata for a previously picked/created URI.
  FileMeta getMetadata(String uri);

  /// Renames the SAF document at [uri] (section 34) and returns its fresh
  /// metadata. Throws FlutterError `not_supported` when the provider
  /// refuses the rename, `invalid_input` for an unusable name.
  FileMeta renameDocument(String uri, String newDisplayName);

  /// Deletes the SAF document at [uri] (section 34). Returns true when the
  /// provider confirms deletion. Destructive and irreversible.
  bool deleteDocument(String uri);

  /// ACTION_OPEN_DOCUMENT_TREE; result via
  /// [FileResultsApi.onPickFolderResult] (null when the user cancels).
  void requestPickFolder();

  /// Copies [uri] into the tree picked via [requestPickFolder] and returns
  /// the new document's metadata. Throws `not_supported` when the provider
  /// refuses.
  FileMeta copyDocument(String uri, String targetTreeUri);

  /// Moves [uri] into the target tree. The source parent is resolved with
  /// DocumentsContract.findDocumentPath; throws `not_supported` when the
  /// provider cannot provide it.
  FileMeta moveDocument(String uri, String targetTreeUri);

  /// Launches the system share sheet for the document.
  void shareDocument(String uri, String mimeType);

  /// Releases a persisted URI permission we no longer need.
  bool releasePersistablePermission(String uri);

  /// App-owned cache workspace for intermediate files (section 5 boundary).
  String tempDirectory();
}

/// PDF operations backed by the native engine (sections 5, 192).
@HostApi()
abstract class PdfApi {
  /// Page count + encryption flag. Throws FlutterError `invalid_pdf` or
  /// `io_error` on failure.
  PdfInfo inspect(String uri);

  /// Starts merging [inputUris] in order into [outputUri] on a worker
  /// thread. Progress/completion/cancellation arrive through [TaskEventsApi].
  void startMerge(List<String> inputUris, String outputUri, String taskId);

  /// Rebuilds [uri] keeping only the zero-based pages in [pageOrder], in
  /// that order. Covers extract, delete, reorder, reverse and duplicate.
  void startRearrangePages(
    String uri,
    List<int> pageOrder,
    String outputUri,
    String taskId,
  );

  /// Adds [rotationDelta] degrees (typically 90/180/270) to the existing
  /// rotation of one-based pages [firstPage]..[lastPage] inclusive.
  void startRotatePages(
    String uri,
    int firstPage,
    int lastPage,
    int rotationDelta,
    String outputUri,
    String taskId,
  );

  /// Reads the document-information dictionary (section 15).
  PdfMetadata readMetadata(String uri);

  /// Writes [metadata] over the source info dictionary (or strips every
  /// field when [removeAll] is true) and saves a copy to [outputUri].
  void startWriteMetadata(
    String uri,
    PdfMetadata metadata,
    bool removeAll,
    String outputUri,
    String taskId,
  );

  /// Re-encodes [uri] at compression [level] (0 low, 1 medium, 2 high).
  /// Honest rasterized compression: pages are rendered, downscaled and
  /// rebuilt, so text becomes non-selectable in the output.
  void startCompress(String uri, int level, String outputUri, String taskId);

  /// Builds a new PDF from the picked images, one image per page, in order.
  void startImagesToPdf(List<String> imageUris, String outputUri, String taskId);

  /// Renders every page of [uri] at [dpi] and saves one PNG per page into
  /// the SAF tree [folderTreeUri]. Created file URIs arrive through
  /// [TaskEventsApi.onFilesResult] before [TaskEventsApi.onComplete].
  void startPdfToImages(
    String uri,
    int dpi,
    String folderTreeUri,
    String taskId,
  );

  /// Overlays [text] on every page. [position]: `diagonal`, `bottom`,
  /// `top`.
  void startWatermark(
    String uri,
    String text,
    String position,
    String outputUri,
    String taskId,
  );

  /// Encrypts the output with [password] (user + owner).
  void startProtect(String uri, String password, String outputUri, String taskId);

  /// Decrypts [uri] using [password] and saves an unencrypted copy.
  /// Throws `invalid_input` for a wrong password.
  void startUnlock(String uri, String password, String outputUri, String taskId);

  /// Requests cancellation of a running task. Safe when unknown.
  void cancel(String taskId);
}

/// File utilities built on platform APIs only (ZIP, QR, folder analysis).
///
/// Long-running work follows the same request + event contract as [PdfApi];
/// results beyond the negotiated output arrive through [TaskEventsApi].
@HostApi()
abstract class FileToolsApi {
  /// Streams the picked files into a ZIP archive at [outputUri].
  void startZipCreate(List<String> inputUris, String outputUri, String taskId);

  /// Extracts [zipUri] into the SAF tree [folderTreeUri]. Created file
  /// URIs arrive through [TaskEventsApi.onFilesResult] before
  /// [TaskEventsApi.onComplete]. Unsafe entry names (path traversal,
  /// absolute paths) are skipped rather than written.
  void startZipExtract(String zipUri, String folderTreeUri, String taskId);

  /// Hashes every file under [folderTreeUri] and reports groups of two or
  /// more byte-identical files through [TaskEventsApi.onDuplicatesResult]
  /// before completion.
  void startFindDuplicates(String folderTreeUri, String taskId);

  /// Walks [folderTreeUri] and reports each top-level child's total size
  /// through [TaskEventsApi.onStorageResult] before completion.
  void startAnalyzeStorage(String folderTreeUri, String taskId);

  /// Renders [content] as a QR code PNG into [outputUri]. [ecLevel]:
  /// 0 low, 1 medium, 2 quartile, 3 high. Synchronous because generation
  /// is fast; throws `invalid_input` when the content is empty or too long.
  void generateQr(String content, int ecLevel, String outputUri);

  /// Requests cancellation of a running task. Safe when unknown.
  void cancel(String taskId);
}

/// Image tools built on platform BitmapFactory/Bitmap APIs only.
///
/// Every op re-encodes the image, so EXIF metadata never survives into the
/// output. Progress/completion/cancellation follow the same request + event
/// contract as [PdfApi] and [FileToolsApi].
@HostApi()
abstract class ImageToolsApi {
  /// Dimensions + format of the image at [uri]. Throws `invalid_input`
  /// when the document is not a decodable image.
  ImageFacts inspectImage(String uri);

  /// Re-encodes [uri] as [format] ('jpeg' or 'webp') at [quality] 1..100.
  void startCompressImage(
    String uri,
    String format,
    int quality,
    String outputUri,
    String taskId,
  );

  /// Binary-searches JPEG quality so the output is at or under [targetKb]
  /// kilobytes; when quality alone cannot reach the target the image is
  /// also downscaled. Throws `invalid_input` for a target below 10 KB.
  void startCompressToKb(String uri, int targetKb, String outputUri, String taskId);

  /// Scales [uri] to [width]x[height] pixels (both >= 1) and saves JPEG.
  void startResizeImage(
    String uri,
    int width,
    int height,
    String outputUri,
    String taskId,
  );

  /// Crops the pixel rectangle ([left],[top],[width],[height]) out of
  /// [uri] and saves it as JPEG. Throws `invalid_input` when the rectangle
  /// leaves the image bounds.
  void startCropImage(
    String uri,
    int left,
    int top,
    int width,
    int height,
    String outputUri,
    String taskId,
  );

  /// Converts [uri] to [format]: 'jpeg', 'png' or 'webp'.
  void startConvertImage(String uri, String format, String outputUri, String taskId);

  /// Re-encodes [uri] as JPEG so no EXIF/GPS metadata survives.
  void startStripExif(String uri, String outputUri, String taskId);

  /// Composes a printable 4×6 inch passport sheet (1200×1800 px, 300 dpi)
  /// from [uri]: the photo is centre-cropped to 3:4, scaled to 413×531 px
  /// (35×45 mm) and tiled [copies] times (1..6) with light cut guides.
  void startPassportSheet(String uri, int copies, String outputUri, String taskId);

  /// Writes small app-generated PNG bytes (e.g. a drawn signature) to
  /// [uri]. Not for bulk file content: callers cap the payload.
  void writeImageBytes(String uri, Uint8List png);

  /// Requests cancellation of a running task. Safe when unknown.
  void cancel(String taskId);
}

/// Native -> Flutter results for picker requests.
@FlutterApi()
abstract class FileResultsApi {
  void onOpenResult(List<FileMeta> files);
  void onPickImagesResult(List<FileMeta> files);
  void onCreateDocumentResult(FileMeta? file);
  void onPickFolderResult(String? treeUri);
}

/// Native -> Flutter events for long-running tasks keyed by taskId.
@FlutterApi()
abstract class TaskEventsApi {
  void onProgress(String taskId, double fraction);
  void onComplete(String taskId);
  void onError(String taskId, String code, String message);

  /// Result URIs for tasks that create multiple files (e.g. PDF pages
  /// rendered to images). Delivered before [onComplete].
  void onFilesResult(String taskId, List<String> uris);

  /// Duplicate groups for find-duplicates tasks. Delivered before
  /// [onComplete].
  void onDuplicatesResult(String taskId, List<DuplicateGroup> groups);

  /// Storage breakdown for analyzer tasks. Delivered before [onComplete].
  void onStorageResult(String taskId, List<StorageEntry> entries);
}
