/// Dart boundary for the typed native bridge (sections 5, 180).
///
/// Pigeon-generated host handlers reply synchronously, so anything async
/// (pickers, long processing) is request + event based: Dart fires a
/// `requestX`/`startX`, and this layer routes the matching
/// [FileResultsApi]/[TaskEventsApi] events back to waiting consumers.
///
/// Gateways are abstract ([FileGateway], [PdfGateway]) so widget tests can
/// substitute fakes without platform channels.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import '../../generated/siliph_bridge.g.dart';
import '../models/file_item.dart';

/// Typed bridge failure. [code] matches the Kotlin error contract:
/// `cancelled`, `invalid_pdf`, `invalid_input`, `io_error`, `not_found`.
class BridgeException implements Exception {
  const BridgeException(this.code, this.message);

  final String code;
  final String message;

  bool get isCancelled => code == 'cancelled';

  /// User-facing copy; never exposes raw stack details.
  String get userMessage => switch (code) {
        'cancelled' => 'Cancelled.',
        'invalid_pdf' => 'That file is not a readable PDF.',
        'invalid_input' => message,
        'not_found' => 'The file can no longer be opened.',
        'not_supported' => message,
        'io_error' => 'Something went wrong while reading or writing files.',
        _ => 'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'BridgeException($code): $message';
}

/// A running long-running task with progress and completion signals.
class TaskHandle {
  TaskHandle({
    required this.taskId,
    required this.progress,
    required this.done,
    required this.onCancelTask,
    Future<List<String>>? files,
    this.duplicates,
    this.storageEntries,
    this.image,
    this.barcode,
    this.ocrBlocks,
    this.pageTexts,
    this.searchFiles,
  }) : files = files ?? Future<List<String>>.value(const []);

  final String taskId;

  /// Progress fractions 0..1. Broadcast; safe to listen more than once.
  final Stream<double> progress;

  /// Completes when the task finishes; fails with [BridgeException].
  final Future<void> done;

  /// URIs of extra files the task created (e.g. rendered page images).
  /// Empty for tasks that only write the negotiated output.
  final Future<List<String>> files;

  /// Duplicate groups for find-duplicates tasks; null otherwise.
  final Future<List<DuplicateGroup>>? duplicates;

  /// Storage breakdown for analyzer tasks; null otherwise.
  final Future<List<StorageEntry>>? storageEntries;

  /// Rendered page JPEG for render-page tasks; null otherwise.
  final Future<Uint8List>? image;

  /// Decoded barcode for scan tasks; null otherwise. An empty
  /// [BarcodeResult.rawValue] means nothing was found.
  final Future<BarcodeResult>? barcode;

  /// Recognized text blocks for OCR tasks; null otherwise.
  final Future<List<OcrBlock>>? ocrBlocks;

  /// Extracted per-page text for extract-text tasks; null otherwise.
  final Future<List<PageText>>? pageTexts;

  /// Matches for file-search tasks; null otherwise.
  final Future<List<FileItem>>? searchFiles;

  /// Issues a cancellation request to the native engine.
  final Future<void> Function() onCancelTask;

  Future<void> cancel() => onCancelTask();
}

/// Routes native -> Flutter events to waiting consumers.
///
/// Register once at startup with [attach].
class BridgeEventRouter implements FileResultsApi, TaskEventsApi {
  BridgeEventRouter();

  Completer<List<FileMeta>>? _pendingOpen;
  Completer<List<FileMeta>>? _pendingPick;
  Completer<FileMeta?>? _pendingCreate;
  Completer<String?>? _pendingFolder;
  Completer<FileMeta?>? _pendingCamera;

  final StreamController<FileMeta> _incoming =
      StreamController<FileMeta>.broadcast();

  /// Files shared into Siliph by other apps while it is running
  /// (section 45). Cold-start shares come via [FileGateway.getLaunchFile].
  Stream<FileMeta> get incomingFiles => _incoming.stream;

  final Map<String, TaskState> _tasks = {};

  /// Wires this router into the generated Flutter APIs.
  void attach() {
    FileResultsApi.setUp(this);
    TaskEventsApi.setUp(this);
  }

  Completer<List<FileMeta>> expectOpenResult() =>
      _pendingOpen = Completer<List<FileMeta>>();

  Completer<List<FileMeta>> expectPickImagesResult() =>
      _pendingPick = Completer<List<FileMeta>>();

  Completer<FileMeta?> expectCreateDocumentResult() =>
      _pendingCreate = Completer<FileMeta?>();

  Completer<String?> expectPickFolderResult() =>
      _pendingFolder = Completer<String?>();

  Completer<FileMeta?> expectCameraResult() =>
      _pendingCamera = Completer<FileMeta?>();

  TaskState registerTask(String taskId) {
    final state = TaskState();
    _tasks[taskId] = state;
    return state;
  }

  // -- FileResultsApi ------------------------------------------------------

  @override
  void onOpenResult(List<FileMeta> files) {
    final completer = _pendingOpen;
    _pendingOpen = null;
    if (completer != null && !completer.isCompleted) completer.complete(files);
  }

  @override
  void onPickImagesResult(List<FileMeta> files) {
    final completer = _pendingPick;
    _pendingPick = null;
    if (completer != null && !completer.isCompleted) completer.complete(files);
  }

