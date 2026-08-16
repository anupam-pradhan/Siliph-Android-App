/// Rename File workflow (section 34 file utilities, section 50 standard).
///
/// Pick any SAF document -> type a new name -> DocumentsContract rename.
/// The extension is kept visible as a fixed suffix so users rarely break
/// the file type, but nothing stops them from changing it either.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/file_names.dart';
import '../../domain/services/native_bridge.dart';

enum _Phase { pick, configure, renaming, done }

class RenameFileScreen extends ConsumerStatefulWidget {
  const RenameFileScreen({super.key});

  @override
  ConsumerState<RenameFileScreen> createState() => _RenameFileScreenState();
}

class _RenameFileScreenState extends ConsumerState<RenameFileScreen> {
  FileItem? _source;
  String _extension = '';
  final TextEditingController _nameController = TextEditingController();
  _Phase _phase = _Phase.pick;
  bool _picking = false;
  String? _error;
  FileItem? _renamed;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _typedName => _nameController.text.trim() + _extension;

  String? get _problem {
    final source = _source;
    if (source == null) return 'Choose a file first.';
    final problem = renameProblem(_typedName);
    if (problem != null) return problem;
    if (isEffectivelyUnchanged(_typedName, source.displayName)) {
      return 'The name is unchanged.';
    }
    return null;
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await ref.read(fileGatewayProvider).openDocuments(const []);
      if (!mounted) return;
      if (picked.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final file = picked.first;
      final (base, extension) = splitExtension(file.displayName);
      setState(() {
        _picking = false;
        _source = file;
        _extension = extension;
        _nameController.text = base;
        _phase = _Phase.configure;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'Could not open the file picker.';
      });
    }
  }

  Future<void> _rename() async {
    final source = _source;
    final problem = _problem;
    if (source == null || problem != null || _phase == _Phase.renaming) {
      if (problem != null) setState(() => _error = problem);
      return;
    }
    setState(() {
      _phase = _Phase.renaming;
      _error = null;
    });
    try {
      final renamed =
          await ref.read(fileGatewayProvider).rename(source, _typedName);
      if (!mounted) return;
      // Keep the recent list honest: old entry out, renamed entry in.
      final imported = ref.read(importedFilesProvider.notifier);
      imported.remove(source.uri);
      imported.addAll([renamed]);
      setState(() {
        _phase = _Phase.done;
        _renamed = renamed;
      });
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.configure;
        _error = e.userMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.configure;
        _error = 'Could not rename the file.';
      });
    }
  }

  void _startOver() {
    setState(() {
      _phase = _Phase.pick;
      _source = null;
      _extension = '';
      _nameController.clear();
      _renamed = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Rename File')),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.done => _DoneView(
              source: _source!,
              renamed: _renamed,
              onStartOver: _startOver,
            ),
          _Phase.pick => _PickView(picking: _picking, onPick: _pick),
          _ => Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(SiliphSpacing.md),
                    children: [
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.insert_drive_file_outlined),
                          title: Text(
                            _source!.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              if (_source!.formattedSize.isNotEmpty)
                                _source!.formattedSize,
                              if (_source!.mimeType != null) _source!.mimeType!,
                            ].join(' · '),
                          ),
                        ),
                      ),
                      const SizedBox(height: SiliphSpacing.md),
                      TextField(
                        controller: _nameController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'New name',
                          suffixText: _extension.isEmpty ? null : _extension,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: SiliphSpacing.xs),
                      Text(
                        _problem == null
                            ? 'Will be saved as "$_typedName".'
                            : _problem!,
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
    if (_phase == _Phase.renaming) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: SiliphSpacing.md),
          const OutlinedButton(onPressed: null, child: Text('Renaming…')),
        ],
      );
    }

    final valid = _problem == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _picking ? null : _pick,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Choose a different file'),
        ),
        const SizedBox(height: SiliphSpacing.sm),
        FilledButton.icon(
          onPressed: valid ? _rename : null,
          icon: const Icon(Icons.drive_file_rename_outline),
          label: const Text('Rename'),
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
              Icons.drive_file_rename_outline,
              size: 64,
              color: SiliphColors.primary,
            ),
            const SizedBox(height: SiliphSpacing.md),
            Text('Rename a file', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Choose a file, then give it a new name. The rename happens '
              'where the file lives, so no copy is made.',
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
              label: Text(picking ? 'Opening…' : 'Choose file'),
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
  const _DoneView({
    required this.source,
    required this.renamed,
    required this.onStartOver,
  });

  final FileItem source;
  final FileItem? renamed;

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
            Text('Renamed', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              '"${source.displayName}" is now '
              '"${renamed?.displayName ?? ''}".',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton(onPressed: onStartOver, child: const Text('Rename another')),
          ],
        ),
      ),
    );
  }
}
