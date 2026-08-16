/// Searchable PDF workflow: rebuild a scanned PDF with an invisible OCR
/// text layer (section 50 tool-screen standard).
///
/// Honest output contract: each page becomes its rendered image plus
/// approximate invisible text positioned from the recognizer's boxes, so
/// copy/search work but selection may not track the original perfectly.
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

enum _Phase { pick, running, done }

class SearchablePdfScreen extends ConsumerStatefulWidget {
  const SearchablePdfScreen({super.key});

  @override
  ConsumerState<SearchablePdfScreen> createState() =>
      _SearchablePdfScreenState();
}

class _SearchablePdfScreenState extends ConsumerState<SearchablePdfScreen> {
  _Phase _phase = _Phase.pick;
  bool _picking = false;
  double _progress = 0;
  FileItem? _output;
  String? _error;
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
          unawaited(_run(picked.first));
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

  Future<void> _run(FileItem input) async {
    setState(() {
      _phase = _Phase.running;
      _progress = 0;
      _error = null;
    });
    try {
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'application/pdf',
            displayName: '${baseName(input)}-searchable.pdf',
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _phase = _Phase.pick);
        return;
      }
      final handle = ref.read(ocrGatewayProvider).searchablePdf(
            input: input,
            output: output,
          );
      _progressSub = handle.progress.listen((value) {
        if (mounted) setState(() => _progress = value);
      });
      await handle.done;
      if (!mounted) return;
      setState(() {
        _output = output;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.pick;
        _error = e is BridgeException ? e.userMessage : 'Conversion failed.';
      });
    } finally {
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }

  Future<void> _share() async {
    final output = _output;
    if (output == null) return;
    try {
      await ref.read(fileGatewayProvider).share(output);
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Searchable PDF')),
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
                          Text(
                            'Recognizing and rebuilding… '
                            '${(_progress * 100).toInt()}%',
                            style:
                                Theme.of(context).textTheme.titleMediumStyle,
                          ),
                          const SizedBox(height: SiliphSpacing.md),
                          LinearProgressIndicator(value: _progress),
                        ],
                      ),
                    ),
                  ),
                _Phase.done => _DoneView(
                    name: _output?.displayName ?? 'searchable.pdf',
                    onShare: _share,
                    onRestart: () => setState(() {
                          _phase = _Phase.pick;
                          _output = null;
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
            const Icon(Icons.manage_search_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Add a searchable text layer',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Each page is rebuilt as an image with invisible recognized '
              'text underneath, so you can copy and search. Selection is '
              'approximate.',
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

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.name,
    required this.onShare,
    required this.onRestart,
  });

  final String name;
  final VoidCallback onShare;
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
            Text('Searchable copy saved',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              '"$name" is ready. Text inside is recognized automatically, '
              'so selection may be approximate.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share PDF'),
            ),
            const SizedBox(height: SiliphSpacing.sm),
            OutlinedButton(
                onPressed: onRestart, child: const Text('Convert another')),
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