  @override
  void onCreateDocumentResult(FileMeta? file) {
    final completer = _pendingCreate;
    _pendingCreate = null;
    if (completer != null && !completer.isCompleted) completer.complete(file);
  }

  @override
  void onPickFolderResult(String? treeUri) {
    final completer = _pendingFolder;
    _pendingFolder = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(treeUri);
    }
  }

  @override
  void onCameraResult(FileMeta? file) {
    final completer = _pendingCamera;
    _pendingCamera = null;
    if (completer != null && !completer.isCompleted) completer.complete(file);
  }

  @override
  void onIncomingFile(FileMeta? file) {
    if (file != null && !_incoming.isClosed) _incoming.add(file);
  }

  // -- TaskEventsApi -------------------------------------------------------

  @override
  void onProgress(String taskId, double fraction) {
    _tasks[taskId]?.progress.add(fraction);
  }

  @override
  void onComplete(String taskId) {
    final state = _tasks.remove(taskId);
    if (state == null) return;
    state.progress.add(1.0);
    if (!state.done.isCompleted) state.done.complete();
    unawaited(state.progress.close());
  }

  @override
  void onError(String taskId, String code, String message) {
    final state = _tasks.remove(taskId);
    if (state == null) return;
    if (!state.done.isCompleted) {
      state.done.completeError(BridgeException(code, message));
    }
    unawaited(state.progress.close());
  }

  @override
  void onFilesResult(String taskId, List<String> uris) {
    final state = _tasks[taskId];
    if (state != null && !state.files.isCompleted) {
      state.files.complete(uris);
    }
  }

  @override
  void onDuplicatesResult(String taskId, List<DuplicateGroup> groups) {
    final state = _tasks[taskId];
    if (state != null && !state.duplicates.isCompleted) {
      state.duplicates.complete(groups);
    }
  }

  @override
  void onStorageResult(String taskId, List<StorageEntry> entries) {
    final state = _tasks[taskId];
    if (state != null && !state.storage.isCompleted) {
      state.storage.complete(entries);
    }
  }

  @override
  void onImageResult(String taskId, Uint8List bytes) {
    final state = _tasks[taskId];
    if (state != null && !state.image.isCompleted) {
      state.image.complete(bytes);
    }
  }

  @override
  void onBarcodeResult(String taskId, BarcodeResult result) {
    final state = _tasks[taskId];
    if (state != null && !state.barcode.isCompleted) {
      state.barcode.complete(result);
    }
  }

  @override
  void onOcrResult(String taskId, List<OcrBlock> blocks) {
    final state = _tasks[taskId];
    if (state != null && !state.ocr.isCompleted) {
      state.ocr.complete(blocks);
    }
  }

  @override
  void onTextResult(String taskId, List<PageText> pages) {
    final state = _tasks[taskId];
    if (state != null && !state.text.isCompleted) {
      state.text.complete(pages);
    }
  }

  @override
  void onSearchResult(String taskId, List<FileMeta> files) {
    final state = _tasks[taskId];
    if (state != null && !state.search.isCompleted) {
      state.search.complete(files);
    }
  }
}

/// Internal progress/completion state for one running task.
class TaskState {
  final StreamController<double> progress =
      StreamController<double>.broadcast();
  final Completer<void> done = Completer<void>();
  final Completer<List<String>> files = Completer<List<String>>();
  final Completer<List<DuplicateGroup>> duplicates =
      Completer<List<DuplicateGroup>>();
  final Completer<List<StorageEntry>> storage = Completer<List<StorageEntry>>();
  final Completer<Uint8List> image = Completer<Uint8List>();
  final Completer<BarcodeResult> barcode = Completer<BarcodeResult>();
  final Completer<List<OcrBlock>> ocr = Completer<List<OcrBlock>>();
  final Completer<List<PageText>> text = Completer<List<PageText>>();
  final Completer<List<FileMeta>> search = Completer<List<FileMeta>>();
}

/// File intake/export surface. Fakeable in tests.
abstract interface class FileGateway {
  /// SAF multi-select. Empty list when the user cancels.
  Future<List<FileItem>> openDocuments(List<String> mimeTypes);

  /// Android Photo Picker. Empty list when the user cancels.
  Future<List<FileItem>> pickImages({int maxItems = 10});

  /// Save-as dialog; null when the user cancels.
  Future<FileItem?> createDocument({
    required String mimeType,
    required String displayName,
  });

  /// Renames a SAF document (section 34) and returns the updated item.
  /// Throws [BridgeException] `not_supported` when the provider refuses.
  Future<FileItem> rename(FileItem file, String newDisplayName);

  /// Deletes a SAF document (section 34). Irreversible; callers must
  /// confirm with the user first. True when the provider confirms it.
  Future<bool> delete(FileItem file);

  /// Folder (tree) picker for copy/move destinations; null on cancel.
  Future<String?> pickFolder();

  /// Copies [file] into [targetTreeUri]; returns the new document.
  Future<FileItem> copy(FileItem file, String targetTreeUri);

  /// Moves [file] into [targetTreeUri]; returns the new document. May
  /// throw `not_supported` when the provider cannot resolve the parent.
  Future<FileItem> move(FileItem file, String targetTreeUri);

