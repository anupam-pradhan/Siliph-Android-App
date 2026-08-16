/// Merge PDF workflow (section 50 tool-screen standard, sections 5, 180).
///
/// Pick -> order -> merge -> save-as. Every state is honest: no fake
/// progress, real cancellation, typed error copy from the bridge.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';
import '../../widgets/common/empty_state.dart';

class _MergeEntry {
  _MergeEntry({required this.file});

  final FileItem file;
  int? pageCount;
  bool encrypted = false;
}

enum _Phase { idle, merging, done }

class MergePdfScreen extends ConsumerStatefulWidget {
  const MergePdfScreen({super.key});

  @override
  ConsumerState<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends ConsumerState<MergePdfScreen> {
  final List<_MergeEntry> _entries = [];
  _Phase _phase = _Phase.idle;
  bool _adding = false;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  TaskHandle? _activeTask;
  StreamSubscription<double>? _progressSub;

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _addPdfs() async {
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      final picked =
          await ref.read(fileGatewayProvider).openDocuments(['application/pdf']);
      if (!mounted) return;
      if (picked.isEmpty) {
        setState(() => _adding = false);
        return;
      }
      await _appendEntries(picked);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adding = false;
        _error = 'Could not open the file picker.';
      });
    }
  }

  Future<void> _appendEntries(List<FileItem> files) async {
    final pdfs = ref.read(pdfGatewayProvider);
    final rejected = <String>[];

    for (final file in files) {
      if (_entries.any((e) => e.file.uri == file.uri)) continue;
      final entry = _MergeEntry(file: file);
      try {
        final info = await pdfs.inspect(file);
        entry.pageCount = info.pageCount;
        entry.encrypted = info.encrypted;
      } on BridgeException {
        rejected.add(file.displayName);
        continue;
      }
      _entries.add(entry);
    }

    if (!mounted) return;
    setState(() {
      _adding = false;
      if (rejected.isNotEmpty) {
        _error = rejected.length == 1
            ? '"${rejected.first}" is not a readable PDF and was skipped.'
            : '${rejected.length} files were not readable PDFs and were skipped.';
      }
    });
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _entries.length) return;
    setState(() {
      final entry = _entries.removeAt(index);
      _entries.insert(target, entry);
    });
  }

  void _remove(int index) {
    setState(() => _entries.removeAt(index));
  }

  Future<void> _merge() async {
    if (_entries.length < 2 || _phase == _Phase.merging) return;
    setState(() {
      _phase = _Phase.merging;
      _progress = 0;
      _error = null;
    });

    final files = ref.read(fileGatewayProvider);
    final FileItem? output;
    try {
      output = await files.createDocument(
        mimeType: 'application/pdf',
        displayName: 'Siliph merged.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _error = 'Could not create the output file.';
      });
      return;
    }
    if (output == null) {
      // User cancelled the save-as dialog.
      if (!mounted) return;
      setState(() => _phase = _Phase.idle);
      return;
    }

    final handle = ref.read(pdfGatewayProvider).merge(
          inputs: _entries.map((e) => e.file).toList(),
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
        _phase = _Phase.idle;
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

  Future<void> _cancelMerge() async {
    await _activeTask?.cancel();
  }

  Future<void> _startOver() async {
    setState(() {
      _phase = _Phase.idle;
      _entries.clear();
      _output = null;
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Merge PDF')),
      body: SafeArea(
        child: _phase == _Phase.done
            ? _SuccessView(output: _output, onStartOver: _startOver)
            : Column(
                children: [
                  Expanded(
                    child: _entries.isEmpty && !_adding
                        ? EmptyState(
                            icon: Icons.merge_type_outlined,
                            title: 'No PDFs yet',
                            message: 'Add at least two PDFs to merge them into one.',
                            actions: [EmptyStateAction('Add PDFs', _addPdfs)],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(SiliphSpacing.md),
                            itemCount: _entries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: SiliphSpacing.sm),
                            itemBuilder: (context, index) =>
                                _EntryCard(
                              entry: _entries[index],
                              index: index,
                              count: _entries.length,
                              busy: _phase == _Phase.merging,
                              onMove: _move,
                              onRemove: _remove,
                            ),
                          ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SiliphSpacing.md,
                      ),
                      child: _ErrorBanner(message: _error!),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(SiliphSpacing.md),
                    child: _buildFooter(textTheme),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFooter(TextTheme textTheme) {
    if (_phase == _Phase.merging) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Merging… ${( _progress * 100).round()}%',
            style: textTheme.labelMedium,
          ),
          const SizedBox(height: SiliphSpacing.xs),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: SiliphSpacing.md),
          OutlinedButton(
            onPressed: _cancelMerge,
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    final canMerge = _entries.length >= 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _adding ? null : _addPdfs,
          icon: _adding
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: Text(_adding ? 'Reading PDFs…' : 'Add PDFs'),
        ),
        const SizedBox(height: SiliphSpacing.sm),
        FilledButton.icon(
          onPressed: canMerge ? _merge : null,
          icon: const Icon(Icons.merge_type),
          label: Text(
            canMerge
                ? 'Merge ${_entries.length} PDFs'
                : 'Merge (add ${2 - _entries.length} more)',
          ),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.index,
    required this.count,
    required this.busy,
    required this.onMove,
    required this.onRemove,
  });

  final _MergeEntry entry;
  final int index;
  final int count;
  final bool busy;
  final void Function(int index, int delta) onMove;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final pages = entry.pageCount;
    final subtitle = <String>[
      if (entry.file.formattedSize.isNotEmpty) entry.file.formattedSize,
      if (pages != null) '$pages ${pages == 1 ? 'page' : 'pages'}',
      if (entry.encrypted) 'Encrypted',
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SiliphSpacing.sm,
          vertical: SiliphSpacing.xxs,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: SiliphColors.primary.withValues(alpha: 0.12),
              child: Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const SizedBox(width: SiliphSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.file.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              tooltip: 'Move up',
              onPressed: busy || index == 0 ? null : () => onMove(index, -1),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward),
              tooltip: 'Move down',
              onPressed: busy || index == count - 1 ? null : () => onMove(index, 1),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove',
              onPressed: busy ? null : () => onRemove(index),
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
      margin: const EdgeInsets.only(bottom: SiliphSpacing.sm),
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

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.output, required this.onStartOver});

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
            Text('Merged successfully', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              output == null
                  ? 'Your merged PDF has been saved.'
                  : 'Saved as ${output!.displayName}.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton(onPressed: onStartOver, child: const Text('Merge more')),
          ],
        ),
      ),
    );
  }
}
