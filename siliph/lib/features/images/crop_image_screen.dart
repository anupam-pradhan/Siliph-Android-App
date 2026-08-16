/// Crop Image workflow (section 50 tool-screen standard).
///
/// Center-crops the picked image to a chosen aspect ratio; the pixel
/// rectangle is computed here from inspected dimensions and executed
/// natively. The UI states up front that the crop is centred.
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

/// A crop aspect option; null ratio keeps the original dimensions.
class _Aspect {
  const _Aspect(this.label, this.ratio);

  final String label;

  /// width / height; null = original.
  final double? ratio;
}

const _aspects = [
  _Aspect('Original', null),
  _Aspect('1:1', 1),
  _Aspect('4:3', 4 / 3),
  _Aspect('16:9', 16 / 9),
  _Aspect('3:2', 3 / 2),
  _Aspect('9:16', 9 / 16),
];

/// Centre-crop rectangle for [ratio] inside [srcWidth]x[srcHeight].
(int left, int top, int width, int height) centerCropRect(
  int srcWidth,
  int srcHeight,
  double? ratio,
) {
  if (ratio == null || srcWidth <= 0 || srcHeight <= 0) {
    return (0, 0, srcWidth, srcHeight);
  }
  final current = srcWidth / srcHeight;
  if (current > ratio) {
    final w = (srcHeight * ratio).round().clamp(1, srcWidth);
    return ((srcWidth - w) ~/ 2, 0, w, srcHeight);
  }
  final h = (srcWidth / ratio).round().clamp(1, srcHeight);
  return (0, (srcHeight - h) ~/ 2, srcWidth, h);
}

class CropImageScreen extends ConsumerStatefulWidget {
  const CropImageScreen({super.key});

  @override
  ConsumerState<CropImageScreen> createState() => _CropImageScreenState();
}

class _CropImageScreenState extends ConsumerState<CropImageScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  int _srcWidth = 0;
  int _srcHeight = 0;
  bool _picking = false;
  bool _saving = false;
  int _aspectIndex = 0;
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
      if (picked.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final facts =
          await ref.read(imageToolsGatewayProvider).inspect(picked.first);
      if (!mounted) return;
      setState(() {
        _picking = false;
        _input = picked.first;
        _srcWidth = facts.width;
        _srcHeight = facts.height;
        _aspectIndex = 0;
        _phase = _Phase.configure;
      });
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = e.userMessage;
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
    if (input == null || _srcWidth <= 0 || _srcHeight <= 0) return;
    final (left, top, width, height) = centerCropRect(
      _srcWidth,
      _srcHeight,
      _aspects[_aspectIndex].ratio,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'image/jpeg',
            displayName: '${baseName(input)}-cropped.jpg',
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _saving = false);
        return; // User cancelled the save dialog.
      }
      final handle = ref.read(imageToolsGatewayProvider).crop(
            input: input,
            left: left,
            top: top,
            width: width,
            height: height,
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
          _error = e is BridgeException ? e.userMessage : 'Crop failed.';
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
      appBar: AppBar(title: const Text('Crop Image')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(picking: _picking, onPick: _pick),
                _Phase.configure => _ConfigureView(
                    file: input!,
                    srcWidth: _srcWidth,
                    srcHeight: _srcHeight,
                    aspectIndex: _aspectIndex,
                    busy: _saving,
                    onAspect: (index) => setState(() => _aspectIndex = index),
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
            const Icon(Icons.crop_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Crop Image',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Trim a photo to a common aspect ratio. The crop is taken '
              'from the centre of the image.',
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
    required this.srcWidth,
    required this.srcHeight,
    required this.aspectIndex,
    required this.busy,
    required this.onAspect,
    required this.onRun,
  });

  final FileItem file;
  final int srcWidth;
  final int srcHeight;
  final int aspectIndex;
  final bool busy;
  final ValueChanged<int> onAspect;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final (left, top, width, height) = centerCropRect(
      srcWidth,
      srcHeight,
      _aspects[aspectIndex].ratio,
    );

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(file.displayName,
                            style: Theme.of(context).textTheme.titleMediumStyle),
                        Text('Original $srcWidth×$srcHeight px',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Text('Aspect ratio',
              style: Theme.of(context).textTheme.titleMediumStyle),
          const SizedBox(height: SiliphSpacing.xs),
          Wrap(
            spacing: SiliphSpacing.sm,
            runSpacing: SiliphSpacing.xs,
            children: [
              for (var i = 0; i < _aspects.length; i++)
                ChoiceChip(
                  label: Text(_aspects[i].label),
                  selected: aspectIndex == i,
                  onSelected: busy ? null : (_) => onAspect(i),
                ),
            ],
          ),
          const SizedBox(height: SiliphSpacing.xs),
          Text(
            'Result: $width×$height px, centred'
            '${left > 0 || top > 0 ? ' (edges trimmed)' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onRun,
              icon: const Icon(Icons.crop_outlined),
              label: const Text('Save cropped image'),
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
            Text('Cropping… ${(progress * 100).toInt()}%',
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
            Text('Image cropped',
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
