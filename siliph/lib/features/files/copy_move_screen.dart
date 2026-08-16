/// Copy / Move File workflow (section 34, section 50 tool-screen standard).
///
/// Both operations share a flow: pick a file, pick a destination folder
/// (SAF tree), run the provider copy/move. Move is honest about providers
/// that refuse it (`not_supported` shows the provider's own guidance).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/file_facts.dart';
import '../../domain/services/native_bridge.dart';

/// Honest, non-technical copy for bridge failures.
String _describeError(Object error) => error is BridgeException
    ? error.userMessage
    : 'Something went wrong. Please try again.';

enum TransferMode { copy, move }

class CopyMoveScreen extends ConsumerStatefulWidget {
  const CopyMoveScreen({super.key, required this.mode});

  final TransferMode mode;

  @override
  ConsumerState<CopyMoveScreen> createState() => _CopyMoveScreenState();
}

class _CopyMoveScreenState extends ConsumerState<CopyMoveScreen> {
  FileItem? _file;
  String? _folderUri;
  bool _busy = false;
  String? _error;
  FileItem? _result;

  String get _verb => widget.mode == TransferMode.copy ? 'Copy' : 'Move';

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ref.read(fileGatewayProvider).openDocuments(const []);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = null;
        _folderUri = null;
        _file = picked.isEmpty ? _file : picked.first;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not open the file picker.';
      });
    }
  }

  Future<void> _pickFolder() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tree = await ref.read(fileGatewayProvider).pickFolder();
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (tree != null) _folderUri = tree;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not open the folder picker.';
      });
    }
  }

  Future<void> _run(FileItem file, String folderUri) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final gateway = ref.read(fileGatewayProvider);
    try {
      final created = widget.mode == TransferMode.copy
          ? await gateway.copy(file, folderUri)
          : await gateway.move(file, folderUri);
      if (!mounted) return;
      if (widget.mode == TransferMode.move) {
        final notifier = ref.read(importedFilesProvider.notifier);
        notifier.remove(file.uri);
        notifier.addAll([created]);
      }
      setState(() {
        _busy = false;
        _result = created;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _describeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: Text('$_verb File')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: result != null
                  ? _DoneView(
                      verb: _verb,
                      file: result,
                      onRestart: _busy ? null : _pickFile,
                    )
                  : _file == null
                      ? _PickView(
                          verb: _verb,
                          picking: _busy,
                          onPick: _pickFile,
                        )
                      : _ReadyView(
                          verb: _verb,
                          file: _file!,
                          folderUri: _folderUri,
                          busy: _busy,
                          onPickFile: _pickFile,
                          onPickFolder: _pickFolder,
                          onRun: () => _run(_file!, _folderUri!),
                        ),
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
    required this.verb,
    required this.picking,
    required this.onPick,
  });

  final String verb;
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
              Icons.drive_file_move_outlined,
              size: 64,
              color: SiliphColors.primary,
            ),
            const SizedBox(height: SiliphSpacing.md),
            Text(
              '$verb a file',
              style: Theme.of(context).textTheme.headlineSmallStyle,
            ),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Pick the file, then choose the destination folder.',
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

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.verb,
    required this.file,
    required this.folderUri,
    required this.busy,
    required this.onPickFile,
    required this.onPickFolder,
    required this.onRun,
  });

  final String verb;
  final FileItem file;
  final String? folderUri;
  final bool busy;
  final VoidCallback onPickFile;
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
                  const Icon(Icons.insert_drive_file_outlined,
                      color: SiliphColors.primary),
                  const SizedBox(width: SiliphSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.displayName,
                          style: Theme.of(context).textTheme.titleMediumStyle,
                        ),
                        Text(
                          file.formattedSize.isEmpty
                              ? 'Size unknown'
                              : file.formattedSize,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: busy ? null : onPickFile,
                    tooltip: 'Choose another file',
                    icon: const Icon(Icons.swap_horiz),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Text('Destination', style: Theme.of(context).textTheme.titleMediumStyle),
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
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_verbIcon(verb)),
              label: Text(
                folderUri == null
                    ? 'Choose a destination folder'
                    : busy
                        ? '${verb}ing…'
                        : '$verb here',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _verbIcon(String verb) =>
    verb == 'Copy' ? Icons.copy : Icons.drive_file_move;

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.verb,
    required this.file,
    required this.onRestart,
  });

  final String verb;
  final FileItem file;
  final VoidCallback? onRestart;

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
            Text(
              verb == 'Copy' ? 'Copied' : 'Moved',
              style: Theme.of(context).textTheme.headlineSmallStyle,
            ),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              verb == 'Copy'
                  ? 'A copy named "${file.displayName}" was created.'
                  : 'The file now lives as "${file.displayName}".',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            OutlinedButton(
              onPressed: onRestart,
              child: Text('$verb another file'),
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
