/// Delete File workflow (section 34, section 50 tool-screen standard).
///
/// SAF deletion is permanent — the screen forces an explicit confirmation
/// dialog before calling the gateway (section 60 honesty: no silent loss).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';

/// Honest, non-technical copy for bridge failures.
String _describeError(Object error) => error is BridgeException
    ? error.userMessage
    : 'Something went wrong. Please try again.';

class DeleteFileScreen extends ConsumerStatefulWidget {
  const DeleteFileScreen({super.key});

  @override
  ConsumerState<DeleteFileScreen> createState() => _DeleteFileScreenState();
}

class _DeleteFileScreenState extends ConsumerState<DeleteFileScreen> {
  FileItem? _file;
  bool _busy = false;
  String? _error;
  String? _deletedName;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ref.read(fileGatewayProvider).openDocuments(const []);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _deletedName = null;
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

  Future<void> _confirmDelete(FileItem file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this file?'),
        content: Text(
          '"${file.displayName}" will be permanently deleted. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: SiliphColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final deleted = await ref.read(fileGatewayProvider).delete(file);
      if (!mounted) return;
      if (!deleted) {
        setState(() {
          _busy = false;
          _error = 'The provider could not delete this file.';
        });
        return;
      }
      ref.read(importedFilesProvider.notifier).remove(file.uri);
      setState(() {
        _busy = false;
        _file = null;
        _deletedName = file.displayName;
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
    final file = _file;
    final deletedName = _deletedName;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete File')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: deletedName != null
                  ? _DoneView(name: deletedName, onPick: _busy ? null : _pick)
                  : file == null
                      ? _PickView(picking: _busy, onPick: _pick)
                      : _ConfirmView(
                          file: file,
                          busy: _busy,
                          onDelete: () => _confirmDelete(file),
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
              Icons.delete_outline,
              size: 64,
              color: SiliphColors.error,
            ),
            const SizedBox(height: SiliphSpacing.md),
            Text(
              'Delete a file',
              style: Theme.of(context).textTheme.headlineSmallStyle,
            ),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Pick the file to delete. You will be asked to confirm.',
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

class _ConfirmView extends StatelessWidget {
  const _ConfirmView({
    required this.file,
    required this.busy,
    required this.onDelete,
  });

  final FileItem file;
  final bool busy;
  final VoidCallback onDelete;

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
                ],
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Text(
            'Deleting removes the file from its current location for good. '
            'There is no trash or undo.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: SiliphColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: busy ? null : onDelete,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever),
              label: Text(busy ? 'Deleting…' : 'Delete file'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({required this.name, required this.onPick});

  final String name;
  final VoidCallback? onPick;

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
            Text('Deleted', style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              '"$name" was deleted.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            OutlinedButton(
              onPressed: onPick,
              child: const Text('Delete another file'),
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
