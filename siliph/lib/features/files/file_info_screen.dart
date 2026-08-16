/// File Information workflow (section 34, section 50 tool-screen standard).
///
/// Pick a file -> show honest facts from the documents provider: name,
/// type, size, last-modified and provider. Nothing is mutated.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/file_facts.dart';

class FileInfoScreen extends ConsumerStatefulWidget {
  const FileInfoScreen({super.key});

  @override
  ConsumerState<FileInfoScreen> createState() => _FileInfoScreenState();
}

class _FileInfoScreenState extends ConsumerState<FileInfoScreen> {
  FileItem? _file;
  bool _picking = false;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await ref.read(fileGatewayProvider).openDocuments(const []);
      if (!mounted) return;
      setState(() {
        _picking = false;
        _file = picked.isEmpty ? _file : picked.first;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'Could not open the file picker.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;

    return Scaffold(
      appBar: AppBar(title: const Text('File Information')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: file == null
                  ? _PickView(picking: _picking, onPick: _pick)
                  : ListView(
                      padding: const EdgeInsets.all(SiliphSpacing.md),
                      children: [
                        _FactRow(label: 'Name', value: file.displayName),
                        _FactRow(
                          label: 'Type',
                          value: file.mimeType ?? 'Unknown',
                        ),
                        _FactRow(
                          label: 'Size',
                          value: file.formattedSize.isEmpty
                              ? 'Unknown'
                              : file.formattedSize,
                        ),
                        _FactRow(
                          label: 'Modified',
                          value: formatModifiedMillis(file.lastModifiedMillis),
                        ),
                        _FactRow(
                          label: 'Provider',
                          value: providerAuthority(file.uri).isEmpty
                              ? 'Unknown'
                              : providerAuthority(file.uri),
                        ),
                      ],
                    ),
            ),
            if (_error != null) _ErrorBanner(message: _error!),
            if (file != null)
              Padding(
                padding: const EdgeInsets.all(SiliphSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _picking ? null : _pick,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Inspect another file'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: SiliphSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SiliphSpacing.md,
          vertical: SiliphSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMediumStyle,
              ),
            ),
            Expanded(
              child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
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
              Icons.description_outlined,
              size: 64,
              color: SiliphColors.primary,
            ),
            const SizedBox(height: SiliphSpacing.md),
            Text(
              'Inspect a file',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'See the name, type, size and last-modified date reported '
              'by the place the file lives.',
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
