/// Shared fake gateways for workflow widget tests (sections 5, 50).
///
/// No platform channels: everything runs in memory. Each started task exposes
/// [FakePdfGateway.lastCompleter] so tests control completion deterministically.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:siliph/domain/models/file_item.dart';
import 'package:siliph/domain/services/native_bridge.dart';
import 'package:siliph/generated/siliph_bridge.g.dart';

const testOutput = FileItem(
  uri: 'content://test/out.pdf',
  displayName: 'out.pdf',
);

class FakeFileGateway implements FileGateway {
  List<FileItem> nextOpen = const [];
  List<FileItem> nextPickedImages = const [];

  /// Queue of save-as results; pops one per createDocument call. Falls back
  /// to [nextCreate].
  final List<FileItem?> createResults = [];
  FileItem? nextCreate = testOutput;

  final openRequests = <List<String>>[];
  final createRequests = <String>[];

  /// Rename behavior knobs.
  BridgeException? renameError;
  FileItem? renameResult;
  final renameRequests = <(String, String)>[];

  /// Delete behavior knobs.
  bool deleteResult = true;
  BridgeException? deleteError;
  final deleteRequests = <String>[];

  /// Folder picker knobs.
  String? nextFolder = 'content://test/tree/Downloads';
  int pickFolderCalls = 0;

  /// Copy/move behavior knobs.
  BridgeException? copyError;
  BridgeException? moveError;
  FileItem? copyResult;
  FileItem? moveResult;
  final copyCalls = <(String, String)>[];
  final moveCalls = <(String, String)>[];

  /// Share behavior knobs.
  int shareCalls = 0;
  BridgeException? shareError;

  /// Camera capture knobs.
  FileItem? nextPhoto;
  BridgeException? photoError;
  int takePhotoCalls = 0;

  @override
  Future<List<FileItem>> openDocuments(List<String> mimeTypes) async {
    openRequests.add(mimeTypes);
    return nextOpen;
  }

  @override
  Future<List<FileItem>> pickImages({int maxItems = 10}) async =>
      nextPickedImages;

  @override
  Future<FileItem?> createDocument({
    required String mimeType,
    required String displayName,
  }) async {
    createRequests.add(displayName);
    if (createResults.isNotEmpty) return createResults.removeAt(0);
    return nextCreate;
  }

  @override
  Future<FileItem> rename(FileItem file, String newDisplayName) async {
    renameRequests.add((file.uri, newDisplayName));
    if (renameError != null) throw renameError!;
    return renameResult ??
        FileItem(
          uri: file.uri,
          displayName: newDisplayName,
          sizeBytes: file.sizeBytes,
        );
  }

  @override
  Future<bool> delete(FileItem file) async {
    deleteRequests.add(file.uri);
    if (deleteError != null) throw deleteError!;
    return deleteResult;
  }

  @override
  Future<String?> pickFolder() async {
    pickFolderCalls++;
    return nextFolder;
  }

  @override
  Future<FileItem> copy(FileItem file, String targetTreeUri) async {
    copyCalls.add((file.uri, targetTreeUri));
    if (copyError != null) throw copyError!;
    return copyResult ??
        FileItem(uri: '$targetTreeUri/${file.displayName}', displayName: file.displayName);
  }

  @override
  Future<FileItem> move(FileItem file, String targetTreeUri) async {
    moveCalls.add((file.uri, targetTreeUri));
    if (moveError != null) throw moveError!;
    return moveResult ??
        FileItem(uri: '$targetTreeUri/${file.displayName}', displayName: file.displayName);
  }

  @override
  Future<void> share(FileItem file) async {
    shareCalls++;
    if (shareError != null) throw shareError!;
  }

  @override
  Future<FileItem?> takePhoto() async {
    takePhotoCalls++;
    if (photoError != null) throw photoError!;
    return nextPhoto;
  }
}

class FakePdfGateway implements PdfGateway {
  int inspectPageCount = 3;
  bool inspectEncrypted = false;
  PdfInfo? inspectFailure;

  /// Set to fail the next inspect with this exception.
  BridgeException? inspectError;

