/// Camera scanner workflows: document, receipt, ID and book modes
/// (section 50 tool-screen standard).
///
/// Capture path: the system camera app takes each shot through
/// ACTION_IMAGE_CAPTURE (no camera permission), pages are collected in
/// order, then the native engine builds one PDF from the images.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';

/// Which scanner flavor is running; only copy differs.
enum ScanMode {
  document(
    title: 'Document Scanner',
    action: 'Scan page',
    hint: 'Capture each page of the document, in order.',
    outputBase: 'scanned-document',
    icon: Icons.document_scanner_outlined,
  ),
  receipt(
    title: 'Receipt Scanner',
    action: 'Scan receipt',
    hint: 'Capture the receipt flat and well lit; one photo per receipt '
        'or per page.',
    outputBase: 'scanned-receipt',
    icon: Icons.receipt_long_outlined,
  ),
  idCard(
    title: 'ID Scanner',
    action: 'Scan side',
    hint: 'Capture the front and back of the card, one side per photo.',
    outputBase: 'scanned-id',
    icon: Icons.badge_outlined,
  ),
  book(
    title: 'Book Scanner',
    action: 'Scan page',
    hint: 'Capture one book page per photo; keep the page flat for the '
        'sharpest result.',
    outputBase: 'scanned-book',
    icon: Icons.auto_stories_outlined,
  );

  const ScanMode({
    required this.title,
    required this.action,
    required this.hint,
    required this.outputBase,
    required this.icon,
  });

  final String title;
  final String action;
  final String hint;
  final String outputBase;
  final IconData icon;
}

enum _Phase { capture, saving, done }

class ScanCaptureScreen extends ConsumerStatefulWidget {
  const ScanCaptureScreen({super.key, required this.mode});

  final ScanMode mode;

  @override
  ConsumerState<ScanCaptureScreen> createState() => _ScanCaptureScreenState();
}

class _ScanCaptureScreenState extends ConsumerState<ScanCaptureScreen> {
  _Phase _phase = _Phase.capture;
  final List<FileItem> _pages = [];
  bool _capturing = false;
  double _progress = 0;
  FileItem? _output;
  String? _error;
  StreamSubscription<double>? _progressSub;

  @override
  void dispose() {
    final sub = _progressSub;
    _progressSub = null;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() {
      _capturing = true;
      _error = null;
    });
    try {
      final shot = await ref.read(fileGatewayProvider).takePhoto();
      if (!mounted) return;
      setState(() {
        _capturing = false;
        if (shot != null) _pages.add(shot);
      });
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = e.userMessage;
      });
    }
  }

  Future<void> _build() async {
    if (_pages.isEmpty) return;
    final mode = widget.mode;
    final name =
        '${mode.outputBase}-${DateTime.now().toIso8601String().substring(0, 10)}.pdf';
    setState(() {
      _error = null;
      _phase = _Phase.saving;
      _progress = 0;
    });
    try {
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'application/pdf',
            displayName: name,
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _phase = _Phase.capture);
        return;
      }
      final handle = ref.read(pdfGatewayProvider).imagesToPdf(
            images: _pages,
            output: output,
          );
      _progressSub = handle.progress.listen((value) {
        if (mounted) setState(() => _progress = value);
      });
      await handle.done;
      if (!mounted) return;
      setState(() {
        _output = output;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.capture;
        _error = e is BridgeException ? e.userMessage : 'Building the PDF failed.';
      });
    } finally {
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }

  Future<void> _share() async {
    final output = _output;
    if (output == null) return;
    try {
      await ref.read(fileGatewayProvider).share(output);
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    }
  }

  void _restart() {
    setState(() {
      _phase = _Phase.capture;
      _pages.clear();
      _output = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    return Scaffold(
      appBar: AppBar(title: Text(mode.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.capture => _CaptureView(
                    mode: mode,
                    pages: _pages,
                    capturing: _capturing,
                    onCapture: _capture,
                    onRemove: (index) =>
                        setState(() => _pages.removeAt(index)),
                    onBuild: _build,
                  ),
                _Phase.saving => _SavingView(progress: _progress),
                _Phase.done => _DoneView(
                    name: _output?.displayName ?? 'scan.pdf',
                    pageCount: _pages.length,
                    onShare: _share,
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

class _CaptureView extends StatelessWidget {
  const _CaptureView({
    required this.mode,
    required this.pages,
    required this.capturing,
    required this.onCapture,
    required this.onRemove,
    required this.onBuild,
  });

  final ScanMode mode;
  final List<FileItem> pages;
  final bool capturing;
  final VoidCallback onCapture;
  final ValueChanged<int> onRemove;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(mode.hint, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: SiliphSpacing.md),
          FilledButton.icon(
            onPressed: capturing ? null : onCapture,
            icon: capturing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(mode.icon),
            label: Text(capturing ? 'Opening camera…' : mode.action),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Text(
            'Captured pages (${pages.length})',
            style: Theme.of(context).textTheme.titleMediumStyle,
          ),
          const SizedBox(height: SiliphSpacing.xs),
          Expanded(
            child: pages.isEmpty
                ? Center(
                    child: Text(
                      'No pages yet.\nUse the camera button above.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.separated(
                    itemCount: pages.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: SiliphSpacing.xs),
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      return Card(
                        child: ListTile(
                          leading: Text('${index + 1}',
                              style:
                                  Theme.of(context).textTheme.titleMediumStyle),
                          title: Text(page.displayName,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: page.formattedSize.isEmpty
                              ? null
                              : Text(page.formattedSize),
                          trailing: IconButton(
                            tooltip: 'Remove page',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => onRemove(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: SiliphSpacing.sm),
          FilledButton.icon(
            onPressed: pages.isEmpty ? null : onBuild,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              pages.isEmpty ? 'Capture at least one page' : 'Create PDF',
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingView extends StatelessWidget {
  const _SavingView({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Building PDF… ${(progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.titleMediumStyle),
            const SizedBox(height: SiliphSpacing.md),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.name,
    required this.pageCount,
    required this.onShare,
    required this.onRestart,
  });

  final String name;
  final int pageCount;
  final VoidCallback onShare;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                size: 64, color: SiliphColors.success),
            const SizedBox(height: SiliphSpacing.md),
            Text('Scan saved',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              '$pageCount ${pageCount == 1 ? 'page' : 'pages'} saved as '
              '"$name".',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share PDF'),
            ),
            const SizedBox(height: SiliphSpacing.sm),
            OutlinedButton(
                onPressed: onRestart, child: const Text('Scan more')),
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
