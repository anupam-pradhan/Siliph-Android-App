/// Riverpod provider for the document scanner.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'scan_mode.dart';
import 'scanner_state.dart';

/// Manages the full scanner state machine.
class ScannerNotifier extends Notifier<ScannerState> {
  ScannerNotifier(this.scanMode);

  final ScanMode scanMode;

  @override
  ScannerState build() => ScannerState(mode: scanMode);

  // -- Phase transitions ---------------------------------------------------

  void setPhase(ScanPhase phase) {
    state = state.copyWith(phase: phase);
  }

  void setStatus(CameraStatus status) {
    state = state.copyWith(status: status);
  }

  void setError(String message) {
    state = state.copyWith(
      phase: ScanPhase.error,
      errorMessage: message,
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  // -- Camera controls -----------------------------------------------------

  void toggleFlash() {
    state = state.copyWith(isFlashOn: !state.isFlashOn);
  }

  void toggleCamera() {
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  void toggleAutoCapture() {
    state = state.copyWith(isAutoCapture: !state.isAutoCapture);
  }

  // -- Detection -----------------------------------------------------------

  void updateDetection(List<double>? corners, int stability) {
    state = state.copyWith(
      detectedCorners: corners,
      detectionStability: stability,
      status: corners != null
          ? (stability >= 4
              ? CameraStatus.holdSteady
              : CameraStatus.detected)
          : CameraStatus.searching,
    );
  }

  // -- Pages ---------------------------------------------------------------

  void addPage(ScannedPage page) {
    state = state.copyWith(pages: [...state.pages, page]);
  }

  void updatePage(int index, ScannedPage page) {
    final pages = List<ScannedPage>.from(state.pages);
    if (index >= 0 && index < pages.length) {
      pages[index] = page;
      state = state.copyWith(pages: pages);
    }
  }

  void removePage(int index) {
    final pages = List<ScannedPage>.from(state.pages);
    if (index >= 0 && index < pages.length) {
      pages.removeAt(index);
      state = state.copyWith(
        pages: pages,
        currentPageIndex: state.currentPageIndex.clamp(
          0,
          (pages.length - 1).clamp(0, pages.length),
        ),
      );
    }
  }

  void reorderPage(int oldIndex, int newIndex) {
    final pages = List<ScannedPage>.from(state.pages);
    if (oldIndex < 0 ||
        oldIndex >= pages.length ||
        newIndex < 0 ||
        newIndex >= pages.length) {
      return;
    }
    final item = pages.removeAt(oldIndex);
    pages.insert(newIndex, item);
    state = state.copyWith(pages: pages);
  }

  void setCurrentPageIndex(int index) {
    state = state.copyWith(currentPageIndex: index);
  }

  void clearPages() {
    state = state.copyWith(pages: [], currentPageIndex: 0);
  }

  // -- ID card mode --------------------------------------------------------

  void advanceIdCardSide() {
    if (state.isIdCardMode && state.idCardSide == IdCardSide.front) {
      state = state.copyWith(idCardSide: IdCardSide.back);
    }
  }

  // -- Export settings -----------------------------------------------------

  void setOutputFormat(ScanOutputFormat format) {
    state = state.copyWith(outputFormat: format);
  }

  void setPageSize(PageSizeOption size) {
    state = state.copyWith(pageSize: size);
  }

  void setQuality(ScanQuality quality) {
    state = state.copyWith(quality: quality);
  }

  void setFileName(String name) {
    state = state.copyWith(fileName: name);
  }

  // -- Processing progress -------------------------------------------------

  void setProcessingProgress(double progress) {
    state = state.copyWith(processingProgress: progress);
  }

  // -- Gallery import ------------------------------------------------------

  void setGalleryImage(String uri) {
    state = state.copyWith(galleryImageUri: uri);
  }

  // -- Navigation shortcuts ------------------------------------------------

  void goToCapture() {
    state = state.copyWith(
      phase: ScanPhase.searching,
      status: CameraStatus.searching,
      detectedCorners: null,
      detectionStability: 0,
    );
  }

  void goToReview() {
    state = state.copyWith(phase: ScanPhase.review);
  }

  void goToCornerAdjust() {
    state = state.copyWith(phase: ScanPhase.cornerAdjust);
  }

  void goToEnhance() {
    state = state.copyWith(phase: ScanPhase.enhancing);
  }

  void goToSave() {
    state = state.copyWith(phase: ScanPhase.saving);
  }

  void restart() {
    state = ScannerState(mode: scanMode);
  }
}

/// Factory provider that creates a notifier for any scan mode.
final scannerProvider =
    NotifierProvider.family<ScannerNotifier, ScannerState, ScanMode>(
  ScannerNotifier.new,
);
