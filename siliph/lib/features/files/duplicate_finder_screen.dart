/// Duplicate Finder workflow (section 50 tool-screen standard).
///
/// Scans a folder the user picks: files are first grouped by size, then only
/// size-matched candidates are hashed (SHA-256) on the native side. Results
/// are report-only — the user deletes duplicates themselves (section 61).
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

enum _Phase { pick, scanning, done }

class DuplicateFinderScreen extends ConsumerStatefulWidget {
  const DuplicateFinderScreen({super.key});

  @override
  ConsumerState<DuplicateFinderScreen> createState() =>
      _DuplicateFinderScreenState();
}

class _DuplicateFinderScreenState extends ConsumerState<DuplicateFinderScreen> {
  _Phase _phase = _Phase.pick;
  String? _folderUri;
  bool _picking = false;
  double _progress = 0;
  String? _error;
  List<DuplicateGroup> _groups = const [];
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

    final handle =
        ref.read(fileToolsGatewayProvider).findDuplicates(folderTreeUri: folderUri);
    _progressSub = handle.progress.listen((value) {
      if (mounted) setState(() => _progress = value);
    });
    setState(() {
      _phase = _Phase.scanning;
      _progress = 0;
      _error = null;
    });
    try {
      await handle.done;
      final groups = await handle.duplicates ?? const <DuplicateGroup>[];
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.pick;
        _error = e is BridgeException ? e.userMessage : 'Scan failed.';
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
      appBar: AppBar(title: const Text('Duplicate Finder')),
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
                _Phase.scanning => _ProgressView(progress: _progress),
                _Phase.done => _ResultsView(
                    groups: _groups,
                    onRestart: () => setState(() {
                          _phase = _Phase.pick;
                          _groups = const [];
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
          Center(
            child: const Icon(Icons.copy_all_outlined,
                size: 64, color: SiliphColors.primary),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Center(
            child: Text('Duplicate Finder',
                style: Theme.of(context).textTheme.headlineSmallStyle),
          ),
          const SizedBox(height: SiliphSpacing.xs),
          Center(
            child: Text(
              'Finds files with identical content (by hash), not just the '
              'same name. Nothing is deleted automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: SiliphSpacing.lg),
          Text('Folder to scan',
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
              icon: const Icon(Icons.manage_search_outlined),
              label: Text(
                folderUri == null ? 'Choose a folder to scan' : 'Find duplicates',
              ),
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
            Text('Scanning… ${(progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.titleMediumStyle),
            const SizedBox(height: SiliphSpacing.md),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Large folders can take a while — only same-size files '
              'are hashed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.groups, required this.onRestart});

  final List<DuplicateGroup> groups;
  final VoidCallback onRestart;

  int get _reclaimableBytes =>
      groups.fold(0, (sum, g) => sum + g.sizeBytes * (g.uris.length - 1));

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SiliphSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  size: 64, color: SiliphColors.success),
              const SizedBox(height: SiliphSpacing.md),
              Text('No duplicates found',
                  style: Theme.of(context).textTheme.headlineSmallStyle),
              const SizedBox(height: SiliphSpacing.lg),
              OutlinedButton(onPressed: onRestart, child: const Text('Done')),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${groups.length} duplicate '
            '${groups.length == 1 ? 'group' : 'groups'} · '
            '${formatBytes(_reclaimableBytes)} reclaimable',
            style: Theme.of(context).textTheme.titleMediumStyle,
          ),
          const SizedBox(height: SiliphSpacing.xs),
          Text(
            'Keeping one copy of each group frees the reclaimable space. '
            'Use Delete File to remove copies you no longer need.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SiliphSpacing.sm),
          Expanded(
            child: ListView.separated(
              itemCount: groups.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: SiliphSpacing.xs),
              itemBuilder: (context, index) {
                final group = groups[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(SiliphSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatBytes(group.sizeBytes)} × '
                          '${group.uris.length} copies',
                          style:
                              Theme.of(context).textTheme.titleMediumStyle,
                        ),
                        const SizedBox(height: SiliphSpacing.xs),
                        for (final uri in group.uris)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: SiliphSpacing.xs / 2),
                            child: Row(
                              children: [
                                const Icon(Icons.insert_drive_file_outlined,
                                    size: 16, color: SiliphColors.primary),
                                const SizedBox(width: SiliphSpacing.xs),
                                Expanded(
                                  child: Text(
                                    displayNameFromUri(uri),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
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