  /// Opens the system share sheet for [file].
  Future<void> share(FileItem file);

  /// Launches the system camera app; null when the user cancels. No
  /// camera permission needed: the camera app does the capture.
  Future<FileItem?> takePhoto();

  /// Consumes the file Siliph was cold-started with (VIEW/SEND intent,
  /// section 45). Null on normal launches; safe to call once at startup.
  Future<FileItem?> getLaunchFile();
}

/// PDF engine surface. Fakeable in tests.
abstract interface class PdfGateway {
  Future<PdfInfo> inspect(FileItem file);

  /// Starts a merge; events arrive on the returned handle.
  TaskHandle merge({
    required List<FileItem> inputs,
    required FileItem output,
  });

  /// Rebuilds [input] keeping only the zero-based [pageOrder] pages, in
  /// that order. Covers extract, delete, reorder, reverse and duplicate.
  TaskHandle rearrangePages({
    required FileItem input,
    required List<int> pageOrder,
    required FileItem output,
  });

  /// Rotates one-based pages [firstPage]..[lastPage] of [input] by
  /// [rotationDelta] degrees (90/180/270).
  TaskHandle rotatePages({
    required FileItem input,
    required int firstPage,
    required int lastPage,
    required int rotationDelta,
    required FileItem output,
  });

  /// Reads the document-information dictionary (section 15).
  Future<PdfMetadata> readMetadata(FileItem file);

  /// Writes [metadata] over the info dictionary, or strips all fields when
  /// [removeAll] is true.
  TaskHandle writeMetadata({
    required FileItem input,
    required PdfMetadata metadata,
    required bool removeAll,
    required FileItem output,
  });

  /// Rasterized recompression; [level] 0 low, 1 medium, 2 high.
  TaskHandle compress({
    required FileItem input,
    required int level,
    required FileItem output,
  });

  /// One image per page, in order.
  TaskHandle imagesToPdf({
    required List<FileItem> images,
    required FileItem output,
  });

  /// Renders every page at [dpi] into [folderTreeUri]; created image URIs
  /// arrive on [TaskHandle.files].
  TaskHandle pdfToImages({
    required FileItem input,
    required int dpi,
    required String folderTreeUri,
  });

  /// Overlays [text] on every page; [position] diagonal|top|bottom.
  TaskHandle watermark({
    required FileItem input,
    required String text,
    required String position,
    required FileItem output,
  });

  /// Overlays page numbers on every page.
  TaskHandle addPageNumbers({
    required FileItem input,
    required String position,
    required String format,
    required int startPage,
    required FileItem output,
  });

  /// Encrypts the output with [password].
  TaskHandle protect({
    required FileItem input,
    required String password,
    required FileItem output,
  });

  /// Decrypts with [password]; `invalid_input` when wrong (section 14).
  TaskHandle unlock({
    required FileItem input,
    required String password,
    required FileItem output,
  });

  /// Renders zero-based [pageIndex] at [dpi]; JPEG bytes arrive on
  /// [TaskHandle.image] before [TaskHandle.done].
  TaskHandle renderPage({
    required FileItem input,
    required int pageIndex,
    required int dpi,
  });

  /// Stamps [image] onto one-based [pageNumber]; [x]/[y] are the
  /// top-left position normalized 0..1, [widthFraction] is the stamp
  /// width relative to the page width.
  TaskHandle stampImage({
    required FileItem input,
    required FileItem image,
    required int pageNumber,
    required double x,
    required double y,
    required double widthFraction,
    required FileItem output,
  });

  /// Draws ink [strokes] and rectangle [rects] (normalized 0..1 against
  /// the rendered page) into one-based [pageNumber]'s content stream.
  TaskHandle annotate({
    required FileItem input,
    required int pageNumber,
    required List<InkStroke> strokes,
    required List<RectMark> rects,
    required FileItem output,
  });

  /// Permanently burns black over every [marks] region; untouched pages
  /// are copied unchanged.
  TaskHandle redact({
    required FileItem input,
    required List<RedactionMark> marks,
    required FileItem output,
  });

  /// Inserts every page of [insert] into [input] after one-based
  /// [afterPage] (0 inserts before the first page).
  TaskHandle insertPages({
    required FileItem input,
    required FileItem insert,
    required int afterPage,
    required FileItem output,
  });

  /// Replaces one-based pages starting at [startPage] of [input] with
  /// every page of [replacement]; the run must fit inside the document.
  TaskHandle replacePages({
    required FileItem input,
    required FileItem replacement,
    required int startPage,
    required FileItem output,
  });

  /// Extracts per-page text; results arrive on [TaskHandle.pageTexts].
  TaskHandle extractText({required FileItem input});

  /// Lists AcroForm fields; empty list when the PDF has no form.
  Future<List<FormField>> listFormFields(FileItem file);

  /// Fills form fields by name and saves a copy.
  TaskHandle fillForm({
    required FileItem input,
    required List<FormFieldValue> values,
    required FileItem output,
  });

  /// Flattens the form so values become static page content.
  TaskHandle flattenForm({
    required FileItem input,
    required FileItem output,
  });

