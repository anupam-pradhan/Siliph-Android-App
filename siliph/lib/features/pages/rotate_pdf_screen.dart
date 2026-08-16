/// Rotate Pages workflow (section 50 tool-screen standard, sections 5, 180).
///
/// Pick one PDF -> choose angle + page range -> save-as. Rotation is applied
/// on the native engine (page /Rotate entry), lossless and instant-ish.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';

enum _Phase { pick, configure, rotating, done }

class RotatePdfScreen extends ConsumerStatefulWidget {
  const RotatePdfScreen({super.key});

  @override
  ConsumerState<RotatePdfScreen> createState() => _RotatePdfScreenState();
}

class _RotatePdfScreenState extends ConsumerState<RotatePdfScreen> {
  FileItem? _source;
  int _pageCount = 0;
  int _angle = 90;
  final TextEditingController _firstController = TextEditingController(text: '1');
  final TextEditingController _lastController = TextEditingController();
  _Phase _phase = _Phase.pick;
  bool _picking = false;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  TaskHandle? _activeTask;
  StreamSubscription<double>? _progressSub;

  @override
  void dispose() {
    _progressSub?.cancel();
    _firstController.dispose();
    _lastController.dispose();
    super.dispose();
  }

  int get _first => int.tryParse(_firstController.text.trim()) ?? 0;

  int get _last => int.tryParse(_lastController.text.trim()) ?? 0;

  bool get _rangeValid =>
      _pageCount > 0 && _first >= 1 && _last >= _first && _last <= _pageCount;

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await ref
          .read(fileGatewayProvider)
          .openDocuments(['application/pdf']);
      if (!mounted) return;
      if (picked.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final info = await ref.read(pdfGatewayProvider).inspect(picked.first);
      if (!mounted) return;
      setState(() {
        _picking = false;
        _source = picked.first;
        _pageCount = info.pageCount;
        _firstController.text = '1';
        _lastController.text = '${info.pageCount}';
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

  Future<void> _rotate() async {
    if (!_rangeValid || _phase == _Phase.rotating) {
      if (!_rangeValid) {
        setState(() => _error = 'Enter a range within 1-$_pageCount.');
      }
      return;
    }
    setState(() {
      _phase = _Phase.rotating;
      _progress = 0;
      _error = null;
    });

    final source = _source!;
    final FileItem? output;
    try {
      output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'application/pdf',
            displayName: '${_baseName(source.displayName)}-rotated.pdf',
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.configure;
        _error = 'Could not create the output file.';
      });
      return;
    }
    if (output == null) {
      // User cancelled the save-as dialog.
      if (!mounted) return;
      setState(() => _phase = _Phase.configure);
      return;
    }

    final handle = ref.read(pdfGatewayProvider).rotatePages(
          input: source,
          firstPage: _first,
          lastPage: _last,
          rotationDelta: _angle,
          output: output,
        );
    _activeTask = handle;
    _progressSub = handle.progress.listen((fraction) {
      if (mounted) setState(() => _progress = fraction);
    });

    try {
      await handle.done;
      if (!mounted) return;
      ref.read(importedFilesProvider.notifier).addAll([output]);
      setState(() {
        _phase = _Phase.done;
        _output = output;
      });
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.configure;
        _error = e.isCancelled ? null : e.userMessage;
      });
    } finally {
      _activeTask = null;
      // Never await stream cleanup: a still-draining broadcast subscription
      // would hold up the phase transition.
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }

  Future<void> _cancelRotate() async {
    await _activeTask?.cancel();
  }

  void _startOver() {
    setState(() {
      _phase = _Phase.pick;
      _source = null;
      _pageCount = 0;
      _output = null;
      _progress = 0;
      _error = null;
    });
  }

  String _baseName(String name) => name.toLowerCase().endsWith('.pdf')
      ? name.substring(0, name.length - 4)
      : name;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Rotate Pages')),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.done => _DoneView(output: _output, onStartOver: _startOver),
          _Phase.pick => _PickView(picking: _picking, onPick: _pick),
          _ => Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(SiliphSpacing.md),
                    children: [
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf_outlined),
                          title: Text(
                            _source!.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('$_pageCount pages'),
                        ),
                      ),
                      const SizedBox(height: SiliphSpacing.md),
                      Text('Rotation angle', style: textTheme.titleSmall),
                      const SizedBox(height: SiliphSpacing.xs),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 90, label: Text('90°')),
                          ButtonSegment(value: 180, label: Text('180°')),
                          ButtonSegment(value: 270, label: Text('270°')),
                        ],
                        selected: {_angle},
                        onSelectionChanged: (selection) =>
                            setState(() => _angle = selection.first),
                      ),
                      const SizedBox(height: SiliphSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _firstController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'First page',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: SiliphSpacing.sm),
                          Expanded(
                            child: TextField(
                              controller: _lastController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Last page',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: SiliphSpacing.xs),
                      Text(
                        _rangeValid
                            ? 'Rotates pages $_first-$_last clockwise by $_angle°.'
                            : 'Enter a range within 1-$_pageCount.',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (_error != null) _ErrorBanner(message: _error!),
                Padding(
                  padding: const EdgeInsets.all(SiliphSpacing.md),
                  child: _buildFooter(),
                ),
              ],
            ),
        },
      ),
    );
  }

  Widget _buildFooter() {
    if (_phase == _Phase.rotating) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rotating… ${(_progress * 100).round()}%'),
          const SizedBox(height: SiliphSpacing.xs),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: SiliphSpacing.md),
          OutlinedButton(onPressed: _cancelRotate, child: const Text('Cancel')),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _picking ? null : _pick,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Choose a different PDF'),
        ),
        const SizedBox(height: SiliphSpacing.sm),
        FilledButton.icon(
          onPressed: _rangeValid ? _rotate : null,
          icon: const Icon(Icons.rotate_right),
          label: const Text('Rotate and save'),
        ),
      ],
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
            const Icon(
              Icons.rotate_right_outlined,
              size: 64,
              color: SiliphColors.primary,
            ),
            const SizedBox(height: SiliphSpacing.md),
            Text('Rotate pages', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Choose a PDF, then rotate every page or just a range.',
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
                  : const Icon(Icons.folder_open),
              label: Text(picking ? 'Opening…' : 'Choose PDF'),
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
      margin: const EdgeInsets.symmetric(horizontal: SiliphSpacing.md),
      padding: const EdgeInsets.all(SiliphSpacing.sm),
      decoration: BoxDecoration(
        color: SiliphColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SiliphRadii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: SiliphColors.error, size: 20),
          const SizedBox(width: SiliphSpacing.sm),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({required this.output, required this.onStartOver});

  final FileItem? output;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: SiliphColors.success,
            ),
            const SizedBox(height: SiliphSpacing.md),
            Text('Rotated successfully', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              output == null
                  ? 'Your rotated PDF has been saved.'
                  : 'Saved as ${output!.displayName}.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton(onPressed: onStartOver, child: const Text('Rotate another')),
          ],
        ),
      ),
    );
  }
}
