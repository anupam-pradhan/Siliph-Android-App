/// Passport Photo workflow (section 50 tool-screen standard).
///
/// Tiles a portrait photo onto a printable 4×6in sheet (1200×1800 px at
/// 300 dpi) with 35×45mm photo slots and cut guides. The compositing runs
/// natively via [ImageToolsGateway.passportSheet].
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

enum _Phase { pick, configure, running, done }

class PassportPhotoScreen extends ConsumerStatefulWidget {
  const PassportPhotoScreen({super.key});

  @override
  ConsumerState<PassportPhotoScreen> createState() =>
      _PassportPhotoScreenState();
}

class _PassportPhotoScreenState extends ConsumerState<PassportPhotoScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  bool _picking = false;
  bool _saving = false;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  int _copies = 6;
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
          .openDocuments(const ['image/*']);
      if (!mounted) return;
      setState(() {
        _picking = false;
        if (picked.isNotEmpty) {
          _input = picked.first;
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

  Future<void> _run() async {
    final input = _input;
    if (input == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'image/jpeg',
            displayName: 'passport-sheet.jpg',
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _saving = false);
        return; // User cancelled the save dialog.
      }
      final handle = ref.read(imageToolsGatewayProvider).passportSheet(
            input: input,
            copies: _copies,
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
          _error = e is BridgeException ? e.userMessage : 'Sheet failed.';
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

  @override
  Widget build(BuildContext context) {
    final input = _input;

    return Scaffold(
      appBar: AppBar(title: const Text('Passport Photo')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(picking: _picking, onPick: _pick),
                _Phase.configure => _ConfigureView(
                    file: input!,
                    copies: _copies,
                    onCopies: (value) => setState(() => _copies = value),
                    busy: _saving,
                    onRun: _run,
                  ),
                _Phase.running => _ProgressView(progress: _progress),
                _Phase.done => _DoneView(
                    name: _output?.displayName ?? 'image',
                    onRestart: () => setState(() {
                          _phase = _Phase.pick;
                          _input = null;
                          _output = null;
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
            const Icon(Icons.account_box_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Passport Photo',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Turn one portrait photo into a printable 4×6 sheet of '
              '35×45mm ID photos with cut guides.',
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
                  : const Icon(Icons.image_outlined),
              label: Text(picking ? 'Opening…' : 'Choose photo'),
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
    required this.copies,
    required this.onCopies,
    required this.busy,
    required this.onRun,
  });

  final FileItem file;
  final int copies;
  final ValueChanged<int> onCopies;
  final bool busy;
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
                  const Icon(Icons.image_outlined,
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
          Text('Copies on the sheet',
              style: Theme.of(context).textTheme.titleMediumStyle),
          const SizedBox(height: SiliphSpacing.xs),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1')),
              ButtonSegment(value: 2, label: Text('2')),
              ButtonSegment(value: 3, label: Text('3')),
              ButtonSegment(value: 4, label: Text('4')),
              ButtonSegment(value: 5, label: Text('5')),
              ButtonSegment(value: 6, label: Text('6')),
            ],
            selected: {copies},
            onSelectionChanged: busy
                ? null
                : (selection) => onCopies(selection.first),
          ),
          const SizedBox(height: SiliphSpacing.md),
          Text(
            'The sheet is 4×6 inches at 300 dpi. Each photo is cropped to '
            'the standard 35×45mm ID size and laid out in a 2×3 grid with '
            'light cut guides. Print it as-is on 4×6 photo paper.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onRun,
              icon: const Icon(Icons.grid_on_outlined),
              label: const Text('Save print sheet'),
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
            Text('Building sheet… ${(progress * 100).toInt()}%',
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
  const _DoneView({required this.name, required this.onRestart});

  final String name;
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
            Text('Sheet ready',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Saved the print sheet as "$name". Print on 4×6 photo paper '
              'and cut along the guides.',
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