  /// Stamps [image] as a translucent watermark on every page;
  /// [position] diagonal|top|bottom, [widthFraction] 0.05..0.9.
  TaskHandle watermarkImage({
    required FileItem input,
    required FileItem image,
    required String position,
    required double widthFraction,
    required FileItem output,
  });
}

/// Live [FileGateway] over the generated [FileAccessApi].
class NativeFileGateway implements FileGateway {
  NativeFileGateway(this._api, this._router);

  final FileAccessApi _api;
  final BridgeEventRouter _router;

  @override
  Future<List<FileItem>> openDocuments(List<String> mimeTypes) async {
    final completer = _router.expectOpenResult();
    await _api.requestOpenDocuments(mimeTypes);
    final metas = await completer.future;
    return metas.map(FileItem.fromMeta).toList();
  }

  @override
  Future<List<FileItem>> pickImages({int maxItems = 10}) async {
    final completer = _router.expectPickImagesResult();
    await _api.requestPickImages(maxItems);
    final metas = await completer.future;
    return metas.map(FileItem.fromMeta).toList();
  }

  @override
  Future<FileItem?> createDocument({
    required String mimeType,
    required String displayName,
  }) async {
    final completer = _router.expectCreateDocumentResult();
    await _api.requestCreateDocument(mimeType, displayName);
    final meta = await completer.future;
    return meta == null ? null : FileItem.fromMeta(meta);
  }

  @override
  Future<FileItem> rename(FileItem file, String newDisplayName) async {
    try {
      final meta = await _api.renameDocument(file.uri, newDisplayName);
      return FileItem.fromMeta(meta);
    } on PlatformException catch (e) {
      throw BridgeException(e.code, e.message ?? 'Rename failed');
    }
  }

  @override
  Future<bool> delete(FileItem file) async {
    try {
      return await _api.deleteDocument(file.uri);
    } on PlatformException catch (e) {
      throw BridgeException(e.code, e.message ?? 'Delete failed');
    }
  }

  @override
  Future<String?> pickFolder() async {
    final completer = _router.expectPickFolderResult();
    await _api.requestPickFolder();
    return completer.future;
  }

  @override
  Future<FileItem> copy(FileItem file, String targetTreeUri) async {
    try {
      final meta = await _api.copyDocument(file.uri, targetTreeUri);
      return FileItem.fromMeta(meta);
    } on PlatformException catch (e) {
      throw BridgeException(e.code, e.message ?? 'Copy failed');
    }
  }

  @override
  Future<FileItem> move(FileItem file, String targetTreeUri) async {
    try {
      final meta = await _api.moveDocument(file.uri, targetTreeUri);
      return FileItem.fromMeta(meta);
    } on PlatformException catch (e) {
      throw BridgeException(e.code, e.message ?? 'Move failed');
    }
  }

  @override
  Future<void> share(FileItem file) async {
    await _api.shareDocument(file.uri, file.mimeType ?? '');
  }

  @override
  Future<FileItem?> takePhoto() async {
    final completer = _router.expectCameraResult();
    try {
      await _api.requestTakePhoto();
    } on PlatformException catch (e) {
      throw BridgeException(e.code, e.message ?? 'Camera unavailable');
    }
    final meta = await completer.future;
    return meta == null ? null : FileItem.fromMeta(meta);
  }

  @override
  Future<FileItem?> getLaunchFile() async {
    final meta = await _api.getLaunchFile();
    return meta == null ? null : FileItem.fromMeta(meta);
  }
}

/// Live [PdfGateway] over the generated [PdfApi].
class NativePdfGateway implements PdfGateway {
  NativePdfGateway(this._api, this._router);

  final PdfApi _api;
  final BridgeEventRouter _router;

  int _sequence = 0;

  /// Registers a task, fires [start], and wraps its events in a handle.
  TaskHandle _run(
    String prefix,
    Future<void> Function(String taskId) start, {
    bool withFiles = false,
    bool withImage = false,
    bool withText = false,
  }) {
    final taskId = '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    final state = _router.registerTask(taskId);
    unawaited(start(taskId));
    return TaskHandle(
      taskId: taskId,
      progress: state.progress.stream,
      done: state.done.future,
      files: withFiles ? state.files.future : null,
      image: withImage ? state.image.future : null,
      pageTexts: withText ? state.text.future : null,
      onCancelTask: () => _api.cancel(taskId),
    );
  }

  @override
  Future<PdfInfo> inspect(FileItem file) async {
    try {
      return await _api.inspect(file.uri);
    } on PlatformException catch (e) {
      throw BridgeException(e.code, e.message ?? 'Inspect failed');
    }
  }

  @override
  TaskHandle merge({
    required List<FileItem> inputs,
    required FileItem output,
  }) =>
      _run(
        'merge',
        (taskId) => _api.startMerge(
          inputs.map((f) => f.uri).toList(),
          output.uri,
          taskId,
        ),
      );

  @override
  TaskHandle rearrangePages({
    required FileItem input,
    required List<int> pageOrder,
    required FileItem output,
  }) =>
      _run(
        'rearrange',
        (taskId) =>
            _api.startRearrangePages(input.uri, pageOrder, output.uri, taskId),
      );

