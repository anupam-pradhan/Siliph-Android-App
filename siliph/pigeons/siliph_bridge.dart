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

/// A decoded QR code or barcode.
class BarcodeResult {
  BarcodeResult({required this.rawValue, required this.format});

  String rawValue;
  String format;
}

/// One recognized text block. Bounds are normalized (0..1) against the
/// source image; [pageIndex] is the zero-based PDF page it came from (0
/// for single-image OCR).
class OcrBlock {
  OcrBlock({
    required this.text,
    required this.pageIndex,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  String text;
  int pageIndex;
  double left;
  double top;
  double right;
  double bottom;
}

/// One AcroForm field discovered in a PDF (section 217 forms gate).
///
/// [type] is 'text', 'checkbox', 'radio', 'choice', 'button',
/// 'signature' or 'other'. [options] lists the export values for
/// choice/radio fields; [value] is the current value ('' when empty).
class FormField {
  FormField({
    required this.name,
    required this.type,
    required this.value,
    required this.options,
    required this.readOnly,
  });

  String name;
  String type;
  String value;
  List<String> options;
  bool readOnly;
}

/// A new value for one AcroForm field. Text fields take [value] as-is;
/// checkboxes/radios take the option's export value ('' unchecks).
class FormFieldValue {
  FormFieldValue({required this.name, required this.value});

  String name;
  String value;
}

/// Extracted text of one PDF page, for in-reader search.
class PageText {
  PageText({required this.pageIndex, required this.text});

  int pageIndex;
  String text;
}

/// A freehand ink stroke drawn on a rendered page. [points] are flattened
/// normalized x,y pairs; [colorRgb] is 0xRRGGBB; [width] is a fraction of
/// the page's shortest side.
class InkStroke {
  InkStroke({
    required this.points,
    required this.colorRgb,
    required this.width,
  });

  List<double> points;
  int colorRgb;
  double width;
}

/// A rectangle mark on a rendered page (highlight or outline box),
/// normalized 0..1 against the rendered page.
class RectMark {
  RectMark({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.colorRgb,
    required this.mode,
  });

  double left;
  double top;
  double right;
  double bottom;
  int colorRgb;
  String mode; // 'highlight' | 'box'
}

/// A redaction rectangle on one page, normalized 0..1.
class RedactionMark {
  RedactionMark({
    required this.pageIndex,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  int pageIndex; // zero-based
  double left;
  double top;
  double right;
  double bottom;
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

  /// Launches the system camera app (ACTION_IMAGE_CAPTURE). The shot is
  /// stored in app-owned storage and delivered through
  /// [FileResultsApi.onCameraResult] (null when the user cancels). No
  /// camera permission is needed because the camera app does the capture.
  void requestTakePhoto();

  /// App-owned cache workspace for intermediate files (section 5 boundary).
  String tempDirectory();

  /// File Siliph was launched with via VIEW/SEND (section 45), or null.
  /// Consumes the launch payload: subsequent calls return null. New
  /// intents on a running instance arrive via
  /// [FileResultsApi.onIncomingFile].
  FileMeta? getLaunchFile();
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

  /// Renders the zero-based [pageIndex] of [uri] at [dpi] and delivers the
  /// JPEG bytes through [TaskEventsApi.onImageResult] before
  /// [TaskEventsApi.onComplete]. Throws `invalid_input` when the page index
  /// is out of range.
  void startRenderPage(String uri, int pageIndex, int dpi, String taskId);

  /// Stamps the image at [imageUri] onto one-based [pageNumber] of [uri].
  /// [x]/[y] are the top-left position normalized 0..1 against the
  /// rendered page; [widthFraction] is the stamp width relative to the
  /// page width, height follows the image's aspect ratio. The original
  /// content stays intact: the stamp is a new image object on top.
  void startStampImage(
    String uri,
    String imageUri,
    int pageNumber,
    double x,
    double y,
    double widthFraction,
    String outputUri,
    String taskId,
  );

  /// Draws freehand [strokes] and rectangle [rects] (normalized against
  /// the rendered page) directly into one-based [pageNumber]'s content
  /// stream, so the page's original text stays selectable.
  void startAnnotate(
    String uri,
    int pageNumber,
    List<InkStroke> strokes,
    List<RectMark> rects,
    String outputUri,
    String taskId,
  );

  /// Permanently removes content under each [marks] rectangle: affected
  /// pages are re-rendered, the rectangles burned in as black, and the
  /// page replaced by that image. Pages without marks are copied
  /// unchanged.
  void startRedact(
    String uri,
    List<RedactionMark> marks,
    String outputUri,
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

  /// Inserts every page of [insertUri] into [uri] after one-based
  /// [afterPage] (0 inserts before the first page).
  void startInsertPages(
    String uri,
    String insertUri,
    int afterPage,
    String outputUri,
    String taskId,
  );

  /// Replaces pages of [uri] starting at one-based [startPage] with every
  /// page of [replaceUri]. Pages before [startPage] survive; pages after
  /// the replaced run survive too.
  void startReplacePages(
    String uri,
    String replaceUri,
    int startPage,
    String outputUri,
    String taskId,
  );

  /// Extracts the text of every page with PDFTextStripper; pages arrive
  /// through [TaskEventsApi.onTextResult] before [TaskEventsApi.onComplete].
  void startExtractText(String uri, String taskId);

  /// Lists the AcroForm fields of [uri]; empty list when the document has
  /// no form. Encrypted PDFs report `invalid_pdf`.
  List<FormField> listFormFields(String uri);

  /// Writes [values] into the AcroForm fields of [uri] and regenerates
  /// appearances; unknown field names are skipped, not fatal.
  void startFillForm(
    String uri,
    List<FormFieldValue> values,
    String outputUri,
    String taskId,
  );

  /// Flattens the AcroForm of [uri]: field values are baked into the
  /// page content and the interactive form removed.
  void startFlattenForm(String uri, String outputUri, String taskId);

  /// Stamps the image at [imageUri] on every page (image watermark);
  /// [position]: `diagonal`, `bottom`, `top`; [widthFraction] is the
  /// stamp width relative to the page width.
  void startWatermarkImage(
    String uri,
    String imageUri,
    String position,
    double widthFraction,
    String outputUri,
    String taskId,
  );

  /// Encrypts the output with [password] (user + owner).
  void startProtect(String uri, String password, String outputUri, String taskId);

  /// Overlays page numbers on every page of [uri].
  /// [position]: `bottom-center`, `bottom-right`, `top-center`, `top-right`.
  /// [format]: `page_x_of_y`, `x`, `dash_x_dash`. [startPage]: starting number (usually 1).
  void startAddPageNumbers(
    String uri,
    String position,
    String format,
    int startPage,
    String outputUri,
    String taskId,
  );

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

  /// Decodes the first QR code / barcode found in the image at [uri].
  /// The result arrives through [TaskEventsApi.onBarcodeResult] before
  /// [TaskEventsApi.onComplete]; when nothing decodes, rawValue is empty.
  void startScanBarcode(String uri, String taskId);

  /// Lists the direct children of [folderUri] (pass the tree URI itself
  /// for the tree root) as FileMeta entries, folders first then files,
  /// each sorted by display name. Throws `not_found` for an unreadable
  /// tree, `not_supported` when the provider cannot list children.
  List<FileMeta> listFolder(String treeUri, String folderUri);

  /// Walks [treeUri] recursively and reports every file whose display
  /// name contains [query] (case-insensitive) through
  /// [TaskEventsApi.onSearchResult] before completion. Caps the result
  /// set so hostile trees cannot flood the channel.
  void startSearchFiles(String treeUri, String query, String taskId);

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

  /// Rotates [uri] clockwise by [degrees] (90, 180 or 270) and saves JPEG.
  void startRotateImage(String uri, int degrees, String outputUri, String taskId);

  /// Flips [uri] horizontally (mirror) or vertically and saves JPEG.
  void startFlipImage(
    String uri,
    bool horizontal,
    String outputUri,
    String taskId,
  );

  /// Suggests the four corners of the dominant document in [uri] as
  /// normalized TLx,TLy,TRx,TRy,BRx,BRy,BLx,BLy (0..1). Returns an empty
  /// list when no convincing document outline is found. Synchronous
  /// because detection runs on a small downscaled copy.
  List<double> detectDocumentCorners(String uri);

  /// Warps the quadrilateral given by [corners] (8 normalized values:
  /// TL, TR, BR, BL) into a rectangle and saves JPEG — perspective
  /// correction for scanned pages.
  void startPerspectiveCrop(
    String uri,
    List<double> corners,
    String outputUri,
    String taskId,
  );

  /// Scanner enhancement pass (section 20). [mode]: 'color' (contrast +
  /// sharpen), 'grayscale', 'bw' (adaptive threshold) or 'magic'
  /// (grayscale + contrast + sharpen). Saves JPEG.
  void startEnhanceImage(String uri, String mode, String outputUri, String taskId);

  /// Writes small app-generated PNG bytes (e.g. a drawn signature) to
  /// [uri]. Not for bulk file content: callers cap the payload.
  void writeImageBytes(String uri, Uint8List png);

  /// Requests cancellation of a running task. Safe when unknown.
  void cancel(String taskId);
}

/// On-device text recognition backed by the bundled ML Kit recognizer.
///
/// All operations report blocks through [TaskEventsApi.onOcrResult] before
/// [TaskEventsApi.onComplete]; progress events track multi-page work.
@HostApi()
abstract class OcrApi {
  /// Recognizes text in the image at [uri]; blocks carry pageIndex 0.
  /// [language]: 'latin', 'devanagari' (Hindi) or 'bengali'.
  void startRecognizeImage(String uri, String language, String taskId);

  /// Renders every page of the PDF at [uri] and recognizes each one;
  /// blocks carry their zero-based page index. [language] as above.
  void startRecognizePdf(String uri, String language, String taskId);

  /// Builds a searchable copy of [uri] at [outputUri]: each page becomes
  /// its rendered image plus an invisible text layer from OCR. Text
  /// selection on the output is approximate. [language] as above.
  void startSearchablePdf(String uri, String language, String outputUri, String taskId);

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

  /// Result of a system-camera capture; null when cancelled.
  void onCameraResult(FileMeta? file);

  /// A file another app handed to Siliph while it was already running
  /// (VIEW/SEND intents, section 45).
  void onIncomingFile(FileMeta? file);
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

  /// Rendered page image (JPEG bytes) for single-page render tasks
  /// (reader / annotate / redact / sign previews). Delivered before
  /// [onComplete].
  void onImageResult(String taskId, Uint8List bytes);

  /// Decoded QR/barcode for scan tasks. Delivered before [onComplete].
  void onBarcodeResult(String taskId, BarcodeResult result);

  /// Recognized text blocks for OCR tasks. Delivered before [onComplete].
  void onOcrResult(String taskId, List<OcrBlock> blocks);

  /// Extracted per-page text for extract-text tasks (reader search).
  /// Delivered before [onComplete].
  void onTextResult(String taskId, List<PageText> pages);

  /// Matching files for folder-search tasks. Delivered before
  /// [onComplete].
  void onSearchResult(String taskId, List<FileMeta> files);
}