  Completer<void>? lastCompleter;
  StreamController<double>? lastProgress;
  List<int>? lastPageOrder;
  int? lastFirstPage;
  int? lastLastPage;
  int? lastRotationDelta;
  final rearrangeCalls = <List<int>>[];
  int rotateCalls = 0;

  /// Batch-B (PDF suite) knobs.
  PdfMetadata nextMetadata = PdfMetadata();

  /// Fails the next started single-output task with this error.
  BridgeException? nextTaskError;

  /// Result URIs delivered through [TaskHandle.files] (pdf-to-images).
  List<String> nextFiles = const [];
  int compressCalls = 0;
  int? lastCompressLevel;
  int writeMetadataCalls = 0;
  bool? lastRemoveAll;
  int imagesToPdfCalls = 0;
  List<String>? lastImageUris;
  int pdfToImagesCalls = 0;
  int? lastDpi;
  String? lastFolderUri;
  int watermarkCalls = 0;
  String? lastWatermarkText;
  String? lastWatermarkPosition;
  int protectCalls = 0;
  String? lastProtectPassword;
  int unlockCalls = 0;
  String? lastUnlockPassword;

  /// Batch D–G knobs (render/stamp/annotate/redact).
  Uint8List nextRenderedPage = Uint8List.fromList(const [0xFF, 0xD8]);
  int renderPageCalls = 0;
  int? lastRenderedPageIndex;
  int stampImageCalls = 0;
  (double, double, double)? lastStampPlacement;
  int annotateCalls = 0;
  List<InkStroke>? lastStrokes;
  List<RectMark>? lastRects;
  int redactCalls = 0;
  List<RedactionMark>? lastRedactionMarks;

  @override
  Future<PdfInfo> inspect(FileItem file) async {
    if (inspectError != null) throw inspectError!;
    return PdfInfo(
      uri: file.uri,
      pageCount: inspectPageCount,
      encrypted: inspectEncrypted,
    );
  }

  /// Starts a task that can be completed via [finishRunningTask]; supports
  /// an immediate failure through [nextTaskError] and file results through
  /// [nextFiles].
  TaskHandle _startOp() {
    lastProgress = StreamController<double>.broadcast();
    lastCompleter = Completer<void>();
    final filesCompleter = Completer<List<String>>()..complete(nextFiles);
    final imageCompleter = Completer<Uint8List>()..complete(nextRenderedPage);
    if (nextTaskError != null) {
      lastCompleter!.completeError(nextTaskError!);
      nextTaskError = null;
    }
    return TaskHandle(
      taskId: 'fake-op',
      progress: lastProgress!.stream,
      done: lastCompleter!.future,
      files: filesCompleter.future,
      image: imageCompleter.future,
      onCancelTask: () async {
        if (!lastCompleter!.isCompleted) {
          lastCompleter!
              .completeError(const BridgeException('cancelled', 'x'));
        }
      },
    );
  }

  @override
  Future<PdfMetadata> readMetadata(FileItem file) async => nextMetadata;

  @override
  TaskHandle writeMetadata({
    required FileItem input,
    required PdfMetadata metadata,
    required bool removeAll,
    required FileItem output,
  }) {
    writeMetadataCalls++;
    lastRemoveAll = removeAll;
    return _startOp();
  }

  @override
  TaskHandle compress({
    required FileItem input,
    required int level,
    required FileItem output,
  }) {
    compressCalls++;
    lastCompressLevel = level;
    return _startOp();
  }

  @override
  TaskHandle imagesToPdf({
    required List<FileItem> images,
    required FileItem output,
  }) {
    imagesToPdfCalls++;
    lastImageUris = images.map((f) => f.uri).toList();
    return _startOp();
  }

  @override
  TaskHandle pdfToImages({
    required FileItem input,
    required int dpi,
    required String folderTreeUri,
  }) {
    pdfToImagesCalls++;
    lastDpi = dpi;
    lastFolderUri = folderTreeUri;
    return _startOp();
  }

  @override
  TaskHandle watermark({
    required FileItem input,
    required String text,
    required String position,
    required FileItem output,
  }) {
    watermarkCalls++;
    lastWatermarkText = text;
    lastWatermarkPosition = position;
    return _startOp();
  }

