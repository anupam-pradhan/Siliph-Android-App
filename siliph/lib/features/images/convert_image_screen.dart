/// Convert Image workflow (section 50 tool-screen standard).
///
/// Re-encodes the picked image into JPEG, PNG or WebP on the native side.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/file_facts.dart';
import '../../domain/services/native_bridge.dart';

enum _Phase { pick, configure, running, done }

const _formats = [
  ('jpeg', 'JPEG', 'image/jpeg', 'jpg'),
  ('png', 'PNG', 'image/png', 'png'),
  ('webp', 'WebP', 'image/webp', 'webp'),
];

class ConvertImageScreen extends ConsumerStatefulWidget {
  const ConvertImageScreen({super.key});

  @override
  ConsumerState<ConvertImageScreen> createState() =>
      _ConvertImageScreenState();
}

class _ConvertImageScreenState extends ConsumerState<ConvertImageScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  bool _picking = false;
  bool _saving = false;
  int _formatIndex = 0;
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
          .openDocuments(const ['image/*']);
      if (!mounted) return;
      setState(() {
        _picking = false;
        if (picked.isNotEmpty) {
          _input = picked.first;
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

  Future<void> _run() async {
    final input = _input;
    if (input == null) return;
    final (format, _, mime, ext) = _formats[_formatIndex];
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: mime,
            displayName: '${baseName(input)}.$ext',
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _saving = false);
        return; // User cancelled the save dialog.
      }
      final handle = ref.read(imageToolsGatewayProvider).convert(
            input: input,
            format: format,
            output: output,
          );
      _output = output;
      _progressSub = handle.progress.listen((value) {
        if (mounted) setState(() => _progress = value);
      });
      setState(() {
        _saving = false;
        _phase = _Phase.running;
        _progress = 0;
      });
      try {
        await handle.done;
        if (!mounted) return;
        setState(() => _phase = _Phase.done);
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not open the save dialog.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = _input;

    return Scaffold(
      appBar: AppBar(title: const Text('Convert Image')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(picking: _picking, onPick: _pick),
                _Phase.configure => _ConfigureView(
                    file: input!,
                    formatIndex: _formatIndex,
                    busy: _picking || _saving,
                    onFormat: (index) => setState(() => _formatIndex = index),
                    onRun: _run,
                  ),
                _Phase.running => _ProgressView(progress: _progress),
                _Phase.done => _DoneView(
                    name: _output?.displayName ?? 'image',
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
            const Icon(Icons.swap_horiz_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Convert Image',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Convert a photo between JPEG, PNG and WebP. '
              'HEIC/HEIF inputs are decoded like any other image.',
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
                  : const Icon(Icons.image_outlined),
              label: Text(picking ? 'Opening…' : 'Choose image'),
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
    required this.formatIndex,
    required this.busy,
    required this.onFormat,
    required this.onRun,
  });

  final FileItem file;
  final int formatIndex;
  final bool busy;
  final ValueChanged<int> onFormat;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final target = _formats[formatIndex];

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
                  const Icon(Icons.image_outlined,
                      color: SiliphColors.primary),
                  const SizedBox(width: SiliphSpacing.sm),
                  Expanded(
                    child: Text(file.displayName,
                        style: Theme.of(context).textTheme.titleMediumStyle),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Text('Convert to',
              style: Theme.of(context).textTheme.titleMediumStyle),
          const SizedBox(height: SiliphSpacing.xs),
          SegmentedButton<int>(
            segments: [
              for (var i = 0; i < _formats.length; i++)
                ButtonSegment(value: i, label: Text(_formats[i].$2)),
            ],
            selected: {formatIndex},
            onSelectionChanged: (selection) => onFormat(selection.first),
          ),
          const SizedBox(height: SiliphSpacing.xs),
          Text(
            formatIndex == 1
                ? 'PNG keeps every pixel exact — files are usually larger.'
                : 'JPEG and WebP are compressed; WebP is usually smaller.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onRun,
              icon: const Icon(Icons.swap_horiz_outlined),
              label: Text('Save as ${target.$2}'),
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
            Text('Converting… ${(progress * 100).toInt()}%',
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
  const _DoneView({required this.name, required this.onRestart});

  final String name;
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
            Text('Image converted',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Saved as "$name".',
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
