/// Split PDF workflow (section 50 tool-screen standard, sections 5, 180).
///
/// Pick one PDF -> choose "page range" or "every N pages" -> save each part
/// through its own save-as dialog. Honest progress per part, real
/// cancellation, typed error copy from the bridge.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';
import '../../domain/services/pdf_plans.dart';

enum _SplitMode { range, everyN }

enum _Phase { pick, configure, splitting, done }

class SplitPdfScreen extends ConsumerStatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  ConsumerState<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends ConsumerState<SplitPdfScreen> {
  FileItem? _source;
  int _pageCount = 0;
  _SplitMode _mode = _SplitMode.range;
  final TextEditingController _firstController = TextEditingController(text: '1');
  final TextEditingController _lastController = TextEditingController();
  final TextEditingController _everyNController = TextEditingController(text: '1');
  _Phase _phase = _Phase.pick;
  bool _picking = false;
  double _progress = 0;
  String? _error;
  final List<FileItem> _outputs = [];
  TaskHandle? _activeTask;
  StreamSubscription<double>? _progressSub;

  @override
  void dispose() {
    _progressSub?.cancel();
    _firstController.dispose();
    _lastController.dispose();
    _everyNController.dispose();
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
        if (info.encrypted) {
          _error = 'This PDF is encrypted and may not split cleanly.';
        }
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

  List<PageRange> _plan() {
    if (_mode == _SplitMode.range) {
      final first = int.tryParse(_firstController.text.trim()) ?? 0;
      final last = int.tryParse(_lastController.text.trim()) ?? 0;
      final range = clampRange(_pageCount, first, last);
      return range == null ? const [] : [range];
    }
    final everyN = int.tryParse(_everyNController.text.trim()) ?? 0;
    return splitPlan(_pageCount, everyN);
  }

  String? _planProblem(List<PageRange> plan) {
    if (_pageCount == 0) return 'This PDF has no pages.';
    if (_mode == _SplitMode.range) {
      final first = int.tryParse(_firstController.text.trim());
      final last = int.tryParse(_lastController.text.trim());
      if (first == null || last == null || first > last) {
        return 'Enter a valid range, e.g. 1-$_pageCount.';
      }
    } else {
      final everyN = int.tryParse(_everyNController.text.trim());
      if (everyN == null || everyN < 1) return 'Enter how many pages per part.';
    }
    if (plan.isEmpty) return 'No pages in this split.';
    return null;
  }

  Future<void> _split() async {
    final plan = _plan();
    final problem = _planProblem(plan);
    if (problem != null || _phase == _Phase.splitting) {
      if (problem != null) setState(() => _error = problem);
      return;
    }
    setState(() {
      _phase = _Phase.splitting;
      _progress = 0;
      _error = null;
      _outputs.clear();
    });

    final files = ref.read(fileGatewayProvider);
    final pdfs = ref.read(pdfGatewayProvider);
    final source = _source!;

    try {
      for (var i = 0; i < plan.length; i++) {
        final range = plan[i];
        final FileItem? output;
        try {
          output = await files.createDocument(
            mimeType: 'application/pdf',
            displayName: partName(
              source.displayName,
              part: i + 1,
              of: plan.length,
            ),
          );
        } catch (e) {
          throw const BridgeException('io_error', 'Could not create the output file.');
        }
        if (output == null) {
          // User cancelled the save-as dialog: stop here, keep what we have.
          break;
        }

        final handle = pdfs.rearrangePages(
          input: source,
          pageOrder: range.toZeroBasedOrder(),
          output: output,
        );
        _activeTask = handle;
        final previousSub = _progressSub;
        _progressSub = null;
        if (previousSub != null) unawaited(previousSub.cancel());
        _progressSub = handle.progress.listen((fraction) {
          if (mounted) {
            setState(() => _progress = (i + fraction) / plan.length);
          }
        });
        await handle.done;
        _activeTask = null;
        _outputs.add(output);
      }
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.isCancelled ? null : e.userMessage);
    } finally {
      _activeTask = null;
      // Never await stream cleanup here: a still-draining broadcast
      // subscription would hold up the phase transition.
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
    }

    if (!mounted) return;
    setState(() => _phase = _outputs.isEmpty ? _Phase.configure : _Phase.done);
  }

  Future<void> _cancelSplit() async {
    await _activeTask?.cancel();
  }

  void _startOver() {
    setState(() {
      _phase = _Phase.pick;
      _source = null;
      _pageCount = 0;
      _outputs.clear();
      _progress = 0;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Split PDF')),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.done => _DoneView(outputs: _outputs, onStartOver: _startOver),
          _Phase.pick => _PickView(picking: _picking, onPick: _pick),
          _ => Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(SiliphSpacing.md),
                    children: [
                      _SourceCard(source: _source!, pageCount: _pageCount),
                      const SizedBox(height: SiliphSpacing.md),
                      SegmentedButton<_SplitMode>(
                        segments: const [
                          ButtonSegment(
                            value: _SplitMode.range,
                            label: Text('Page range'),
                            icon: Icon(Icons.horizontal_rule),
                          ),
                          ButtonSegment(
                            value: _SplitMode.everyN,
                            label: Text('Every N pages'),
                            icon: Icon(Icons.grid_view_outlined),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (selection) =>
                            setState(() => _mode = selection.first),
                      ),
                      const SizedBox(height: SiliphSpacing.md),
                      if (_mode == _SplitMode.range)
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
                        )
                      else
                        TextField(
                          controller: _everyNController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Pages per part',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      const SizedBox(height: SiliphSpacing.sm),
                      Text(
                        _planSummary(),
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

  String _planSummary() {
    final plan = _plan();
    if (plan.isEmpty) return 'No pages selected yet.';
    if (_mode == _SplitMode.range) {
      return 'Extracts pages ${plan.first} of $_pageCount into one new PDF.';
    }
    return 'Creates ${plan.length} ${plan.length == 1 ? 'part' : 'parts'} '
        '(${plan.map((r) => r.toString()).join(', ')}).';
  }

  Widget _buildFooter() {
    if (_phase == _Phase.splitting) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Splitting… ${(_progress * 100).round()}%'),
          const SizedBox(height: SiliphSpacing.xs),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: SiliphSpacing.md),
          OutlinedButton(onPressed: _cancelSplit, child: const Text('Cancel')),
        ],
      );
    }

    final plan = _plan();
    final valid = _planProblem(plan) == null;
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
          onPressed: valid ? _split : null,
          icon: const Icon(Icons.content_cut),
          label: Text(
            _mode == _SplitMode.range
                ? 'Split ${plan.isEmpty ? '' : 'pages ${plan.first}'}'
                : 'Split into ${plan.length} ${plan.length == 1 ? 'part' : 'parts'}',
          ),
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
            const Icon(Icons.content_cut_outlined, size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Split a PDF', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Choose a PDF, then split it by a page range or into equal parts.',
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

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.pageCount});

  final FileItem source;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf_outlined),
        title: Text(
          source.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('$pageCount pages'),
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
  const _DoneView({required this.outputs, required this.onStartOver});

  final List<FileItem> outputs;
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
            Text(
              outputs.length == 1 ? 'Split complete' : 'Saved ${outputs.length} parts',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              outputs.map((f) => f.displayName).join('\n'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton(onPressed: onStartOver, child: const Text('Split another')),
          ],
        ),
      ),
    );
  }
}