  @override
  TaskHandle protect({
    required FileItem input,
    required String password,
    required FileItem output,
  }) {
    protectCalls++;
    lastProtectPassword = password;
    return _startOp();
  }

  @override
  TaskHandle unlock({
    required FileItem input,
    required String password,
    required FileItem output,
  }) {
    unlockCalls++;
    lastUnlockPassword = password;
    return _startOp();
  }

  @override
  TaskHandle renderPage({
    required FileItem input,
    required int pageIndex,
    required int dpi,
  }) {
    renderPageCalls++;
    lastRenderedPageIndex = pageIndex;
    return _startOp();
  }

  @override
  TaskHandle stampImage({
    required FileItem input,
    required FileItem image,
    required int pageNumber,
    required double x,
    required double y,
    required double widthFraction,
    required FileItem output,
  }) {
    stampImageCalls++;
    lastStampPlacement = (x, y, widthFraction);
    return _startOp();
  }

  @override
  TaskHandle annotate({
    required FileItem input,
    required int pageNumber,
    required List<InkStroke> strokes,
    required List<RectMark> rects,
    required FileItem output,
  }) {
    annotateCalls++;
    lastStrokes = strokes;
    lastRects = rects;
    return _startOp();
  }

  @override
  TaskHandle redact({
    required FileItem input,
    required List<RedactionMark> marks,
    required FileItem output,
  }) {
    redactCalls++;
    lastRedactionMarks = marks;
    return _startOp();
  }

  TaskHandle _newHandle() {
    lastProgress = StreamController<double>.broadcast();
    lastCompleter = Completer<void>();
    return TaskHandle(
      taskId: 'fake-task',
      progress: lastProgress!.stream,
      done: lastCompleter!.future,
      onCancelTask: () async {
        lastCompleter!.completeError(const BridgeException('cancelled', 'x'));
      },
    );
  }

  /// Test helper: complete the running task. (No progress event is emitted
  /// here because a broadcast event delivered just before completion can
  /// still be draining when the screen cancels its subscription.)
  Future<void> finishRunningTask() async {
    lastCompleter?.complete();
  }

  @override
  TaskHandle merge({
    required List<FileItem> inputs,
    required FileItem output,
  }) =>
      _newHandle();

  @override
  TaskHandle rearrangePages({
    required FileItem input,
    required List<int> pageOrder,
    required FileItem output,
  }) {
    lastPageOrder = pageOrder;
    rearrangeCalls.add(pageOrder);
    return _newHandle();
  }

  @override
  TaskHandle rotatePages({
    required FileItem input,
    required int firstPage,
    required int lastPage,
    required int rotationDelta,
    required FileItem output,
  }) {
    lastFirstPage = firstPage;
    lastLastPage = lastPage;
    lastRotationDelta = rotationDelta;
    rotateCalls++;
    return _newHandle();
  }
}

class FakeFileToolsGateway implements FileToolsGateway {
  Completer<void>? lastCompleter;
  StreamController<double>? lastProgress;

  /// Fails the next started task with this error.
  BridgeException? nextTaskError;

  /// Result payloads delivered through the matching [TaskHandle] future.
  List<String> nextFiles = const [];
  List<DuplicateGroup> nextDuplicates = const [];
  List<StorageEntry> nextStorage = const [];

  int zipCreateCalls = 0;
  List<String>? lastZipInputs;
  int zipExtractCalls = 0;
  String? lastExtractFolder;
  int findDuplicatesCalls = 0;
  String? lastDuplicatesFolder;
  int analyzeStorageCalls = 0;
  String? lastAnalyzedFolder;
  int generateQrCalls = 0;
  String? lastQrContent;
  int? lastQrEcLevel;
  BridgeException? qrError;

  /// Barcode scan knobs.
  BarcodeResult nextBarcode = BarcodeResult(rawValue: '', format: 'none');
  int scanBarcodeCalls = 0;

