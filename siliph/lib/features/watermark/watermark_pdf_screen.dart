/// Watermark PDF workflow (section 14, section 50 tool-screen standard).
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

class WatermarkPdfScreen extends ConsumerStatefulWidget {
  const WatermarkPdfScreen({super.key});

  @override
  ConsumerState<WatermarkPdfScreen> createState() =>
      _WatermarkPdfScreenState();
}

class _WatermarkPdfScreenState extends ConsumerState<WatermarkPdfScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  bool _picking = false;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  StreamSubscription<double>? _progressSub;

  final _textController = TextEditingController(text: 'CONFIDENTIAL');
  String _position = 'diagonal';

  @override
  void dispose() {
    final sub = _progressSub;
    _progressSub = null;
    if (sub != null) unawaited(sub.cancel());
    _textController.dispose();
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

  Future<void> _run() async {
    final input = _input;
    if (input == null) return;
    final output = await ref.read(fileGatewayProvider).createDocument(
          mimeType: 'application/pdf',
          displayName: '${stripPdfExtension(input.displayName)}-watermarked.pdf',
        );
    if (!mounted) return;
    if (output == null) return;

    final handle = ref.read(pdfGatewayProvider).watermark(
          input: input,
          text: _textController.text.trim(),
          position: _position,
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
        _error = e is BridgeException ? e.userMessage : 'Watermarking failed.';
      });
    } finally {
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = _input;
    final output = _output;

    return Scaffold(
      appBar: AppBar(title: const Text('Watermark PDF')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(picking: _picking, onPick: _pick),
                _Phase.configure => _ConfigureView(
                    file: input!,
                    controller: _textController,
                    position: _position,
                    onPosition: (value) => setState(() {
                          _position = value;
                        }),
                    onChanged: (_) => setState(() {}),
                    onRun: _run,
                  ),
                _Phase.running => _ProgressView(progress: _progress),
                _Phase.done => _DoneView(
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
            const Icon(Icons.branding_watermark_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Watermark a PDF',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Stamp text on every page of a PDF.',
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
    required this.controller,
    required this.position,
    required this.onPosition,
    required this.onChanged,
    required this.onRun,
  });

  final FileItem file;
  final TextEditingController controller;
  final String position;
  final ValueChanged<String> onPosition;
  final ValueChanged<String> onChanged;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final valid = controller.text.trim().isNotEmpty;
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
                    child: Text(file.displayName,
                        style: Theme.of(context).textTheme.titleMediumStyle),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: const InputDecoration(
              labelText: 'Watermark text',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'diagonal', label: Text('Diagonal')),
              ButtonSegment(value: 'top', label: Text('Top')),
              ButtonSegment(value: 'bottom', label: Text('Bottom')),
            ],
            selected: {position},
            onSelectionChanged: (selection) => onPosition(selection.first),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: valid ? onRun : null,
              icon: const Icon(Icons.branding_watermark_outlined),
              label: Text(valid ? 'Add watermark' : 'Enter watermark text'),
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
            Text('Adding watermark… ${(progress * 100).toInt()}%',
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
            Text('Watermarked',
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