  @override
  TaskHandle rotatePages({
    required FileItem input,
    required int firstPage,
    required int lastPage,
    required int rotationDelta,
    required FileItem output,
  }) =>
      _run(
        'rotate',
        (taskId) => _api.startRotatePages(
          input.uri,
          firstPage,
          lastPage,
          rotationDelta,
          output.uri,
          taskId,
        ),
      );

  @override
  Future<PdfMetadata> readMetadata(FileItem file) async {
    try {
      return await _api.readMetadata(file.uri);
    } on PlatformException catch (e) {
      throw BridgeException(e.code, e.message ?? 'Metadata read failed');
    }
  }

  @override
  TaskHandle writeMetadata({
    required FileItem input,
    required PdfMetadata metadata,
    required bool removeAll,
    required FileItem output,
  }) =>
      _run(
        'write-metadata',
        (taskId) => _api.startWriteMetadata(
          input.uri,
          metadata,
          removeAll,
          output.uri,
          taskId,
        ),
      );

  @override
  TaskHandle compress({
    required FileItem input,
    required int level,
    required FileItem output,
  }) =>
      _run(
        'compress',
        (taskId) => _api.startCompress(input.uri, level, output.uri, taskId),
      );

  @override
  TaskHandle imagesToPdf({
    required List<FileItem> images,
    required FileItem output,
  }) =>
      _run(
        'images-to-pdf',
        (taskId) => _api.startImagesToPdf(
          images.map((f) => f.uri).toList(),
          output.uri,
          taskId,
        ),
      );

  @override
  TaskHandle pdfToImages({
    required FileItem input,
    required int dpi,
    required String folderTreeUri,
  }) =>
      _run(
        'pdf-to-images',
        (taskId) =>
            _api.startPdfToImages(input.uri, dpi, folderTreeUri, taskId),
        withFiles: true,
      );

  @override
  TaskHandle watermark({
    required FileItem input,
    required String text,
    required String position,
    required FileItem output,
  }) =>
      _run(
        'watermark',
        (taskId) => _api.startWatermark(
          input.uri,
          text,
          position,
          output.uri,
          taskId,
        ),
      );

  @override
  TaskHandle addPageNumbers({
    required FileItem input,
    required String position,
    required String format,
    required int startPage,
    required FileItem output,
  }) =>
      _run(
        'add-page-numbers',
        (taskId) => _api.startAddPageNumbers(
          input.uri,
          position,
          format,
          startPage,
          output.uri,
          taskId,
        ),
      );

  @override
  TaskHandle protect({
    required FileItem input,
    required String password,
    required FileItem output,
  }) =>
      _run(
        'protect',
        (taskId) => _api.startProtect(input.uri, password, output.uri, taskId),
      );

  @override
  TaskHandle unlock({
    required FileItem input,
    required String password,
    required FileItem output,
  }) =>
      _run(
        'unlock',
        (taskId) => _api.startUnlock(input.uri, password, output.uri, taskId),
      );

  @override
  TaskHandle renderPage({
    required FileItem input,
    required int pageIndex,
    required int dpi,
  }) =>
      _run(
        'render-page',
        (taskId) => _api.startRenderPage(input.uri, pageIndex, dpi, taskId),
        withImage: true,
      );

  @override
  TaskHandle stampImage({
    required FileItem input,
    required FileItem image,
    required int pageNumber,
    required double x,
    required double y,
    required double widthFraction,
    required FileItem output,
  }) =>
      _run(
        'stamp-image',
        (taskId) => _api.startStampImage(
          input.uri, image.uri, pageNumber, x, y, widthFraction,
          output.uri, taskId,
        ),
      );

  @override
  TaskHandle annotate({
    required FileItem input,
    required int pageNumber,
    required List<InkStroke> strokes,
    required List<RectMark> rects,
    required FileItem output,
  }) =>
      _run(
        'annotate',
        (taskId) => _api.startAnnotate(
          input.uri, pageNumber, strokes, rects, output.uri, taskId,
        ),
      );

  @override
  TaskHandle redact({
    required FileItem input,
    required List<RedactionMark> marks,
    required FileItem output,
  }) =>
      _run(
        'redact',
        (taskId) => _api.startRedact(input.uri, marks, output.uri, taskId),
      );

  @override
  TaskHandle insertPages({
    required FileItem input,
    required FileItem insert,
    required int afterPage,
    required FileItem output,
  }) =>
      _run(
        'insert-pages',
        (taskId) => _api.startInsertPages(
          input.uri, insert.uri, afterPage, output.uri, taskId,
        ),
      );

  @override
  TaskHandle replacePages({
    required FileItem input,
    required FileItem replacement,
    required int startPage,
    required FileItem output,
  }) =>
      _run(
        'replace-pages',
        (taskId) => _api.startReplacePages(
          input.uri, replacement.uri, startPage, output.uri, taskId,
        ),
      );

  @override
  TaskHandle extractText({required FileItem input}) => _run(
        'extract-text',
        (taskId) => _api.startExtractText(input.uri, taskId),
        withText: true,
      );

  @override
  Future<List<FormField>> listFormFields(FileItem file) async {
    try {
      return await _api.listFormFields(file.uri);
    } on PlatformException catch (e) {
      throw BridgeException(e.code, e.message ?? 'Form listing failed');
    }
  }

