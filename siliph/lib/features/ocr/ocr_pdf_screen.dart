/// PDF OCR workflow: extract text from every page of a scanned PDF
/// (section 50 tool-screen standard). Pages are rendered on-device and
/// recognized by the bundled ML Kit recognizer; nothing leaves the device.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';
import '../../generated/siliph_bridge.g.dart';

enum _Phase { pick, running, done }

class OcrPdfScreen extends ConsumerStatefulWidget {
  const OcrPdfScreen({super.key});

  @override
  ConsumerState<OcrPdfScreen> createState() => _OcrPdfScreenState();
}

class _OcrPdfScreenState extends ConsumerState<OcrPdfScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  bool _picking = false;
  double _progress = 0;
  List<OcrBlock> _blocks = const [];
  String? _error;
  String? _notice;
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
          unawaited(_recognize(picked.first));
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

  Future<void> _recognize(FileItem input) async {
    final handle = ref.read(ocrGatewayProvider).recognizePdf(input: input);
    _progressSub = handle.progress.listen((value) {
      if (mounted) setState(() => _progress = value);
    });
    setState(() {
      _phase = _Phase.running;
      _progress = 0;
      _error = null;
    });
    try {
      final blocks = await handle.ocrBlocks;
      await handle.done;
      if (!mounted) return;
      setState(() {
        _blocks = blocks ?? const [];
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.pick;
        _input = null;
        _error = e is BridgeException ? e.userMessage : 'Recognition failed.';
      });
    } finally {
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }

  Future<void> _copyAll() async {
    final text = _blocks.map((b) => b.text).join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _notice = 'All text copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF OCR')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(picking: _picking, onPick: _pick),
                _Phase.running => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(SiliphSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Recognizing pages… ${(_progress * 100).toInt()}%',
                              style:
                                  Theme.of(context).textTheme.titleMediumStyle),
                          const SizedBox(height: SiliphSpacing.md),
                          LinearProgressIndicator(value: _progress),
                        ],
                      ),
                    ),
                  ),
                _Phase.done => _ResultView(
                    fileName: _input?.displayName ?? '',
                    blocks: _blocks,
                    notice: _notice,
                    onCopyAll: _copyAll,
                    onRestart: () => setState(() {
                          _phase = _Phase.pick;
                          _input = null;
                          _blocks = const [];
                          _notice = null;
                          _error = null;
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
            const Icon(Icons.text_snippet_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Extract text from a PDF',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Every page is rendered and recognized on this device.',
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

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.fileName,
    required this.blocks,
    required this.notice,
    required this.onCopyAll,
    required this.onRestart,
  });

  final String fileName;
  final List<OcrBlock> blocks;
  final String? notice;
  final VoidCallback onCopyAll;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    // Group blocks by page for readable per-page sections.
    final byPage = <int, List<OcrBlock>>{};
    for (final block in blocks) {
      byPage.putIfAbsent(block.pageIndex, () => []).add(block);
    }
    final pages = byPage.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  blocks.isEmpty
                      ? 'No text recognized in "$fileName"'
                      : 'Found text on ${pages.length} '
                          '${pages.length == 1 ? 'page' : 'pages'}',
                  style: Theme.of(context).textTheme.titleMediumStyle,
                ),
              ),
              TextButton.icon(
                onPressed: blocks.isEmpty ? null : onCopyAll,
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Copy all'),
              ),
            ],
          ),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: SiliphSpacing.xs),
              child: Text(notice!, style: Theme.of(context).textTheme.bodySmall),
            ),
          Expanded(
            child: blocks.isEmpty
                ? Center(
                    child: Text(
                      'This PDF may already contain selectable text, or its '
                      'pages may be too blurry for recognition.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    itemCount: pages.length,
                    itemBuilder: (context, i) {
                      final page = pages[i];
                      final text =
                          byPage[page]!.map((b) => b.text).join('\n');
                      return Card(
                        margin:
                            const EdgeInsets.only(bottom: SiliphSpacing.sm),
                        child: Padding(
                          padding: const EdgeInsets.all(SiliphSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Page ${page + 1}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMediumStyle),
                              const SizedBox(height: SiliphSpacing.xs),
                              SelectableText(
                                text,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: SiliphSpacing.sm),
          OutlinedButton(
              onPressed: onRestart, child: const Text('Choose another PDF')),
        ],
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
