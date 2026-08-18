/// Main scanner camera screen.
///
/// Shows live camera preview with document detection overlay,
/// auto/manual capture, flash control, camera switch, and gallery import.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/providers.dart';
import 'scan_corner_screen.dart';
import 'scan_mode.dart';
import 'scanner_provider.dart';
import 'scanner_service.dart';
import 'scanner_state.dart';
import 'scan_widgets.dart';

class ScanCameraScreen extends ConsumerStatefulWidget {
  const ScanCameraScreen({super.key, required this.mode});

  final ScanMode mode;

  @override
  ConsumerState<ScanCameraScreen> createState() => _ScanCameraScreenState();
}

class _ScanCameraScreenState extends ConsumerState<ScanCameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isInitializing = true;
  String? _initError;
  Timer? _detectionTimer;
  List<double>? _smoothedCorners;
  int _stabilityCount = 0;
  DateTime? _lastCaptureTime;
  bool _isCapturing = false;

  static const _detectionInterval = Duration(milliseconds: 500);
  static const _captureCooldown = Duration(seconds: 2);
  static const _stabilityThreshold = 5;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _initError = null;
    });

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _isInitializing = false;
          _initError = 'permission_denied';
        });
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _initError = 'camera_unavailable';
        });
        return;
      }

      await _setupCamera(_cameras[_currentCameraIndex]);
      setState(() => _isInitializing = false);
      _startDetectionLoop();
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _initError = 'camera_unavailable';
      });
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    await _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await _controller!.initialize();
    } catch (_) {
      // Camera init failed
    }
  }

  void _startDetectionLoop() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(_detectionInterval, (_) {
      _processFrame();
    });
  }

  Future<void> _processFrame() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing ||
        !mounted) {
      return;
    }

    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      final result = await detectDocument(bytes);

      if (!mounted) return;

      final notifier = ref.read(scannerProvider(widget.mode).notifier);
      final currentState = ref.read(scannerProvider(widget.mode));

      if (result != null && result.isLikelyDocument) {
        final smoothed = smoothCorners(_smoothedCorners, result.corners);
        _smoothedCorners = smoothed;

        if (_isSameDocument(smoothed, _smoothedCorners)) {
          _stabilityCount++;
        } else {
          _stabilityCount = 1;
        }

        notifier.updateDetection(smoothed, _stabilityCount);

        if (currentState.isAutoCapture &&
            _stabilityCount >= _stabilityThreshold) {
          _triggerCapture();
        }
      } else {
        _stabilityCount = 0;
        _smoothedCorners = null;
        notifier.updateDetection(null, 0);
      }
    } catch (_) {
      // Frame processing error - skip silently
    }
  }

  bool _isSameDocument(List<double>? a, List<double>? b) {
    if (a == null || b == null || a.length != 8 || b.length != 8) return false;
    for (var i = 0; i < 8; i++) {
      if ((a[i] - b[i]).abs() > 0.05) return false;
    }
    return true;
  }

  Future<void> _triggerCapture() async {
    if (_isCapturing) return;
    final now = DateTime.now();
    if (_lastCaptureTime != null &&
        now.difference(_lastCaptureTime!) < _captureCooldown) {
      return;
    }

    setState(() => _isCapturing = true);
    _detectionTimer?.cancel();

    final notifier = ref.read(scannerProvider(widget.mode).notifier);
    notifier.setPhase(ScanPhase.capturing);
    notifier.setStatus(CameraStatus.capturing);

    try {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) {
        return;
      }

      final xFile = await controller.takePicture();
      final bytes = await xFile.readAsBytes();

      // Detect corners on the captured full-res image
      final result = await detectDocument(bytes);
      final corners = result?.corners ?? _smoothedCorners;

      _lastCaptureTime = DateTime.now();
      final pageId =
          'page-${DateTime.now().microsecondsSinceEpoch}';

      final page = ScannedPage(
        id: pageId,
        originalUri: xFile.path,
        corners: corners,
      );

      notifier.addPage(page);
      notifier.setPhase(ScanPhase.captured);

      if (!mounted) return;
      // Navigate to corner adjustment
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScanCornerScreen(
            mode: widget.mode,
            pageId: pageId,
          ),
        ),
      );
    } catch (e) {
      notifier.setError('Failed to capture image. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
        _startDetectionLoop();
      }
    }
  }

  Future<void> _importFromGallery() async {
    try {
      final files = await ref.read(fileGatewayProvider).pickImages(maxItems: 1);
      if (files.isEmpty || !mounted) return;

      final file = files.first;
      final notifier = ref.read(scannerProvider(widget.mode).notifier);

      // Detect corners
      final result = await detectDocument(
        await _readFileBytes(file.uri),
      );

      final pageId = 'page-${DateTime.now().microsecondsSinceEpoch}';
      final page = ScannedPage(
        id: pageId,
        originalUri: file.uri,
        corners: result?.corners,
      );

      notifier.addPage(page);
      notifier.setPhase(ScanPhase.captured);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScanCornerScreen(
            mode: widget.mode,
            pageId: pageId,
          ),
        ),
      );
    } catch (_) {
      // Gallery import failed
    }
  }

  Future<Uint8List> _readFileBytes(String uri) async {
    // Read file bytes through the gateway for SAF URIs
    final files = await ref.read(fileGatewayProvider).openDocuments(['image/*']);
    if (files.isNotEmpty) {
      return Uint8List(0); // Placeholder - native bridge handles file access
    }
    return Uint8List(0);
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _setupCamera(_cameras[_currentCameraIndex]);
    ref.read(scannerProvider(widget.mode).notifier).toggleCamera();
    _startDetectionLoop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerProvider(widget.mode));
    final scannerState = ref.watch(scannerProvider(widget.mode));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _initError != null
            ? _buildErrorView()
            : _isInitializing
                ? _buildLoadingView()
                : _buildCameraView(state, scannerState),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: SiliphColors.categoryScanner,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: SiliphSpacing.md),
          Text(
            'Starting camera...',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    final isPermission = _initError == 'permission_denied';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPermission ? Icons.photo_camera_outlined : Icons.error_outline,
              size: 64,
              color: SiliphColors.categoryScanner,
            ),
            const SizedBox(height: SiliphSpacing.md),
            Text(
              isPermission ? 'Camera Permission Required' : 'Camera Unavailable',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              isPermission
                  ? 'Siliph needs camera access to scan documents. Please grant the permission in your device settings.'
                  : 'Could not access the camera. Please check your device.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: SiliphSpacing.xl),
            FilledButton(
              onPressed: isPermission
                  ? () async {
                      await openAppSettings();
                    }
                  : _initCamera,
              style: FilledButton.styleFrom(
                backgroundColor: SiliphColors.categoryScanner,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: SiliphSpacing.xl,
                  vertical: SiliphSpacing.md,
                ),
              ),
              child: Text(isPermission ? 'Open Settings' : 'Try Again'),
            ),
            const SizedBox(height: SiliphSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Go Back',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView(
    ScannerState providerState,
    ScannerState scannerState,
  ) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _buildLoadingView();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        CameraPreview(controller),

        // Detection overlay
        DetectionOverlay(
          detectedCorners: scannerState.detectedCorners,
          status: scannerState.status,
        ),

        // Top bar: status + controls
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTopBar(scannerState),
        ),

        // ID card side indicator
        if (scannerState.isIdCardMode)
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SiliphSpacing.md,
                  vertical: SiliphSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(SiliphRadii.full),
                ),
                child: Text(
                  'Scanning: ${scannerState.idCardSide.label}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomControls(scannerState),
        ),

        // Page count indicator
        if (scannerState.hasPages)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: SiliphSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SiliphSpacing.sm,
                vertical: SiliphSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: SiliphColors.categoryScanner,
                borderRadius: BorderRadius.circular(SiliphRadii.full),
              ),
              child: Text(
                '${scannerState.pageCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopBar(ScannerState state) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SiliphSpacing.md,
        vertical: SiliphSpacing.sm,
      ),
      child: Row(
        children: [
          // Close button
          ScannerControlButton(
            icon: Icons.close,
            onTap: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
          const Spacer(),
          // Status banner
          ScannerStatusBanner(status: state.status),
          const Spacer(),
          // Flash toggle
          ScannerControlButton(
            icon: state.isFlashOn ? Icons.flash_on : Icons.flash_off,
            onTap: () {
              ref.read(scannerProvider(widget.mode).notifier).toggleFlash();
              _setFlashMode();
            },
            isActive: state.isFlashOn,
            tooltip: 'Flash',
          ),
        ],
      ),
    );
  }

  void _setFlashMode() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final state = ref.read(scannerProvider(widget.mode));
    controller.setFlashMode(
      state.isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Widget _buildBottomControls(ScannerState state) {
    return Container(
      padding: const EdgeInsets.only(
        bottom: SiliphSpacing.lg,
        top: SiliphSpacing.md,
      ),
      child: Column(
        mainAxisSize: SiliphSpacing.xxxl > 0 ? MainAxisSize.min : MainAxisSize.min,
        children: [
          // Page thumbnails
          if (state.hasPages)
            PageThumbnailStrip(
              pages: state.pages,
              onTap: (index) {
                ref
                    .read(scannerProvider(widget.mode).notifier)
                    .setCurrentPageIndex(index);
              },
              onDelete: (index) {
                ref
                    .read(scannerProvider(widget.mode).notifier)
                    .removePage(index);
              },
            ),
          const SizedBox(height: SiliphSpacing.md),
          // Auto-capture toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SiliphSpacing.xl),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Auto Capture',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: SiliphSpacing.xs),
                GestureDetector(
                  onTap: () => ref
                      .read(scannerProvider(widget.mode).notifier)
                      .toggleAutoCapture(),
                  child: Container(
                    width: 40,
                    height: 22,
                    decoration: BoxDecoration(
                      color: state.isAutoCapture
                          ? SiliphColors.categoryScanner
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 150),
                      alignment: state.isAutoCapture
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          // Main controls row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SiliphSpacing.xl),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery
                ScannerControlButton(
                  icon: Icons.photo_library_outlined,
                  onTap: _importFromGallery,
                  tooltip: 'Gallery',
                ),
                // Capture button
                CaptureButton(
                  onTap: _triggerCapture,
                  isCapturing: _isCapturing,
                ),
                // Switch camera
                ScannerControlButton(
                  icon: Icons.cameraswitch_outlined,
                  onTap: _switchCamera,
                  tooltip: 'Switch Camera',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
