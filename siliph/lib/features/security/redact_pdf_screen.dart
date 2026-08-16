/// Redact PDF workflow: mark regions on rendered pages and permanently
/// burn black boxes over them (section 50 tool-screen standard).
///
/// Honesty contract shown to the user: marked pages are re-rendered and
/// rebuilt as images, so the covered pixels are truly gone — this is
/// irreversible and the original text under a mark cannot be recovered.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/file_facts.dart';
import '../../domain/services/native_bridge.dart';
import '../../generated/siliph_bridge.g.dart';

enum _Phase { pick, edit, running, done }

class RedactPdfScreen extends ConsumerStatefulWidget {
  const RedactPdfScreen({super.key});

  @override
  ConsumerState<RedactPdfScreen> createState() => _RedactPdfScreenState();
}

class _RedactPdfScreenState extends ConsumerState<RedactPdfScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  bool _busy = false;
  int _pageCount = 0;
  int _pageNumber = 1; // one-based

  Uint8List? _bytes;
  bool _rendering = false;
  double _aspect = 0.75;
  TaskHandle? _activeRender;

  /// Normalized redaction rectangles keyed by zero-based page index.
  final Map<int, List<Rect>> _marks = {};
  Rect? _liveRect;

  FileItem? _output;
  String? _error;

  int get _totalMarks =>
      _marks.values.fold(0, (sum, list) => sum + list.length);

  @override
  void dispose() {
    final handle = _activeRender;
    if (handle != null) unawaited(handle.cancel().catchError((_) {}));
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ref
          .read(fileGatewayProvider)
          .openDocuments(const ['application/pdf']);
      if (picked.isEmpty || !mounted) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final info = await ref.read(pdfGatewayProvider).inspect(picked.first);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _input = picked.first;
        _pageCount = info.pageCount;
        _pageNumber = 1;
        _marks.clear();
        _phase = _Phase.edit;
      });
      unawaited(_loadPage(1));
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.userMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not open the file picker.';
      });
    }
  }

  Future<void> _loadPage(int pageNumber) async {
    final input = _input;
    if (input == null) return;
    final handle = ref.read(pdfGatewayProvider).renderPage(
          input: input,
          pageIndex: pageNumber - 1,
          dpi: 120,
        );
    _activeRender = handle;
    setState(() {
      _rendering = true;
      _error = null;
    });
    try {
      final bytes = await handle.image;
      await handle.done;
      final codec = await ui.instantiateImageCodec(bytes!);
      final frame = await codec.getNextFrame();
      final aspect = frame.image.width / frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (!mounted || _pageNumber != pageNumber) return;
      setState(() {
        _bytes = bytes;
        _aspect = aspect;
        _rendering = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _rendering = false;
        _error = e is BridgeException ? e.userMessage : 'Rendering failed.';
      });
    } finally {
      if (_activeRender == handle) _activeRender = null;
    }
  }

  void _go(int pageNumber) {
    if (pageNumber < 1 || pageNumber > _pageCount || _rendering) return;
    setState(() {
      _pageNumber = pageNumber;
      _bytes = null;
      _liveRect = null;
    });
    unawaited(_loadPage(pageNumber));
  }

  Offset _normalized(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return Offset.zero;
    return Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
  }

  Future<void> _save() async {
    final input = _input;
    if (input == null || _totalMarks == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redaction is permanent'),
        content: const Text(
          'Every marked region will be replaced with a solid black box and '
          'the page rebuilt. The original content under the marks cannot be '
          'recovered. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Redact'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _phase = _Phase.running;
      _error = null;
    });
    try {
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'application/pdf',
            displayName: '${baseName(input)}-redacted.pdf',
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _phase = _Phase.edit);
        return;
      }
      final marks = [
        for (final entry in _marks.entries)
          for (final rect in entry.value)
            RedactionMark(
              pageIndex: entry.key,
              left: rect.left,
              top: rect.top,
              right: rect.right,
              bottom: rect.bottom,
            ),
      ];
      final handle = ref.read(pdfGatewayProvider).redact(
            input: input,
            marks: marks,
            output: output,
          );
      await handle.done;
      if (!mounted) return;
      setState(() {
        _output = output;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.edit;
        _error = e is BridgeException ? e.userMessage : 'Redaction failed.';
      });
    }
  }

  Future<void> _share() async {
    final output = _output;
    if (output == null) return;
    try {
      await ref.read(fileGatewayProvider).share(output);
    } on BridgeException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
    }
  }

  void _restart() {
    setState(() {
      _phase = _Phase.pick;
      _input = null;
      _bytes = null;
      _marks.clear();
      _output = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Redact PDF')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick => _PickView(picking: _busy, onPick: _pick),
                _Phase.edit => _buildEdit(context),
                _Phase.running => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: SiliphSpacing.md),
                        Text('Redacting…'),
                      ],
                    ),
                  ),
                _Phase.done => _DoneView(
                    name: _output?.displayName ?? 'redacted.pdf',
                    onShare: _share,
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

  Widget _buildEdit(BuildContext context) {
    final pageMarks = _marks[_pageNumber - 1] ?? const [];
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.sm),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous page',
                icon: const Icon(Icons.chevron_left),
                onPressed: _pageNumber > 1 && !_rendering
                    ? () => _go(_pageNumber - 1)
                    : null,
              ),
              Text('Page $_pageNumber of $_pageCount',
                  style: Theme.of(context).textTheme.bodyMedium),
              IconButton(
                tooltip: 'Next page',
                icon: const Icon(Icons.chevron_right),
                onPressed: _pageNumber < _pageCount && !_rendering
                    ? () => _go(_pageNumber + 1)
                    : null,
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: _rendering || _bytes == null
                  ? const CircularProgressIndicator()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = width / _aspect;
                        final size = height <= constraints.maxHeight
                            ? Size(width, height)
                            : Size(constraints.maxHeight * _aspect,
                                constraints.maxHeight);
                        return SizedBox(
                          width: size.width,
                          height: size.height,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(_bytes!,
                                  fit: BoxFit.fill, gaplessPlayback: true),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: (d) {
                                  final p =
                                      _normalized(d.localPosition, size);
                                  setState(
                                      () => _liveRect = Rect.fromPoints(p, p));
                                },
                                onPanUpdate: (d) {
                                  final p =
                                      _normalized(d.localPosition, size);
                                  setState(() => _liveRect = _liveRect == null
                                      ? Rect.fromPoints(p, p)
                                      : Rect.fromPoints(
                                          _liveRect!.topLeft, p));
                                },
                                onPanEnd: (_) {
                                  final rect = _liveRect;
                                  _liveRect = null;
                                  if (rect != null &&
                                      rect.width > 0.005 &&
                                      rect.height > 0.005) {
                                    _marks
                                        .putIfAbsent(
                                            _pageNumber - 1, () => [])
                                        .add(Rect.fromLTRB(
                                          rect.left.clamp(0, 1),
                                          rect.top.clamp(0, 1),
                                          rect.right.clamp(0, 1),
                                          rect.bottom.clamp(0, 1),
                                        ));
                                  }
                                  setState(() {});
                                },
                              ),
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: _RedactionPainter(
                                    rects: pageMarks,
                                    live: _liveRect,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _totalMarks == 0
                      ? 'Drag over text to mark it for redaction'
                      : '$_totalMarks ${_totalMarks == 1 ? 'region' : 'regions'} marked',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: SiliphSpacing.sm),
                IconButton(
                  tooltip: 'Clear marks on this page',
                  icon: const Icon(Icons.undo),
                  onPressed: pageMarks.isEmpty
                      ? null
                      : () => setState(() => _marks.remove(_pageNumber - 1)),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _totalMarks == 0 || _rendering ? null : _save,
              icon: const Icon(Icons.visibility_off_outlined),
              label: Text(_totalMarks == 0
                  ? 'Mark regions to redact first'
                  : 'Redact permanently'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RedactionPainter extends CustomPainter {
  const _RedactionPainter({required this.rects, required this.live});

  final List<Rect> rects;
  final Rect? live;

  @override
  void paint(Canvas canvas, Size size) {
    for (final rect in rects) {
      _paintRect(canvas, size, rect, dashed: false);
    }
    final current = live;
    if (current != null) _paintRect(canvas, size, current, dashed: true);
  }

  void _paintRect(Canvas canvas, Size size, Rect rect, {required bool dashed}) {
    final r = Rect.fromLTRB(
      rect.left * size.width,
      rect.top * size.height,
      rect.right * size.width,
      rect.bottom * size.height,
    );
    canvas.drawRect(
      r,
      Paint()..color = Colors.black.withValues(alpha: dashed ? 0.35 : 0.85),
    );
    canvas.drawRect(
      r,
      Paint()
        ..color = SiliphColors.error
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RedactionPainter oldDelegate) => true;
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
            const Icon(Icons.visibility_off_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Redact sensitive content',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Drag boxes over anything sensitive. Marked regions are '
              'permanently replaced with solid black — this cannot be '
              'undone.',
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

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.name,
    required this.onShare,
    required this.onRestart,
  });

  final String name;
  final VoidCallback onShare;
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
            Text('Redaction complete',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              '"$name" no longer contains the marked content. Untouched '
              'pages were copied without changes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share PDF'),
            ),
            const SizedBox(height: SiliphSpacing.sm),
            OutlinedButton(
                onPressed: onRestart, child: const Text('Redact another')),
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
