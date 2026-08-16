/// Extract ZIP workflow (section 50 tool-screen standard).
///
/// Unpacks an archive into a folder the user picks. Unsafe entry names
/// (absolute paths, path traversal) are skipped on the native side rather
/// than written.
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

class ZipExtractScreen extends ConsumerStatefulWidget {
  const ZipExtractScreen({super.key});

  @override
  ConsumerState<ZipExtractScreen> createState() => _ZipExtractScreenState();
}

class _ZipExtractScreenState extends ConsumerState<ZipExtractScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _archive;
  String? _folderUri;
  bool _picking = false;
  double _progress = 0;
  String? _error;
  int _extractedCount = 0;
  StreamSubscription<double>? _progressSub;

  @override
  void dispose() {
    final sub = _progressSub;
    _progressSub = null;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  Future<void> _pickArchive() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await ref.read(fileGatewayProvider).openDocuments(const [
        'application/zip',
        'application/x-zip-compressed',
      ]);
      if (!mounted) return;
      setState(() {
        _picking = false;
        if (picked.isNotEmpty) {
          _archive = picked.first;
          _folderUri = null;
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
    final archive = _archive;
    final folderUri = _folderUri;
    if (archive == null || folderUri == null) return;

    final handle = ref.read(fileToolsGatewayProvider).zipExtract(
          archive: archive,
          folderTreeUri: folderUri,
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
      final uris = await handle.files;
      if (!mounted) return;
      setState(() {
        _extractedCount = uris.length;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.configure;
        _error = e is BridgeException ? e.userMessage : 'Extraction failed.';
      });
    } finally {
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }

  @override
  Widget build(BuildContext context) {
    final archive = _archive;

    return Scaffold(
      appBar: AppBar(title: const Text('Extract ZIP')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick =>
                  _PickView(picking: _picking, onPick: _pickArchive),
                _Phase.configure => _ConfigureView(
                    file: archive!,
                    folderUri: _folderUri,
                    busy: _picking,
                    onPickFolder: _pickFolder,
                    onRun: _run,
                  ),
                _Phase.running => _ProgressView(progress: _progress),
                _Phase.done => _DoneView(
                    count: _extractedCount,
                    folder: folderHint(_folderUri ?? ''),
                    onRestart: () => setState(() {
                          _phase = _Phase.pick;
                          _archive = null;
                          _folderUri = null;
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
            const Icon(Icons.unarchive_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Extract ZIP',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Unpack a ZIP archive into a folder you choose. '
              'Entries with unsafe names are skipped.',
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
                  : const Icon(Icons.folder_zip_outlined),
              label: Text(picking ? 'Opening…' : 'Choose ZIP'),
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
    required this.folderUri,
    required this.busy,
    required this.onPickFolder,
    required this.onRun,
  });

  final FileItem file;
  final String? folderUri;
  final bool busy;
  final VoidCallback onPickFolder;
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
                  const Icon(Icons.folder_zip_outlined,
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
          Text('Extract into',
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
              icon: const Icon(Icons.unarchive_outlined),
              label: Text(
                folderUri == null ? 'Choose a destination folder' : 'Extract',
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
            Text('Extracting… ${(progress * 100).toInt()}%',
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
  const _DoneView({
    required this.count,
    required this.folder,
    required this.onRestart,
  });

  final int count;
  final String folder;
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
            Text('Extraction complete',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              '$count ${count == 1 ? 'file' : 'files'} saved into '
              '"$folder".',
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
