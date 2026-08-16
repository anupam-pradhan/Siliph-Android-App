/// Page composer workflow (section 50 tool-screen standard, sections 5, 180).
///
/// One screen, three entry points:
///   * extract  -> keep the pages you tick (defaults: all selected)
///   * delete   -> untick the pages to remove (defaults: all selected)
///   * reorder  -> move pages into a new order (defaults: all selected)
///
/// The engine call is always rearrangePages with the displayed order of the
/// selected pages, so the behavior is one code path, fully tested.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';

enum ComposerMode { extract, delete, reorder }

enum _Phase { pick, compose, working, done }

class _Slot {
  _Slot({required this.originalIndex});

  /// Zero-based index in the source PDF.
  final int originalIndex;
  bool selected = true;
}

class PageComposerScreen extends ConsumerStatefulWidget {
  const PageComposerScreen({super.key, required this.mode});

  final ComposerMode mode;

  @override
  ConsumerState<PageComposerScreen> createState() => _PageComposerScreenState();
}

class _PageComposerScreenState extends ConsumerState<PageComposerScreen> {
  FileItem? _source;
  final List<_Slot> _slots = [];
  _Phase _phase = _Phase.pick;
  bool _picking = false;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  TaskHandle? _activeTask;
  StreamSubscription<double>? _progressSub;

  String get _title => switch (widget.mode) {
        ComposerMode.extract => 'Extract Pages',
        ComposerMode.delete => 'Delete Pages',
        ComposerMode.reorder => 'Reorder Pages',
      };

  String get _cta => switch (widget.mode) {
        ComposerMode.extract => 'Extract selected pages',
        ComposerMode.delete => 'Save without deleted pages',
        ComposerMode.reorder => 'Save new order',
      };

  String get _emptyHint => switch (widget.mode) {
        ComposerMode.extract =>
          'Tick the pages to keep, then save them as a new PDF.',
        ComposerMode.delete =>
          'Untick the pages to remove, then save the rest as a new PDF.',
        ComposerMode.reorder =>
          'Move pages up or down, then save the new order.',
      };

