/// Storage Analyzer workflow (section 50 tool-screen standard).
///
/// Walks a picked folder on the native side and reports the size of each
/// top-level child. Read-only: nothing is modified or deleted.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/providers.dart';
import '../../domain/services/file_facts.dart';
import '../../domain/services/native_bridge.dart';
import '../../generated/siliph_bridge.g.dart';

enum _Phase { pick, analyzing, done }

class StorageAnalyzerScreen extends ConsumerStatefulWidget {
  const StorageAnalyzerScreen({super.key});

  @override
  ConsumerState<StorageAnalyzerScreen> createState() =>
      _StorageAnalyzerScreenState();
}

class _StorageAnalyzerScreenState
    extends ConsumerState<StorageAnalyzerScreen> {
  _Phase _phase = _Phase.pick;
  String? _folderUri;
  bool _picking = false;
  double _progress = 0;
  String? _error;
  List<StorageEntry> _entries = const [];
  StreamSubscription<double>? _progressSub;

  @override
  void dispose() {
    final sub = _progressSub;
    _progressSub = null;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  Future<void> _pickFolder() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final tree = await ref.read(fileGatewayProvider).pickFolder();
      if (!mounted) return;
      setState(() {
        _picking = false;
        if (tree != null) _folderUri = tree;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'Could not open the folder picker.';
      });
    }
  }

  Future<void> _run() async {
    final folderUri = _folderUri;
    if (folderUri == null) return;

    final handle = ref
        .read(fileToolsGatewayProvider)
        .analyzeStorage(folderTreeUri: folderUri);
    _progressSub = handle.progress.listen((value) {
      if (mounted) setState(() => _progress = value);
    });
    setState(() {
      _phase = _Phase.analyzing;
      _progress = 0;
      _error = null;
    });
    try {
      await handle.done;
      final entries = await handle.storageEntries ?? const <StorageEntry>[];
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.pick;
        _error = e is BridgeException ? e.userMessage : 'Analysis failed.';
      });
    } finally {
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage Analyzer')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(
                    folderUri: _folderUri,
                    busy: _picking,
                    onPickFolder: _pickFolder,
                    onRun: _run,
                  ),
                _Phase.analyzing => _ProgressView(progress: _progress),
                _Phase.done => _ResultsView(
                    folder: folderHint(_folderUri ?? ''),
                    entries: _entries,
                    onRestart: () => setState(() {
                          _phase = _Phase.pick;
                          _entries = const [];
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
  const _PickView({
    required this.folderUri,
    required this.busy,
    required this.onPickFolder,
    required this.onRun,
  });

  final String? folderUri;
  final bool busy;
  final VoidCallback onPickFolder;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Icon(Icons.pie_chart_outline,
                size: 64, color: SiliphColors.primary),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Center(
            child: Text('Storage Analyzer',
                style: Theme.of(context).textTheme.headlineSmallStyle),
          ),
          const SizedBox(height: SiliphSpacing.xs),
          Center(
            child: Text(
              'Shows how much space each item inside a folder uses. '
              'Pick your Downloads or Documents folder to see what takes '
              'up the most room.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: SiliphSpacing.lg),
          Text('Folder to analyze',
              style: Theme.of(context).textTheme.titleMediumStyle),
          const SizedBox(height: SiliphSpacing.xs),
          Card(
            child: InkWell(
              onTap: busy ? null : onPickFolder,
              borderRadius: BorderRadius.circular(SiliphRadii.lg),
              child: Padding(
                padding: const EdgeInsets.all(SiliphSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.folder_outlined,
                        color: SiliphColors.primary),
                    const SizedBox(width: SiliphSpacing.sm),
                    Expanded(
                      child: Text(
                        folderUri == null
                            ? 'Tap to choose a folder'
                            : folderHint(folderUri!),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: folderUri == null || busy ? null : onRun,
              icon: const Icon(Icons.query_stats_outlined),
              label: Text(folderUri == null
                  ? 'Choose a folder to analyze'
                  : 'Analyze'),
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
            Text('Analyzing… ${(progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.titleMediumStyle),
            const SizedBox(height: SiliphSpacing.md),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.folder,
    required this.entries,
    required this.onRestart,
  });

  final String folder;
  final List<StorageEntry> entries;
  final VoidCallback onRestart;

  int get _totalBytes => entries.fold(0, (sum, e) => sum + e.sizeBytes);

  @override
  Widget build(BuildContext context) {
    final total = _totalBytes;

    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"$folder" · ${formatBytes(total)} total',
            style: Theme.of(context).textTheme.titleMediumStyle,
          ),
          const SizedBox(height: SiliphSpacing.sm),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'The folder is empty.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: SiliphSpacing.xs),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final share =
                          total > 0 ? entry.sizeBytes / total : 0.0;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(SiliphSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    entry.folder
                                        ? Icons.folder_outlined
                                        : Icons.insert_drive_file_outlined,
                                    color: SiliphColors.primary,
                                  ),
                                  const SizedBox(width: SiliphSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      entry.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMediumStyle,
                                    ),
                                  ),
                                  Text(
                                    formatBytes(entry.sizeBytes),
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: SiliphSpacing.xs),
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(SiliphRadii.md),
                                child: LinearProgressIndicator(
                                  value: share,
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: SiliphSpacing.xs),
                              Text(
                                entry.folder
                                    ? '${entry.fileCount} '
                                        '${entry.fileCount == 1 ? 'file' : 'files'} · '
                                        '${(share * 100).toStringAsFixed(1)}% of total'
                                    : '${(share * 100).toStringAsFixed(1)}% of total',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(
            width: double.infinity,
            child:
                OutlinedButton(onPressed: onRestart, child: const Text('Done')),
          ),
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