  @override
  TaskHandle fillForm({
    required FileItem input,
    required List<FormFieldValue> values,
    required FileItem output,
  }) =>
      _run(
        'fill-form',
        (taskId) =>
            _api.startFillForm(input.uri, values, output.uri, taskId),
      );

  @override
  TaskHandle flattenForm({
    required FileItem input,
    required FileItem output,
  }) =>
      _run(
        'flatten-form',
        (taskId) => _api.startFlattenForm(input.uri, output.uri, taskId),
      );

  @override
  TaskHandle watermarkImage({
    required FileItem input,
    required FileItem image,
    required String position,
    required double widthFraction,
    required FileItem output,
  }) =>
      _run(
        'watermark-image',
        (taskId) => _api.startWatermarkImage(
          input.uri, image.uri, position, widthFraction, output.uri, taskId,
        ),
      );
}

/// File utilities surface (ZIP, QR, folder analysis). Fakeable in tests.
abstract interface class FileToolsGateway {
  /// Streams [inputs] into a ZIP archive written to [output].
  TaskHandle zipCreate({
    required List<FileItem> inputs,
    required FileItem output,
  });

  /// Extracts [archive] into [folderTreeUri]; created file URIs arrive on
  /// [TaskHandle.files].
  TaskHandle zipExtract({
    required FileItem archive,
    required String folderTreeUri,
  });

  /// Scans [folderTreeUri] for byte-identical files; groups arrive on
  /// [TaskHandle.duplicates].
  TaskHandle findDuplicates({required String folderTreeUri});

  /// Measures [folderTreeUri]; top-level breakdown arrives on
  /// [TaskHandle.storageEntries].
  TaskHandle analyzeStorage({required String folderTreeUri});

  /// Renders [content] as a QR code PNG into [output]. [ecLevel]:
  /// 0 low, 1 medium, 2 quartile, 3 high.
  Future<void> generateQr({
    required String content,
    required int ecLevel,
    required FileItem output,
  });

  /// Decodes a QR/barcode from [image]; the result arrives on
  /// [TaskHandle.barcode] (empty [BarcodeResult.rawValue] = no match).
  TaskHandle scanBarcode({required FileItem image});

  /// Lists the direct children of [folderUri] inside [treeUri], folders
  /// first; entries carry [FileItem.isDirectory].
  Future<List<FileItem>> listFolder({
    required String treeUri,
    required String folderUri,
  });

  /// Recursively searches [treeUri] by file name; matches arrive on
  /// [TaskHandle.searchFiles] (capped at 500 results).
  TaskHandle searchFiles({required String treeUri, required String query});
}

/// Live [FileToolsGateway] over the generated [FileToolsApi].
class NativeFileToolsGateway implements FileToolsGateway {
  NativeFileToolsGateway(this._api, this._router);

  final FileToolsApi _api;
  final BridgeEventRouter _router;

  int _sequence = 0;

  TaskHandle _run(
    String prefix,
    Future<void> Function(String taskId) start, {
    bool withFiles = false,
    bool withDuplicates = false,
    bool withStorage = false,
    bool withBarcode = false,
    bool withSearch = false,
  }) {
    final taskId = '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    final state = _router.registerTask(taskId);
    unawaited(start(taskId));
    return TaskHandle(
      taskId: taskId,
      progress: state.progress.stream,
      done: state.done.future,
      files: withFiles ? state.files.future : null,
      duplicates: withDuplicates ? state.duplicates.future : null,
      storageEntries: withStorage ? state.storage.future : null,
      barcode: withBarcode ? state.barcode.future : null,
      searchFiles: withSearch
          ? state.search.future.then(
              (metas) => metas.map(FileItem.fromMeta).toList(),
            )
          : null,
      onCancelTask: () => _api.cancel(taskId),
    );
  }

  @override
  TaskHandle zipCreate({
    required List<FileItem> inputs,
    required FileItem output,
  }) =>
      _run(
        'zip-create',
        (taskId) => _api.startZipCreate(
          inputs.map((f) => f.uri).toList(),
          output.uri,
          taskId,
        ),
      );

  @override
  TaskHandle zipExtract({
    required FileItem archive,
    required String folderTreeUri,
  }) =>
      _run(
        'zip-extract',
        (taskId) => _api.startZipExtract(archive.uri, folderTreeUri, taskId),
        withFiles: true,
      );

  @override
  TaskHandle findDuplicates({required String folderTreeUri}) => _run(
        'find-duplicates',
        (taskId) => _api.startFindDuplicates(folderTreeUri, taskId),
        withDuplicates: true,
      );

  @override
  TaskHandle analyzeStorage({required String folderTreeUri}) => _run(
        'analyze-storage',
        (taskId) => _api.startAnalyzeStorage(folderTreeUri, taskId),
        withStorage: true,
      );

  @override
  Future<void> generateQr({
    required String content,
    required int ecLevel,
    required FileItem output,
  }) async {
    try {
      await _api.generateQr(content, ecLevel, output.uri);
    } on PlatformException catch (e) {
      throw BridgeException(e.code, e.message ?? 'QR generation failed');
    }
  }