  @override
  void dispose() {
    _progressSub?.cancel();
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
          .openDocuments(['application/pdf']);
      if (!mounted) return;
      if (picked.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final info = await ref.read(pdfGatewayProvider).inspect(picked.first);
      if (!mounted) return;
      setState(() {
        _picking = false;
        _source = picked.first;
        _slots
          ..clear()
          ..addAll(
            List.generate(info.pageCount, (i) => _Slot(originalIndex: i)),
          );
        _phase = _Phase.compose;
      });
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = e.userMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'Could not open the file picker.';
      });
    }
  }

  int get _selectedCount => _slots.where((s) => s.selected).length;

  void _toggle(int index) {
    setState(() => _slots[index].selected = !_slots[index].selected);
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _slots.length) return;
    setState(() {
      final slot = _slots.removeAt(index);
      _slots.insert(target, slot);
    });
  }

  void _reverse() {
    setState(() => _slots.replaceRange(0, _slots.length, _slots.reversed.toList()));
  }

  void _setAll(bool selected) {
    setState(() {
      for (final slot in _slots) {
        slot.selected = selected;
      }
    });
  }

  Future<void> _apply() async {
    final selected = _slots.where((s) => s.selected).toList();
    if (selected.isEmpty || _phase == _Phase.working) return;
    setState(() {
      _phase = _Phase.working;
      _progress = 0;
      _error = null;
    });

    final source = _source!;
    final suffix = switch (widget.mode) {
      ComposerMode.extract => '-extracted',
      ComposerMode.delete => '-trimmed',
      ComposerMode.reorder => '-reordered',
    };
    final FileItem? output;
    try {
      output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'application/pdf',
            displayName: '${_baseName(source.displayName)}$suffix.pdf',
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.compose;
        _error = 'Could not create the output file.';
      });
      return;
    }
    if (output == null) {
      // User cancelled the save-as dialog.
      if (!mounted) return;
      setState(() => _phase = _Phase.compose);
      return;
    }

    final handle = ref.read(pdfGatewayProvider).rearrangePages(
          input: source,
          pageOrder: selected.map((s) => s.originalIndex).toList(),
          output: output,
        );
    _activeTask = handle;
    _progressSub = handle.progress.listen((fraction) {
      if (mounted) setState(() => _progress = fraction);
    });

    try {
      await handle.done;
      if (!mounted) return;
      ref.read(importedFilesProvider.notifier).addAll([output]);
      setState(() {
        _phase = _Phase.done;
        _output = output;
      });
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.compose;
        _error = e.isCancelled ? null : e.userMessage;
      });
    } finally {
      _activeTask = null;
      // Never await stream cleanup: a still-draining broadcast subscription
      // would hold up the phase transition.
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }

  Future<void> _cancelWork() async {
    await _activeTask?.cancel();
  }

  void _startOver() {
    setState(() {
      _phase = _Phase.pick;
      _source = null;
      _slots.clear();
      _output = null;
      _progress = 0;
      _error = null;
    });
  }

  String _baseName(String name) => name.toLowerCase().endsWith('.pdf')
      ? name.substring(0, name.length - 4)
      : name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.done => _DoneView(
              output: _output,
              title: _title,
              onStartOver: _startOver,
            ),
          _Phase.pick => _PickView(picking: _picking, onPick: _pick, hint: _emptyHint),
          _ => Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(SiliphSpacing.md),
                    itemCount: _slots.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: SiliphSpacing.xs),
                    itemBuilder: (context, index) => _SlotTile(
                      slot: _slots[index],
                      position: index,
                      count: _slots.length,
                      busy: _phase == _Phase.working,
                      onToggle: () => _toggle(index),
                      onMove: (delta) => _move(index, delta),
                    ),
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
    if (_phase == _Phase.working) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Working… ${(_progress * 100).round()}%'),
          const SizedBox(height: SiliphSpacing.xs),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: SiliphSpacing.md),
          OutlinedButton(onPressed: _cancelWork, child: const Text('Cancel')),
        ],
      );
    }

    final selectedCount = _selectedCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _setAll(true),
                child: const Text('Select all'),
              ),
            ),
            const SizedBox(width: SiliphSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _setAll(false),
                child: const Text('Select none'),
              ),
            ),
            const SizedBox(width: SiliphSpacing.sm),
            Expanded(
              child: OutlinedButton(onPressed: _reverse, child: const Text('Reverse')),
            ),
          ],
        ),
        const SizedBox(height: SiliphSpacing.sm),
        OutlinedButton.icon(
          onPressed: _picking ? null : _pick,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Choose a different PDF'),
        ),
        const SizedBox(height: SiliphSpacing.sm),
        FilledButton.icon(
          onPressed: selectedCount > 0 ? _apply : null,
          icon: const Icon(Icons.save_alt),
          label: Text(
            selectedCount > 0
                ? '$_cta ($selectedCount ${selectedCount == 1 ? 'page' : 'pages'})'
                : _cta,
          ),
        ),
      ],
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.position,
    required this.count,
    required this.busy,
    required this.onToggle,
    required this.onMove,
  });

  final _Slot slot;
  final int position;
  final int count;
  final bool busy;
  final VoidCallback onToggle;
  final void Function(int delta) onMove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SiliphSpacing.sm,
          vertical: SiliphSpacing.xxs,
        ),
        child: Row(
          children: [
            Checkbox(value: slot.selected, onChanged: busy ? null : (_) => onToggle()),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: busy ? null : onToggle,
                child: Text(
                  'Page ${slot.originalIndex + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              tooltip: 'Move earlier',
              onPressed: busy || position == 0 ? null : () => onMove(-1),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward),
              tooltip: 'Move later',
              onPressed: busy || position == count - 1 ? null : () => onMove(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickView extends StatelessWidget {
  const _PickView({
    required this.picking,
    required this.onPick,
    required this.hint,
  });

  final bool picking;
  final VoidCallback onPick;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.view_agenda_outlined,
              size: 64,
              color: SiliphColors.primary,
            ),
            const SizedBox(height: SiliphSpacing.md),
            Text('Choose a PDF', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              hint,
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
              label: Text(picking ? 'Opening…' : 'Choose PDF'),
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
    required this.output,
    required this.title,
    required this.onStartOver,
  });

  final FileItem? output;
  final String title;
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
            Text('Done', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              output == null
                  ? 'Your new PDF has been saved.'
                  : 'Saved as ${output!.displayName}.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton(onPressed: onStartOver, child: Text('Use $title again')),
          ],
        ),
      ),
    );
  }
}
