/// Images -> PDF workflow (section 12, section 50 tool-screen standard).
///
/// [single] drives the one-image variant ('image-to-pdf' tool); otherwise
/// the Photo Picker supplies up to ten images that can be reordered.
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
import '../../domain/services/pdf_plans.dart';

enum _Phase { pick, configure, running, done }

class ImagesToPdfScreen extends ConsumerStatefulWidget {
  const ImagesToPdfScreen({super.key, this.single = false});

  final bool single;

  @override
  ConsumerState<ImagesToPdfScreen> createState() => _ImagesToPdfScreenState();
}

class _ImagesToPdfScreenState extends ConsumerState<ImagesToPdfScreen> {
  _Phase _phase = _Phase.pick;
  final List<FileItem> _images = [];
  bool _picking = false;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  StreamSubscription<double>? _progressSub;

  @override
  void dispose() {
    final sub = _progressSub;
    _progressSub = null;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final gateway = ref.read(fileGatewayProvider);
      final picked = widget.single
          ? await gateway.openDocuments(const ['image/*'])
          : await gateway.pickImages(maxItems: 10);
      if (!mounted) return;
      setState(() {
        _picking = false;
        if (picked.isNotEmpty) {
          _images
            ..clear()
            ..addAll(widget.single ? picked.take(1) : picked);
          _output = null;
          _phase = _Phase.configure;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'Could not open the picker.';
      });
    }
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _images.length) return;
    setState(() {
      final item = _images.removeAt(index);
      _images.insert(target, item);
    });
  }

  Future<void> _run() async {
    if (_images.isEmpty) return;
    final base = widget.single
        ? stripPdfExtension(_images.first.displayName)
        : 'images';
    final output = await ref.read(fileGatewayProvider).createDocument(
          mimeType: 'application/pdf',
          displayName: '$base.pdf',
        );
    if (!mounted) return;
    if (output == null) return;

    final handle = ref.read(pdfGatewayProvider).imagesToPdf(
          images: List.of(_images),
          output: output,
        );
    _progressSub = handle.progress.listen((value) {
      if (mounted) setState(() => _progress = value);
    });
    setState(() {
      _phase = _Phase.running;
      _progress = 0;
      _error = null;
    });
    try {
      await handle.done;
      if (!mounted) return;
      ref.read(importedFilesProvider.notifier).addAll([output]);
      setState(() {
        _output = output;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.configure;
        _error = e is BridgeException ? e.userMessage : 'Conversion failed.';
      });
    } finally {
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.single ? 'Image to PDF' : 'Images to PDF';
    final output = _output;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(
                    picking: _picking, onPick: _pick, single: widget.single),
                _Phase.configure => _ConfigureView(
                    images: _images,
                    single: widget.single,
                    onMove: _move,
                    onAdd: widget.single ? null : _pick,
                    onRemove: (index) => setState(() {
                          _images.removeAt(index);
                          if (_images.isEmpty) _phase = _Phase.pick;
                        }),
                    onRun: _run,
                  ),
                _Phase.running => _ProgressView(progress: _progress),
                _Phase.done => _DoneView(
                    output: output!,
                    onRestart: () => setState(() {
                          _phase = _Phase.pick;
                          _images.clear();
                          _output = null;
                        }),
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
    required this.picking,
    required this.onPick,
    required this.single,
  });

  final bool picking;
  final VoidCallback onPick;
  final bool single;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text(single ? 'Turn an image into a PDF' : 'Turn images into a PDF',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              single
                  ? 'One page, sized to the image.'
                  : 'Each image becomes one page, in the order you choose.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton.icon(
              onPressed: picking ? null : onPick,
              icon: picking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                picking ? 'Opening…' : single ? 'Choose image' : 'Add images',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigureView extends StatelessWidget {
  const _ConfigureView({
    required this.images,
    required this.single,
    required this.onMove,
    required this.onAdd,
    required this.onRemove,
    required this.onRun,
  });

  final List<FileItem> images;
  final bool single;
  final void Function(int index, int delta) onMove;
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(SiliphSpacing.md),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              return Card(
                margin: const EdgeInsets.only(bottom: SiliphSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SiliphSpacing.sm,
                    vertical: SiliphSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Text('${index + 1}.',
                          style: Theme.of(context).textTheme.titleMediumStyle),
                      const SizedBox(width: SiliphSpacing.sm),
                      Expanded(
                        child: Text(
                          image.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (!single) ...[
                        IconButton(
                          onPressed:
                              index > 0 ? () => onMove(index, -1) : null,
                          icon: const Icon(Icons.arrow_upward),
                          tooltip: 'Move up',
                        ),
                        IconButton(
                          onPressed: index < images.length - 1
                              ? () => onMove(index, 1)
                              : null,
                          icon: const Icon(Icons.arrow_downward),
                          tooltip: 'Move down',
                        ),
                      ],
                      IconButton(
                        onPressed: () => onRemove(index),
                        icon: const Icon(Icons.close),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(SiliphSpacing.md),
          child: Column(
            children: [
              if (onAdd != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: SiliphSpacing.sm),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add more images'),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: images.isEmpty ? null : onRun,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    images.isEmpty
                        ? 'Add at least one image'
                        : 'Save PDF (${images.length} '
                            '${images.length == 1 ? 'page' : 'pages'})',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.progress});

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
  const _DoneView({required this.output, required this.onRestart});

  final FileItem output;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: SiliphColors.success),
            const SizedBox(height: SiliphSpacing.md),
            Text('PDF created',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Saved as "${output.displayName}".',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            OutlinedButton(onPressed: onRestart, child: const Text('Done')),
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