  @override
  TaskHandle scanBarcode({required FileItem image}) => _run(
        'scan-barcode',
        (taskId) => _api.startScanBarcode(image.uri, taskId),
        withBarcode: true,
      );

  @override
  Future<List<FileItem>> listFolder({
    required String treeUri,
    required String folderUri,
  }) async {
    try {
      final metas = await _api.listFolder(treeUri, folderUri);
      return metas.map(FileItem.fromMeta).toList();
    } on PlatformException catch (e) {
      throw BridgeException(e.code, e.message ?? 'Folder listing failed');
    }
  }

  @override
  TaskHandle searchFiles({
    required String treeUri,
    required String query,
  }) =>
      _run(
        'search-files',
        (taskId) => _api.startSearchFiles(treeUri, query, taskId),
        withSearch: true,
      );
}

/// OCR surface (image/PDF recognition, searchable PDF). Fakeable in tests.
abstract interface class OcrGateway {
  /// Recognizes text in [image]; blocks arrive on [TaskHandle.ocrBlocks].
  /// [language]: 'latin', 'devanagari' (Hindi) or 'bengali'.
  TaskHandle recognizeImage({
    required FileItem image,
    String language = 'latin',
  });

  /// Recognizes text on every page of [input]; blocks carry pageIndex.
  TaskHandle recognizePdf({
    required FileItem input,
    String language = 'latin',
  });

  /// Rebuilds [input] as image pages with an invisible OCR text layer,
  /// so the output is copy/search-able (approximate selection). Note:
  /// the overlay font is WinAnsi, so non-Latin scripts appear as spaces
  /// in the invisible layer (recognized text still exports fine).
  TaskHandle searchablePdf({
    required FileItem input,
    required FileItem output,
    String language = 'latin',
  });
}

/// Live [OcrGateway] over the generated [OcrApi].
class NativeOcrGateway implements OcrGateway {
  NativeOcrGateway(this._api, this._router);

  final OcrApi _api;
  final BridgeEventRouter _router;

  int _sequence = 0;

  TaskHandle _run(
    String prefix,
    Future<void> Function(String taskId) start, {
    bool withOcr = false,
  }) {
    final taskId = '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    final state = _router.registerTask(taskId);
    unawaited(start(taskId));
    return TaskHandle(
      taskId: taskId,
      progress: state.progress.stream,
      done: state.done.future,
      ocrBlocks: withOcr ? state.ocr.future : null,
      onCancelTask: () => _api.cancel(taskId),
    );
  }

  @override
  TaskHandle recognizeImage({
    required FileItem image,
    String language = 'latin',
  }) =>
      _run(
        'ocr-image',
        (taskId) => _api.startRecognizeImage(image.uri, language, taskId),
        withOcr: true,
      );

  @override
  TaskHandle recognizePdf({
    required FileItem input,
    String language = 'latin',
  }) =>
      _run(
        'ocr-pdf',
        (taskId) => _api.startRecognizePdf(input.uri, language, taskId),
        withOcr: true,
      );

  @override
  TaskHandle searchablePdf({
    required FileItem input,
    required FileItem output,
    String language = 'latin',
  }) =>
      _run(
        'searchable-pdf',
        (taskId) => _api.startSearchablePdf(
          input.uri, language, output.uri, taskId,
        ),
      );
}

/// Image tools surface (compress, resize, crop, convert, exact-KB, EXIF).
/// Fakeable in tests.
abstract interface class ImageToolsGateway {
  /// Dimensions + format of [file]; throws [BridgeException] when the
  /// document is not a decodable image.
  Future<ImageFacts> inspect(FileItem file);

  /// Re-encodes [input] as [format] ('jpeg'/'webp') at [quality] 1..100.
  TaskHandle compress({
    required FileItem input,
    required String format,
    required int quality,
    required FileItem output,
  });

  /// JPEG-encodes [input] at or under [targetKb] kilobytes.
  TaskHandle compressToKb({
    required FileItem input,
    required int targetKb,
    required FileItem output,
  });

  /// Scales [input] to [width]x[height] pixels.
  TaskHandle resize({
    required FileItem input,
    required int width,
    required int height,
    required FileItem output,
  });

  /// Crops the pixel rectangle out of [input].
  TaskHandle crop({
    required FileItem input,
    required int left,
    required int top,
    required int width,
    required int height,
    required FileItem output,
  });

  /// Converts [input] to [format]: 'jpeg', 'png' or 'webp'.
  TaskHandle convert({
    required FileItem input,
    required String format,
    required FileItem output,
  });

  /// Re-encodes [input] as JPEG so no EXIF/GPS metadata survives.
  TaskHandle stripExif({required FileItem input, required FileItem output});

  /// Composes a printable 4×6 passport sheet with [copies] (1..6) photos
  /// from [input].
  TaskHandle passportSheet({
    required FileItem input,
    required int copies,
    required FileItem output,
  });

  /// Writes small app-generated PNG bytes (e.g. a drawn signature) to
  /// [output]; throws for payloads over the native cap.
  Future<void> writeImageBytes({required FileItem output, required Uint8List png});

  /// Rotates [input] clockwise by [degrees] (90/180/270).
  TaskHandle rotate({
    required FileItem input,
    required int degrees,
    required FileItem output,
  });