  TaskHandle _startOp({
    bool withFiles = false,
    bool withDuplicates = false,
    bool withStorage = false,
    bool withBarcode = false,
  }) {
    lastProgress = StreamController<double>.broadcast();
    lastCompleter = Completer<void>();
    final filesCompleter = Completer<List<String>>()..complete(nextFiles);
    final dupCompleter = Completer<List<DuplicateGroup>>()
      ..complete(nextDuplicates);
    final storageCompleter = Completer<List<StorageEntry>>()
      ..complete(nextStorage);
    final barcodeCompleter = Completer<BarcodeResult>()..complete(nextBarcode);
    if (nextTaskError != null) {
      lastCompleter!.completeError(nextTaskError!);
      nextTaskError = null;
    }
    return TaskHandle(
      taskId: 'fake-file-tool',
      progress: lastProgress!.stream,
      done: lastCompleter!.future,
      files: withFiles ? filesCompleter.future : null,
      duplicates: withDuplicates ? dupCompleter.future : null,
      storageEntries: withStorage ? storageCompleter.future : null,
      barcode: withBarcode ? barcodeCompleter.future : null,
      onCancelTask: () async {
        if (!lastCompleter!.isCompleted) {
          lastCompleter!
              .completeError(const BridgeException('cancelled', 'x'));
        }
      },
    );
  }

  /// Test helper: complete the running task without emitting progress
  /// (see [FakePdfGateway.finishRunningTask] for why).
  Future<void> finishRunningTask() async {
    lastCompleter?.complete();
  }

  @override
  TaskHandle zipCreate({
    required List<FileItem> inputs,
    required FileItem output,
  }) {
    zipCreateCalls++;
    lastZipInputs = inputs.map((f) => f.uri).toList();
    return _startOp();
  }

  @override
  TaskHandle zipExtract({
    required FileItem archive,
    required String folderTreeUri,
  }) {
    zipExtractCalls++;
    lastExtractFolder = folderTreeUri;
    return _startOp(withFiles: true);
  }

  @override
  TaskHandle findDuplicates({required String folderTreeUri}) {
    findDuplicatesCalls++;
    lastDuplicatesFolder = folderTreeUri;
    return _startOp(withDuplicates: true);
  }

  @override
  TaskHandle analyzeStorage({required String folderTreeUri}) {
    analyzeStorageCalls++;
    lastAnalyzedFolder = folderTreeUri;
    return _startOp(withStorage: true);
  }

  @override
  Future<void> generateQr({
    required String content,
    required int ecLevel,
    required FileItem output,
  }) async {
    generateQrCalls++;
    lastQrContent = content;
    lastQrEcLevel = ecLevel;
    if (qrError != null) {
      final error = qrError!;
      qrError = null;
      throw error;
    }
  }

  @override
  TaskHandle scanBarcode({required FileItem image}) {
    scanBarcodeCalls++;
    return _startOp(withBarcode: true);
  }
}

class FakeImageToolsGateway implements ImageToolsGateway {
  Completer<void>? lastCompleter;
  StreamController<double>? lastProgress;

  /// Fails the next started task with this error.
  BridgeException? nextTaskError;

  /// Facts returned by [inspect]; set [inspectError] to fail inspection.
  ImageFacts nextFacts = ImageFacts(width: 4000, height: 3000, format: 'jpeg');
  BridgeException? inspectError;
  int inspectCalls = 0;

  int compressCalls = 0;
  String? lastCompressFormat;
  int? lastCompressQuality;
  int compressToKbCalls = 0;
  int? lastTargetKb;
  int resizeCalls = 0;
  int? lastResizeWidth;
  int? lastResizeHeight;
  int cropCalls = 0;
  (int, int, int, int)? lastCropRect;
  int convertCalls = 0;
  String? lastConvertFormat;
  int stripExifCalls = 0;
  int passportSheetCalls = 0;
  int? lastPassportCopies;
  int writeImageBytesCalls = 0;
  Uint8List? lastWrittenBytes;

  /// Fails the next [writeImageBytes] call with this error.
  BridgeException? writeBytesError;

  TaskHandle _startOp() {
    lastProgress = StreamController<double>.broadcast();
    lastCompleter = Completer<void>();
    if (nextTaskError != null) {
      lastCompleter!.completeError(nextTaskError!);
      nextTaskError = null;
    }
    return TaskHandle(
      taskId: 'fake-image-tool',
      progress: lastProgress!.stream,
      done: lastCompleter!.future,
      onCancelTask: () async {
        if (!lastCompleter!.isCompleted) {
          lastCompleter!
              .completeError(const BridgeException('cancelled', 'x'));
        }
      },
    );
  }

