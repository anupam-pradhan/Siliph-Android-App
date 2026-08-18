/// Core state types for the scanner feature.
///
/// The state machine flows:
///   permission → camera → detecting → detected → holdSteady → capturing
///   → captured → cornerAdjust → enhancing → review → saving → done
library;

import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'scan_mode.dart';

/// Phases the scanner camera can be in.
enum ScanPhase {
  /// Waiting for camera permission.
  permission,

  /// Camera active, searching for a document.
  searching,

  /// Document edges detected in the frame.
  detected,

  /// Document stable; about to auto-capture.
  holdSteady,

  /// Actively capturing a frame.
  capturing,

  /// Frame captured; transitioning to corner adjustment.
  captured,

  /// User is adjusting the detected corners.
  cornerAdjust,

  /// Perspective correction in progress.
  correcting,

  /// Enhancement / filter selection.
  enhancing,

  /// Multi-page review.
  review,

  /// Crop editor.
  cropping,

  /// Saving / exporting the scan.
  saving,

  /// Scan complete.
  done,

  /// An error occurred.
  error,
}

/// A single scanned page through the pipeline.
@immutable
class ScannedPage {
  const ScannedPage({
    required this.id,
    required this.originalUri,
    this.corners,
    this.correctedUri,
    this.enhancedUri,
    this.rotation = 0,
    this.filter = ScanFilter.original,
    this.isSelected = false,
  });

  final String id;
  final String originalUri;

  /// Detected corners (8 normalized doubles: TLx, TLy, TRx, TRy, BRx, BRy, BLx, BLy).
  final List<double>? corners;

  /// URI of the perspective-corrected image.
  final String? correctedUri;

  /// URI of the enhanced/filtered image.
  final String? enhancedUri;

  /// Clockwise rotation in degrees (0, 90, 180, 270).
  final int rotation;

  /// Applied enhancement filter.
  final ScanFilter filter;

  /// Whether this page is selected in review.
  final bool isSelected;

