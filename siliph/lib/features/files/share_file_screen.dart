/// Share File workflow (section 34, section 50 tool-screen standard).
///
/// Pick a file -> hand it to the system share sheet (ACTION_SEND). The
/// share itself is delegated to Android; Siliph only prepares the intent.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';

class ShareFileScreen extends ConsumerStatefulWidget {
  const ShareFileScreen({super.key});

  @override
  ConsumerState<ShareFileScreen> createState() => _ShareFileScreenState();
}

class _ShareFileScreenState extends ConsumerState<ShareFileScreen> {
  FileItem? _file;
  bool _busy = false;
  String? _error;
  bool _shared = false;

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
        _shared = false;
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

  Future<void> _share(FileItem file) async {
    setState(() => _busy = true);
    try {
      await ref.read(fileGatewayProvider).share(file);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _shared = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not open the share sheet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;

    return Scaffold(
      appBar: AppBar(title: const Text('Share File')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: file == null
                  ? _PickView(picking: _busy, onPick: _pick)
                  : _ReadyView(
                      file: file,
                      busy: _busy,
                      shared: _shared,
                      onShare: () => _share(file),
                      onPick: _busy ? null : _pick,
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
            const Icon(Icons.share_outlined, size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text(
              'Share a file',
              style: Theme.of(context).textTheme.headlineSmallStyle,
            ),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Pick a file and send it to any app that accepts it.',
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
    required this.file,
    required this.busy,
    required this.shared,
    required this.onShare,
    required this.onPick,
  });

  final FileItem file;
  final bool busy;
  final bool shared;
  final VoidCallback onShare;
  final VoidCallback? onPick;

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
                          file.mimeType ?? 'Type unknown',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (shared) ...[
            const SizedBox(height: SiliphSpacing.md),
            Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: SiliphColors.primary),
                const SizedBox(width: SiliphSpacing.xs),
                Expanded(
                  child: Text(
                    'The share sheet was opened. Pick a destination app to '
                    'finish sending it.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onShare,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              label: Text(shared ? 'Share again' : 'Share file'),
            ),
          ),
          const SizedBox(height: SiliphSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Share another file'),
            ),
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