  /// Test helper: complete the running task (see [FakePdfGateway.finishRunningTask]).
  Future<void> finishRunningTask() async {
    lastCompleter?.complete();
  }

  @override
  Future<ImageFacts> inspect(FileItem file) async {
    inspectCalls++;
    if (inspectError != null) throw inspectError!;
    return nextFacts;
  }

  @override
  TaskHandle compress({
    required FileItem input,
    required String format,
    required int quality,
    required FileItem output,
  }) {
    compressCalls++;
    lastCompressFormat = format;
    lastCompressQuality = quality;
    return _startOp();
  }

  @override
  TaskHandle compressToKb({
    required FileItem input,
    required int targetKb,
    required FileItem output,
  }) {
    compressToKbCalls++;
    lastTargetKb = targetKb;
    return _startOp();
  }

  @override
  TaskHandle resize({
    required FileItem input,
    required int width,
    required int height,
    required FileItem output,
  }) {
    resizeCalls++;
    lastResizeWidth = width;
    lastResizeHeight = height;
    return _startOp();
  }

  @override
  TaskHandle crop({
    required FileItem input,
    required int left,
    required int top,
    required int width,
    required int height,
    required FileItem output,
  }) {
    cropCalls++;
    lastCropRect = (left, top, width, height);
    return _startOp();
  }

  @override
  TaskHandle convert({
    required FileItem input,
    required String format,
    required FileItem output,
  }) {
    convertCalls++;
    lastConvertFormat = format;
    return _startOp();
  }

  @override
  TaskHandle stripExif({required FileItem input, required FileItem output}) {
    stripExifCalls++;
    return _startOp();
  }

  @override
  TaskHandle passportSheet({
    required FileItem input,
    required int copies,
    required FileItem output,
  }) {
    passportSheetCalls++;
    lastPassportCopies = copies;
    return _startOp();
  }

  @override
  Future<void> writeImageBytes({
    required FileItem output,
    required Uint8List png,
  }) async {
    writeImageBytesCalls++;
    lastWrittenBytes = png;
    if (writeBytesError != null) {
      final error = writeBytesError!;
      writeBytesError = null;
      throw error;
    }
  }
}

class FakeOcrGateway implements OcrGateway {
  Completer<void>? lastCompleter;
  StreamController<double>? lastProgress;

  /// Fails the next started task with this error.
  BridgeException? nextTaskError;

  /// Blocks delivered through [TaskHandle.ocrBlocks].
  List<OcrBlock> nextBlocks = const [];

  int recognizeImageCalls = 0;
  int recognizePdfCalls = 0;
  int searchablePdfCalls = 0;

  TaskHandle _startOp({bool withOcr = false}) {
    lastProgress = StreamController<double>.broadcast();
    lastCompleter = Completer<void>();
    final ocrCompleter = Completer<List<OcrBlock>>()..complete(nextBlocks);
    if (nextTaskError != null) {
      lastCompleter!.completeError(nextTaskError!);
      nextTaskError = null;
    }
    return TaskHandle(
      taskId: 'fake-ocr',
      progress: lastProgress!.stream,
      done: lastCompleter!.future,
      ocrBlocks: withOcr ? ocrCompleter.future : null,
      onCancelTask: () async {
        if (!lastCompleter!.isCompleted) {
          lastCompleter!
              .completeError(const BridgeException('cancelled', 'x'));
        }
      },
    );
  }

  /// Test helper: complete the running task (see [FakePdfGateway.finishRunningTask]).
  Future<void> finishRunningTask() async {
    lastCompleter?.complete();
  }

  @override
  TaskHandle recognizeImage({required FileItem image}) {
    recognizeImageCalls++;
    return _startOp(withOcr: true);
  }

  @override
  TaskHandle recognizePdf({required FileItem input}) {
    recognizePdfCalls++;
    return _startOp(withOcr: true);
  }

  @override
  TaskHandle searchablePdf({
    required FileItem input,
    required FileItem output,
  }) {
    searchablePdfCalls++;
    return _startOp();
  }
}