  ScannedPage copyWith({
    String? originalUri,
    List<double>? corners,
    String? correctedUri,
    String? enhancedUri,
    int? rotation,
    ScanFilter? filter,
    bool? isSelected,
  }) {
    return ScannedPage(
      id: id,
      originalUri: originalUri ?? this.originalUri,
      corners: corners ?? this.corners,
      correctedUri: correctedUri ?? this.correctedUri,
      enhancedUri: enhancedUri ?? this.enhancedUri,
      rotation: rotation ?? this.rotation,
      filter: filter ?? this.filter,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  /// The best available URI for display: enhanced > corrected > original.
  String get displayUri => enhancedUri ?? correctedUri ?? originalUri;
}

/// Enhancement filters available after perspective correction.
enum ScanFilter {
  original('Original'),
  auto('Auto'),
  document('Document'),
  grayscale('Grayscale'),
  blackWhite('B&W'),
  photo('Photo'),
  magic('Magic');

  const ScanFilter(this.label);

  final String label;

  /// Maps to the native enhance() mode parameter.
  String get nativeMode => switch (this) {
        ScanFilter.original => 'color',
        ScanFilter.auto => 'auto',
        ScanFilter.document => 'document',
        ScanFilter.grayscale => 'grayscale',
        ScanFilter.blackWhite => 'bw',
        ScanFilter.photo => 'photo',
        ScanFilter.magic => 'magic',
      };
}

/// Output format for the final scan.
enum ScanOutputFormat {
  pdf('PDF'),
  jpg('JPG'),
  png('PNG');

  const ScanOutputFormat(this.label);

  final String label;

  String get extension => label.toLowerCase();
}

/// Page size options for PDF export.
enum PageSizeOption {
  a4('A4'),
  letter('Letter'),
  original('Original'),
  auto('Auto');

  const PageSizeOption(this.label);

  final String label;
}

/// Quality presets for export.
enum ScanQuality {
  high('High'),
  medium('Medium'),
  small('Small');

  const ScanQuality(this.label);

  final String label;
}

/// Camera status messages shown to the user.
enum CameraStatus {
  searching('Looking for a document...'),
  detected('Document detected'),
  holdSteady('Hold steady'),
  noDocument('No document found'),
  tooFar('Move closer'),
  tooClose('Move farther away'),
  poorLighting('Try moving to a brighter area'),
  partialDocument('Move the document inside the frame'),
  capturing('Capturing...'),
  processing('Processing...'),
  permissionDenied('Camera permission required'),
  cameraUnavailable('Camera unavailable');

  const CameraStatus(this.message);

  final String message;
}

/// ID card scanning side.
enum IdCardSide {
  front('Front Side'),
  back('Back Side');

  const IdCardSide(this.label);

  final String label;
}

/// Complete scanner state.
@immutable
class ScannerState {
  const ScannerState({
    this.mode = ScanMode.document,
    this.phase = ScanPhase.permission,
    this.pages = const [],
    this.currentPageIndex = 0,
    this.status = CameraStatus.searching,
    this.isFlashOn = false,
    this.isFrontCamera = false,
    this.isAutoCapture = true,
    this.detectedCorners,
    this.detectionStability = 0,
    this.idCardSide = IdCardSide.front,
    this.outputFormat = ScanOutputFormat.pdf,
    this.pageSize = PageSizeOption.a4,
    this.quality = ScanQuality.high,
    this.fileName = '',
    this.errorMessage,
    this.processingProgress = 0,
    this.galleryImageUri,
  });

  final ScanMode mode;
  final ScanPhase phase;
  final List<ScannedPage> pages;
  final int currentPageIndex;
  final CameraStatus status;
  final bool isFlashOn;
  final bool isFrontCamera;
  final bool isAutoCapture;

  /// Latest detected corners (8 normalized values).
  final List<double>? detectedCorners;

  /// How many consecutive frames the detection has been stable (0..5).
  final int detectionStability;

  /// For ID card mode: which side we're scanning.
  final IdCardSide idCardSide;

  // Export settings
  final ScanOutputFormat outputFormat;
  final PageSizeOption pageSize;
  final ScanQuality quality;
  final String fileName;

  final String? errorMessage;
  final double processingProgress;

  /// URI of an image imported from the gallery (instead of camera capture).
  final String? galleryImageUri;

  bool get hasPages => pages.isNotEmpty;
  int get pageCount => pages.length;
  bool get isIdCardMode => mode.isIdCard;
  bool get needsBackSide => isIdCardMode && pages.isEmpty;
  bool get canExport => hasPages;

  String get effectiveFileName {
    if (fileName.isNotEmpty) return fileName;
    final date = DateTime.now().toIso8601String().substring(0, 10);
    return '${mode.outputBase}-$date';
  }

  ScannerState copyWith({
    ScanMode? mode,
    ScanPhase? phase,
    List<ScannedPage>? pages,
    int? currentPageIndex,
    CameraStatus? status,
    bool? isFlashOn,
    bool? isFrontCamera,
    bool? isAutoCapture,
    List<double>? detectedCorners,
    int? detectionStability,
    IdCardSide? idCardSide,
    ScanOutputFormat? outputFormat,
    PageSizeOption? pageSize,
    ScanQuality? quality,
    String? fileName,
    String? errorMessage,
    double? processingProgress,
    String? galleryImageUri,
  }) {
    return ScannerState(
      mode: mode ?? this.mode,
      phase: phase ?? this.phase,
      pages: pages ?? this.pages,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      status: status ?? this.status,
      isFlashOn: isFlashOn ?? this.isFlashOn,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isAutoCapture: isAutoCapture ?? this.isAutoCapture,
      detectedCorners: detectedCorners ?? this.detectedCorners,
      detectionStability: detectionStability ?? this.detectionStability,
      idCardSide: idCardSide ?? this.idCardSide,
      outputFormat: outputFormat ?? this.outputFormat,
      pageSize: pageSize ?? this.pageSize,
      quality: quality ?? this.quality,
      fileName: fileName ?? this.fileName,
      errorMessage: errorMessage,
      processingProgress: processingProgress ?? this.processingProgress,
      galleryImageUri: galleryImageUri ?? this.galleryImageUri,
    );
  }
}
