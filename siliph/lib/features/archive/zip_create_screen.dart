/// Create ZIP workflow (section 50 tool-screen standard).
///
/// Collects picked files, then streams them into a single ZIP archive via
/// the native platform APIs. No binary payload crosses the bridge.
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

enum _Phase { configure, running, done }

class ZipCreateScreen extends ConsumerStatefulWidget {
  const ZipCreateScreen({super.key});

  @override
  ConsumerState<ZipCreateScreen> createState() => _ZipCreateScreenState();
}

class _ZipCreateScreenState extends ConsumerState<ZipCreateScreen> {
  _Phase _phase = _Phase.configure;
  final List<FileItem> _files = [];
  bool _picking = false;
  bool _saving = false;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  StreamSubscription<double>? _progressSub;

  @override
  void dispose() {
    final sub = _progressSub;
    _progressSub = null;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  Future<void> _addFiles() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await ref
          .read(fileGatewayProvider)
          .openDocuments(const ['*/*']);
      if (!mounted) return;
      setState(() {
        _picking = false;
        for (final file in picked) {
          if (!_files.any((existing) => existing.uri == file.uri)) {
            _files.add(file);
          }
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

  void _removeAt(int index) {
    setState(() => _files.removeAt(index));
  }

  Future<void> _run() async {
    if (_files.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'application/zip',
            displayName: 'archive.zip',
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _saving = false);
        return; // User cancelled the save dialog.
      }
      final handle = ref.read(fileToolsGatewayProvider).zipCreate(
            inputs: List.of(_files),
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
          _error = e is BridgeException ? e.userMessage : 'Archiving failed.';
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

  void _restart() {
    setState(() {
      _phase = _Phase.configure;
      _files.clear();
      _output = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create ZIP')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.configure => _ConfigureView(
                    files: _files,
                    busy: _picking || _saving,
                    onAdd: _addFiles,
                    onRemove: _removeAt,
                    onRun: _run,
                  ),
                _Phase.running => _ProgressView(progress: _progress),
                _Phase.done => _DoneView(
                    name: _output?.displayName ?? 'archive.zip',
                    count: _files.length,
                    onRestart: _restart,
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

class _ConfigureView extends StatelessWidget {
  const _ConfigureView({
    required this.files,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
    required this.onRun,
  });

  final List<FileItem> files;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Files to compress',
                  style: Theme.of(context).textTheme.titleMediumStyle,
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: SiliphSpacing.xs),
          if (files.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Nothing added yet.\nTap Add to pick files.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: files.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: SiliphSpacing.xs),
                itemBuilder: (context, index) {
                  final file = files[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined,
                          color: SiliphColors.primary),
                      title: Text(file.displayName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(file.formattedSize.isEmpty
                          ? 'Unknown size'
                          : file.formattedSize),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => onRemove(index),
                      ),
                    ),
                  );
                },
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: files.isEmpty || busy ? null : onRun,
              icon: const Icon(Icons.folder_zip_outlined),
              label: Text(files.isEmpty
                  ? 'Add files to compress'
                  : 'Save ZIP (${files.length} '
                      '${files.length == 1 ? 'file' : 'files'})'),
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
  const _DoneView({
    required this.name,
    required this.count,
    required this.onRestart,
  });

  final String name;
  final int count;
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
            Text('Archive saved',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              '$count ${count == 1 ? 'file' : 'files'} compressed into '
              '"$name".',
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
