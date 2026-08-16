/// Exact KB workflow (section 50 tool-screen standard).
///
/// Targets a file size in kilobytes: the native side binary-searches JPEG
/// quality and downscales when quality alone cannot reach the target.
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

class ExactKbScreen extends ConsumerStatefulWidget {
  const ExactKbScreen({super.key});

  @override
  ConsumerState<ExactKbScreen> createState() => _ExactKbScreenState();
}

class _ExactKbScreenState extends ConsumerState<ExactKbScreen> {
  final TextEditingController _target = TextEditingController(text: '100');
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  bool _picking = false;
  bool _saving = false;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  StreamSubscription<double>? _progressSub;

  @override
  void dispose() {
    _target.dispose();
    final sub = _progressSub;
    _progressSub = null;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  int? get _targetKb => int.tryParse(_target.text.trim());

  bool get _validTarget => (_targetKb ?? 0) >= 10;

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
    final targetKb = _targetKb;
    if (input == null || targetKb == null || !_validTarget) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'image/jpeg',
            displayName: '${baseName(input)}-${targetKb}kb.jpg',
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _saving = false);
        return; // User cancelled the save dialog.
      }
      final handle = ref.read(imageToolsGatewayProvider).compressToKb(
            input: input,
            targetKb: targetKb,
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
      appBar: AppBar(title: const Text('Exact KB')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(picking: _picking, onPick: _pick),
                _Phase.configure => _ConfigureView(
                    file: input!,
                    controller: _target,
                    valid: _validTarget,
                    busy: _picking || _saving,
                    onChanged: (_) => setState(() {}),
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
            const Icon(Icons.straighten_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Exact KB',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Compress a photo to fit a size limit, like a 100 KB form '
              'upload. The output is a JPEG at or under the target.',
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
    required this.controller,
    required this.valid,
    required this.busy,
    required this.onChanged,
    required this.onRun,
  });

  final FileItem file;
  final TextEditingController controller;
  final bool valid;
  final bool busy;
  final ValueChanged<String> onChanged;
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
                        if (file.sizeBytes > 0)
                          Text('Currently ${formatBytes(file.sizeBytes)}',
                              style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Text('Target size (KB)',
              style: Theme.of(context).textTheme.titleMediumStyle),
          const SizedBox(height: SiliphSpacing.xs),
          TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'e.g. 100',
              suffixText: 'KB',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: SiliphSpacing.xs),
          Text(
            valid
                ? 'Quality is reduced first; the image is downscaled only '
                    'if the target still cannot be met.'
                : 'Enter a target of at least 10 KB.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: valid && !busy ? onRun : null,
              icon: const Icon(Icons.straighten_outlined),
              label: Text(valid ? 'Save at target size' : 'Enter a target'),
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
            Text('Target size reached',
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
