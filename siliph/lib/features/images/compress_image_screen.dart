/// Compress Image workflow (section 50 tool-screen standard).
///
/// Re-encodes the picked image as JPEG or WebP at a chosen quality on the
/// native side. Honest about re-encoding: EXIF metadata does not survive.
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

class CompressImageScreen extends ConsumerStatefulWidget {
  const CompressImageScreen({super.key});

  @override
  ConsumerState<CompressImageScreen> createState() =>
      _CompressImageScreenState();
}

class _CompressImageScreenState extends ConsumerState<CompressImageScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  bool _picking = false;
  bool _saving = false;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  String _format = 'jpeg';
  double _quality = 70;
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
      final picked = await ref.read(fileGatewayProvider).openDocuments(const [
        'image/*',
      ]);
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
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ext = _format == 'webp' ? 'webp' : 'jpg';
      final mime = _format == 'webp' ? 'image/webp' : 'image/jpeg';
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: mime,
            displayName: '${baseName(input)}-compressed.$ext',
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _saving = false);
        return; // User cancelled the save dialog.
      }
      final handle = ref.read(imageToolsGatewayProvider).compress(
            input: input,
            format: _format,
            quality: _quality.round(),
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
          _error =
              e is BridgeException ? e.userMessage : 'Compression failed.';
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
      appBar: AppBar(title: const Text('Compress Image')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick =>
                  _PickView(picking: _picking, onPick: _pick),
                _Phase.configure => _ConfigureView(
                    file: input!,
                    format: _format,
                    quality: _quality,
                    busy: _picking || _saving,
                    onFormat: (value) => setState(() => _format = value),
                    onQuality: (value) => setState(() => _quality = value),
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
            const Icon(Icons.compress_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Compress Image',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Re-encode a photo at a lower quality to shrink it. '
              'Metadata such as GPS location is not kept in the output.',
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
    required this.format,
    required this.quality,
    required this.busy,
    required this.onFormat,
    required this.onQuality,
    required this.onRun,
  });

  final FileItem file;
  final String format;
  final double quality;
  final bool busy;
  final ValueChanged<String> onFormat;
  final ValueChanged<double> onQuality;
  final VoidCallback onRun;

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
          Text('Format', style: Theme.of(context).textTheme.titleMediumStyle),
          const SizedBox(height: SiliphSpacing.xs),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'jpeg', label: Text('JPEG')),
              ButtonSegment(value: 'webp', label: Text('WebP')),
            ],
            selected: {format},
            onSelectionChanged: (selection) => onFormat(selection.first),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Text('Quality: ${quality.toInt()}',
              style: Theme.of(context).textTheme.titleMediumStyle),
          Slider(
            value: quality,
            min: 10,
            max: 95,
            divisions: 17,
            onChanged: busy ? null : onQuality,
          ),
          Text(
            'Lower quality means a smaller file. Re-encoding always loses '
            'some detail.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onRun,
              icon: const Icon(Icons.compress_outlined),
              label: const Text('Save compressed image'),
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
            Text('Image compressed',
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
