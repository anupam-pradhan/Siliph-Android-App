/// Compress PDF workflow (section 10, section 50 tool-screen standard).
///
/// Honest scope note surfaced in the UI: this is rasterized compression —
/// pages are re-rendered at a lower resolution, so the output's text is
/// not selectable.
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

enum _Phase { pick, configure, compressing, done }

const _levelHints = [
  'Best quality, smaller savings.',
  'Balanced quality and size.',
  'Smallest size, lower quality.',
];

class CompressPdfScreen extends ConsumerStatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  ConsumerState<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends ConsumerState<CompressPdfScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  int _level = 1;
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
      final picked = await ref
          .read(fileGatewayProvider)
          .openDocuments(const ['application/pdf']);
      if (!mounted) return;
      setState(() {
        _picking = false;
        if (picked.isNotEmpty) {
          _input = picked.first;
          _output = null;
          _phase = _Phase.configure;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'Could not open the file picker.';
      });
    }
  }

  Future<void> _compress() async {
    final input = _input;
    if (input == null) return;
    final output = await ref.read(fileGatewayProvider).createDocument(
          mimeType: 'application/pdf',
          displayName: '${stripPdfExtension(input.displayName)}-compressed.pdf',
        );
    if (!mounted) return;
    if (output == null) return;

    final handle = ref.read(pdfGatewayProvider).compress(
          input: input,
          level: _level,
          output: output,
        );
    _progressSub = handle.progress.listen((value) {
      if (mounted) setState(() => _progress = value);
    });
    setState(() {
      _phase = _Phase.compressing;
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
        _error = e is BridgeException ? e.userMessage : 'Compression failed.';
      });
    } finally {
      // Never await stream cleanup: a still-draining broadcast subscription
      // would hold up the phase transition.
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = _input;
    final output = _output;

    return PopScope(
      canPop: _phase == _Phase.pick,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_phase == _Phase.configure || _phase == _Phase.done) {
          setState(() {
            _phase = _Phase.pick;
            _input = null;
            _output = null;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compress PDF'),
          leading: BackButton(
            onPressed: () {
              if (_phase == _Phase.configure || _phase == _Phase.done) {
                setState(() {
                  _phase = _Phase.pick;
                  _input = null;
                  _output = null;
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: switch (_phase) {
                  _Phase.pick => _PickView(picking: _picking, onPick: _pick),
                  _Phase.configure => _ConfigureView(
                      file: input!,
                      level: _level,
                      onLevel: (value) => setState(() => _level = value),
                      onCompress: _compress,
                    ),
                  _Phase.compressing => _ProgressView(progress: _progress),
                  _Phase.done => _DoneView(
                      source: input!,
                      output: output!,
                      onRestart: () => setState(() {
                            _phase = _Phase.pick;
                            _input = null;
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
      ),
    );
  }
}

class _PickView extends StatelessWidget {
  const _PickView({required this.picking, required this.onPick});

  final bool picking;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.compress, size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Compress a PDF',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Shrink a PDF by re-encoding its pages at a lower '
              'resolution.',
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
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(picking ? 'Opening…' : 'Choose PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigureView extends StatelessWidget {
  const _ConfigureView({
    required this.file,
    required this.level,
    required this.onLevel,
    required this.onCompress,
  });

  final FileItem file;
  final int level;
  final ValueChanged<int> onLevel;
  final VoidCallback onCompress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SiliphSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined,
                      color: SiliphColors.primary),
                  const SizedBox(width: SiliphSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(file.displayName,
                            style: Theme.of(context).textTheme.titleMediumStyle),
                        Text(
                          file.formattedSize.isEmpty
                              ? 'Size unknown'
                              : file.formattedSize,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Low')),
              ButtonSegment(value: 1, label: Text('Medium')),
              ButtonSegment(value: 2, label: Text('High')),
            ],
            selected: {level},
            onSelectionChanged: (selection) => onLevel(selection.first),
          ),
          const SizedBox(height: SiliphSpacing.sm),
          Text(_levelHints[level],
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: SiliphSpacing.sm),
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: SiliphColors.primary),
              const SizedBox(width: SiliphSpacing.xs),
              Expanded(
                child: Text(
                  'Compressed pages become images, so text will not be '
                  'selectable in the output.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCompress,
              icon: const Icon(Icons.compress),
              label: const Text('Save compressed PDF'),
            ),
          ),
        ],
      ),
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
            Text('Compressing… ${(progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.titleMediumStyle),
            const SizedBox(height: SiliphSpacing.md),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

class _DoneView extends ConsumerWidget {
  const _DoneView({
    required this.source,
    required this.output,
    required this.onRestart,
  });

  final FileItem source;
  final FileItem output;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = source.sizeBytes > 0 &&
        output.sizeBytes > 0 &&
        source.sizeBytes > output.sizeBytes;
    final percent = saved
        ? (((source.sizeBytes - output.sizeBytes) / source.sizeBytes) * 100).round()
        : 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: SiliphColors.success),
            const SizedBox(height: SiliphSpacing.md),
            Text('Compressed',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            if (saved)
              Text(
                'Reduced by $percent% (${source.formattedSize} → ${output.formattedSize})',
                style: Theme.of(context).textTheme.titleMediumStyle.copyWith(
                      color: SiliphColors.success,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Saved as "${output.displayName}"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(fileGatewayProvider).share(output);
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
                const SizedBox(width: SiliphSpacing.md),
                FilledButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Compress Another'),
                ),
              ],
            ),
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
