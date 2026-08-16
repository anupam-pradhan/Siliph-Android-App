/// Resize Image workflow (section 50 tool-screen standard).
///
/// Inspects the picked image for its pixel dimensions, then scales it to
/// new dimensions with the aspect ratio locked by default.
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

class ResizeImageScreen extends ConsumerStatefulWidget {
  const ResizeImageScreen({super.key});

  @override
  ConsumerState<ResizeImageScreen> createState() => _ResizeImageScreenState();
}

class _ResizeImageScreenState extends ConsumerState<ResizeImageScreen> {
  final TextEditingController _width = TextEditingController();
  final TextEditingController _height = TextEditingController();
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  int _srcWidth = 0;
  int _srcHeight = 0;
  bool _picking = false;
  bool _saving = false;
  bool _lockRatio = true;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  StreamSubscription<double>? _progressSub;

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    final sub = _progressSub;
    _progressSub = null;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  double get _ratio =>
      _srcHeight > 0 ? _srcWidth / _srcHeight : 1.0;

  int? get _widthPx => int.tryParse(_width.text.trim());

  int? get _heightPx => int.tryParse(_height.text.trim());

  bool get _validDims {
    final w = _widthPx;
    final h = _heightPx;
    return w != null && h != null && w >= 1 && h >= 1 && w <= 10000 && h <= 10000;
  }

  void _onWidth(String value) {
    final w = int.tryParse(value.trim());
    if (_lockRatio && w != null && w > 0 && _srcHeight > 0) {
      _height.text = (w / _ratio).round().toString();
    }
    setState(() {});
  }

  void _onHeight(String value) {
    final h = int.tryParse(value.trim());
    if (_lockRatio && h != null && h > 0 && _srcHeight > 0) {
      _width.text = (h * _ratio).round().toString();
    }
    setState(() {});
  }

  void _applyPercent(int percent) {
    if (_srcWidth <= 0 || _srcHeight <= 0) return;
    _width.text = ((_srcWidth * percent) / 100).round().toString();
    _height.text = ((_srcHeight * percent) / 100).round().toString();
    setState(() {});
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
        _width.text = facts.width.toString();
        _height.text = facts.height.toString();
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
    final w = _widthPx;
    final h = _heightPx;
    if (input == null || w == null || h == null || !_validDims) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'image/jpeg',
            displayName: '${baseName(input)}-${w}x$h.jpg',
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _saving = false);
        return; // User cancelled the save dialog.
      }
      final handle = ref.read(imageToolsGatewayProvider).resize(
            input: input,
            width: w,
            height: h,
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
          _error = e is BridgeException ? e.userMessage : 'Resize failed.';
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
      appBar: AppBar(title: const Text('Resize Image')),
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
                    widthController: _width,
                    heightController: _height,
                    lockRatio: _lockRatio,
                    busy: _saving,
                    onWidth: _onWidth,
                    onHeight: _onHeight,
                    onLock: (value) => setState(() => _lockRatio = value),
                    onPercent: _applyPercent,
                    onRun: _run,
                    valid: _validDims,
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
            const Icon(Icons.aspect_ratio_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Resize Image',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Scale a photo to exact pixel dimensions. The output is '
              'saved as a JPEG.',
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
    required this.widthController,
    required this.heightController,
    required this.lockRatio,
    required this.busy,
    required this.valid,
    required this.onWidth,
    required this.onHeight,
    required this.onLock,
    required this.onPercent,
    required this.onRun,
  });

  final FileItem file;
  final int srcWidth;
  final int srcHeight;
  final TextEditingController widthController;
  final TextEditingController heightController;
  final bool lockRatio;
  final bool busy;
  final bool valid;
  final ValueChanged<String> onWidth;
  final ValueChanged<String> onHeight;
  final ValueChanged<bool> onLock;
  final ValueChanged<int> onPercent;
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widthController,
                  onChanged: onWidth,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Width px',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  lockRatio ? Icons.link : Icons.link_off,
                  color: lockRatio ? SiliphColors.primary : null,
                ),
                onPressed: () => onLock(!lockRatio),
                tooltip: lockRatio ? 'Aspect ratio locked' : 'Aspect ratio free',
              ),
              Expanded(
                child: TextField(
                  controller: heightController,
                  onChanged: onHeight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Height px',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SiliphSpacing.sm),
          Wrap(
            spacing: SiliphSpacing.sm,
            children: [
              for (final percent in [25, 50, 75])
                OutlinedButton(
                  onPressed: busy ? null : () => onPercent(percent),
                  child: Text('$percent%'),
                ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: valid && !busy ? onRun : null,
              icon: const Icon(Icons.aspect_ratio_outlined),
              label: Text(valid ? 'Save resized image' : 'Enter dimensions'),
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
            Text('Resizing… ${(progress * 100).toInt()}%',
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
            Text('Image resized',
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
