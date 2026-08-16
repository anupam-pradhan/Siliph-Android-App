/// PDF -> Images workflow (section 12, section 50 tool-screen standard).
///
/// Renders every page at the chosen DPI and saves one PNG per page into a
/// folder the user picks (SAF tree).
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

class PdfToImagesScreen extends ConsumerStatefulWidget {
  const PdfToImagesScreen({super.key});

  @override
  ConsumerState<PdfToImagesScreen> createState() => _PdfToImagesScreenState();
}

class _PdfToImagesScreenState extends ConsumerState<PdfToImagesScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  bool _picking = false;
  int _dpi = 150;
  String? _folderUri;
  double _progress = 0;
  String? _error;
  int _createdCount = 0;
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
    final input = _input;
    final folderUri = _folderUri;
    if (input == null || folderUri == null) return;

    final handle = ref.read(pdfGatewayProvider).pdfToImages(
          input: input,
          dpi: _dpi,
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
        _createdCount = uris.length;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.configure;
        _error = e is BridgeException ? e.userMessage : 'Rendering failed.';
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

    return Scaffold(
      appBar: AppBar(title: const Text('PDF to Images')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(picking: _picking, onPick: _pick),
                _Phase.configure => _ConfigureView(
                    file: input!,
                    dpi: _dpi,
                    folderUri: _folderUri,
                    busy: _picking,
                    onDpi: (value) => setState(() => _dpi = value),
                    onPickFolder: _pickFolder,
                    onRun: _run,
                  ),
                _Phase.running => _ProgressView(progress: _progress),
                _Phase.done => _DoneView(
                    count: _createdCount,
                    folder: folderHint(_folderUri ?? ''),
                    onRestart: () => setState(() {
                          _phase = _Phase.pick;
                          _input = null;
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
            const Icon(Icons.photo_library_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('PDF to Images',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Save every page of a PDF as a PNG image.',
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
    required this.dpi,
    required this.folderUri,
    required this.busy,
    required this.onDpi,
    required this.onPickFolder,
    required this.onRun,
  });

  final FileItem file;
  final int dpi;
  final String? folderUri;
  final bool busy;
  final ValueChanged<int> onDpi;
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
          Text('Quality', style: Theme.of(context).textTheme.titleMediumStyle),
          const SizedBox(height: SiliphSpacing.xs),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 100, label: Text('Small')),
              ButtonSegment(value: 150, label: Text('Balanced')),
              ButtonSegment(value: 200, label: Text('Sharp')),
            ],
            selected: {dpi},
            onSelectionChanged: (selection) => onDpi(selection.first),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Text('Save into',
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
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                folderUri == null ? 'Choose a destination folder' : 'Render pages',
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
            Text('Rendering pages… ${(progress * 100).toInt()}%',
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
            const Icon(Icons.check_circle, size: 64, color: SiliphColors.success),
            const SizedBox(height: SiliphSpacing.md),
            Text('Pages saved',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              '$count ${count == 1 ? 'image' : 'images'} saved into '
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