  /// Mirrors [input] horizontally or vertically.
  TaskHandle flip({
    required FileItem input,
    required bool horizontal,
    required FileItem output,
  });

  /// Suggests document corners (8 normalized values: TL, TR, BR, BL).
  /// Empty list when no document-like region was detected. Approximate
  /// by design — the UI lets the user adjust the corners.
  Future<List<double>> detectCorners(FileItem image);

  /// Warps the quad in [corners] (8 normalized values) to a rectangle.
  TaskHandle perspectiveCrop({
    required FileItem input,
    required List<double> corners,
    required FileItem output,
  });

  /// Scan enhancement; [mode] color|grayscale|bw|magic.
  TaskHandle enhance({
    required FileItem input,
    required String mode,
    required FileItem output,
  });
}

/// Live [ImageToolsGateway] over the generated [ImageToolsApi].
class NativeImageToolsGateway implements ImageToolsGateway {
  NativeImageToolsGateway(this._api, this._router);

  final ImageToolsApi _api;
  final BridgeEventRouter _router;

  int _sequence = 0;

  TaskHandle _run(String prefix, Future<void> Function(String taskId) start) {
    final taskId =
        '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    final state = _router.registerTask(taskId);
    unawaited(start(taskId));
    return TaskHandle(
      taskId: taskId,
      progress: state.progress.stream,
      done: state.done.future,
      onCancelTask: () => _api.cancel(taskId),
    );
  }

  @override
  Future<ImageFacts> inspect(FileItem file) async {
    try {
      return await _api.inspectImage(file.uri);
    } on PlatformException catch (e) {
      throw BridgeException(e.code, e.message ?? 'Image inspection failed');
    }
  }

  @override
  TaskHandle compress({
    required FileItem input,
    required String format,
    required int quality,
    required FileItem output,
  }) =>
      _run(
        'image-compress',
        (taskId) => _api.startCompressImage(
          input.uri, format, quality, output.uri, taskId,
        ),
      );

  @override
  TaskHandle compressToKb({
    required FileItem input,
    required int targetKb,
    required FileItem output,
  }) =>
      _run(
        'image-compress-kb',
        (taskId) =>
            _api.startCompressToKb(input.uri, targetKb, output.uri, taskId),
      );

  @override
  TaskHandle resize({
    required FileItem input,
    required int width,
    required int height,
    required FileItem output,
  }) =>
      _run(
        'image-resize',
        (taskId) => _api.startResizeImage(
          input.uri, width, height, output.uri, taskId,
        ),
      );

  @override
  TaskHandle crop({
    required FileItem input,
    required int left,
    required int top,
    required int width,
    required int height,
    required FileItem output,
  }) =>
      _run(
        'image-crop',
        (taskId) => _api.startCropImage(
          input.uri, left, top, width, height, output.uri, taskId,
        ),
      );

  @override
  TaskHandle convert({
    required FileItem input,
    required String format,
    required FileItem output,
  }) =>
      _run(
        'image-convert',
        (taskId) =>
            _api.startConvertImage(input.uri, format, output.uri, taskId),
      );

  @override
  TaskHandle stripExif({
    required FileItem input,
    required FileItem output,
  }) =>
      _run(
        'image-strip-exif',
        (taskId) => _api.startStripExif(input.uri, output.uri, taskId),
      );

  @override
  TaskHandle passportSheet({
    required FileItem input,
    required int copies,
    required FileItem output,
  }) =>
      _run(
        'passport-sheet',
        (taskId) =>
            _api.startPassportSheet(input.uri, copies, output.uri, taskId),
      );

  @override
  Future<void> writeImageBytes({
    required FileItem output,
    required Uint8List png,
  }) async {
    try {
      await _api.writeImageBytes(output.uri, png);
    } on PlatformException catch (e) {
      throw BridgeException(e.code, e.message ?? 'Saving the image failed');
    }
  }

  @override
  TaskHandle rotate({
    required FileItem input,
    required int degrees,
    required FileItem output,
  }) =>
      _run(
        'image-rotate',
        (taskId) =>
            _api.startRotateImage(input.uri, degrees, output.uri, taskId),
      );

  @override
  TaskHandle flip({
    required FileItem input,
    required bool horizontal,
    required FileItem output,
  }) =>
      _run(
        'image-flip',
        (taskId) =>
            _api.startFlipImage(input.uri, horizontal, output.uri, taskId),
      );

  @override
  Future<List<double>> detectCorners(FileItem image) async {
    try {
      return await _api.detectDocumentCorners(image.uri);
    } on PlatformException catch (e) {
      throw BridgeException(e.code, e.message ?? 'Corner detection failed');
    }
  }

  @override
  TaskHandle perspectiveCrop({
    required FileItem input,
    required List<double> corners,
    required FileItem output,
  }) =>
      _run(
        'perspective-crop',
        (taskId) => _api.startPerspectiveCrop(
          input.uri, corners, output.uri, taskId,
        ),
      );

  @override
  TaskHandle enhance({
    required FileItem input,
    required String mode,
    required FileItem output,
  }) =>
      _run(
        'image-enhance',
        (taskId) =>
            _api.startEnhanceImage(input.uri, mode, output.uri, taskId),
      );
}
