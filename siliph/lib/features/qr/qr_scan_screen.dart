/// QR / Barcode Scanner workflow (section 50 tool-screen standard).
///
/// Decode path: capture a photo with the system camera or pick an
/// existing image, then run the bundled ML Kit barcode scanner on it.
/// No live-finder camera: the system camera app does the capture, so the
/// app needs no camera permission.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';
import '../../generated/siliph_bridge.g.dart';

enum _Phase { pick, scanning, result }

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  _Phase _phase = _Phase.pick;
  bool _busy = false;
  BarcodeResult? _result;
  String? _error;
  String? _copiedNotice;

  Future<void> _fromCamera() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final shot = await ref.read(fileGatewayProvider).takePhoto();
      if (!mounted) return;
      setState(() => _busy = false);
      if (shot != null) unawaited(_scan(shot));
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.userMessage;
      });
    }
  }

  Future<void> _fromGallery() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ref.read(fileGatewayProvider).pickImages(maxItems: 1);
      if (!mounted) return;
      setState(() => _busy = false);
      if (picked.isNotEmpty) unawaited(_scan(picked.first));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not open the image picker.';
      });
    }
  }

  Future<void> _scan(FileItem image) async {
    final handle =
        ref.read(fileToolsGatewayProvider).scanBarcode(image: image);
    setState(() {
      _phase = _Phase.scanning;
      _error = null;
    });
    try {
      final result = await handle.barcode;
      await handle.done;
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _Phase.result;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.pick;
        _error = e is BridgeException ? e.userMessage : 'Scanning failed.';
      });
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    setState(() => _copiedNotice = 'Copied to clipboard.');
  }

  void _restart() {
    setState(() {
      _phase = _Phase.pick;
      _result = null;
      _copiedNotice = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Scanner')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(
                    busy: _busy,
                    onCamera: _fromCamera,
                    onGallery: _fromGallery,
                  ),
                _Phase.scanning => const _ScanningView(),
                _Phase.result => _ResultView(
                    result: _result!,
                    notice: _copiedNotice,
                    onCopy: _copy,
                    onRestart: _restart,
                  ),
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(SiliphSpacing.md),
                child: _ErrorBanner(message: _error!),
              ),
          ],
        ),
      ),
    );
  }
}

class _PickView extends StatelessWidget {
  const _PickView({
    required this.busy,
    required this.onCamera,
    required this.onGallery,
  });

  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Scan a QR code or barcode',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Take a photo of the code, or choose an image that already '
              'contains one.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton.icon(
              onPressed: busy ? null : onCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take photo'),
            ),
            const SizedBox(height: SiliphSpacing.sm),
            OutlinedButton.icon(
              onPressed: busy ? null : onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose image'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanningView extends StatelessWidget {
  const _ScanningView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: SiliphSpacing.md),
          Text('Looking for a code…',
              style: Theme.of(context).textTheme.titleMediumStyle),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.notice,
    required this.onCopy,
    required this.onRestart,
  });

  final BarcodeResult result;
  final String? notice;
  final ValueChanged<String> onCopy;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final found = result.rawValue.isNotEmpty;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              found ? Icons.qr_code_2 : Icons.search_off_outlined,
              size: 64,
              color: found ? SiliphColors.success : SiliphColors.error,
            ),
            const SizedBox(height: SiliphSpacing.md),
            Text(
              found ? 'Code found' : 'No code found',
              style: Theme.of(context).textTheme.headlineSmallStyle,
            ),
            const SizedBox(height: SiliphSpacing.xs),
            if (found) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(SiliphSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Format: ${result.format}',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: SiliphSpacing.xs),
                      SelectableText(
                        result.rawValue,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: SiliphSpacing.sm),
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: SiliphSpacing.sm),
                  child: Text(notice!,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              FilledButton.icon(
                onPressed: () => onCopy(result.rawValue),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy value'),
              ),
            ] else
              Text(
                'Nothing decodable was found in that image. Try a closer, '
                'better-lit shot.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: SiliphSpacing.lg),
            OutlinedButton(onPressed: onRestart, child: const Text('Scan again')),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.sm),
      decoration: BoxDecoration(
        color: SiliphColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SiliphRadii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: SiliphColors.error, size: 20),
          const SizedBox(width: SiliphSpacing.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
