/// Annotate PDF workflow: draw ink, highlights and boxes directly onto a
/// rendered page, then bake the marks into the page's content stream so
/// the original text stays selectable (section 50 tool-screen standard).
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

enum _Tool { pen, highlight, box }

/// One committed mark, either ink or a rectangle, normalized 0..1.
sealed class _Mark {
  const _Mark();
}

class _InkMark extends _Mark {
  const _InkMark(this.points, this.colorRgb);
  final List<Offset> points; // normalized
  final int colorRgb;
}

class _RectMarkUi extends _Mark {
  const _RectMarkUi(this.rect, this.mode, this.colorRgb);
  final Rect rect; // normalized
  final String mode; // 'highlight' | 'box'
  final int colorRgb;
}

class AnnotatePdfScreen extends ConsumerStatefulWidget {
  const AnnotatePdfScreen({super.key});

  @override
  ConsumerState<AnnotatePdfScreen> createState() => _AnnotatePdfScreenState();
}

class _AnnotatePdfScreenState extends ConsumerState<AnnotatePdfScreen> {
  static const int _red = 0xE53935;
  static const int _blue = 0x1E88E5;
  static const int _black = 0x212121;
  static const int _yellow = 0xFFD600;

  _Phase _phase = _Phase.pick;
  FileItem? _input;
  bool _busy = false;
  int _pageCount = 0;
  int _pageNumber = 1; // one-based

  Uint8List? _bytes;
  bool _rendering = false;
  double _aspect = 0.75;
  TaskHandle? _activeRender;

  _Tool _tool = _Tool.pen;
  int _penColor = _black;
  final List<_Mark> _marks = [];

  // In-progress gesture state.
  final List<Offset> _livePoints = [];
  Rect? _liveRect;

  FileItem? _output;
  String? _error;

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
      _marks.clear();
      _bytes = null;
    });
    unawaited(_loadPage(pageNumber));
  }

  void _panStart(DragStartDetails details, Size size) {
    final p = _normalized(details.localPosition, size);
    if (_tool == _Tool.pen) {
      _livePoints
        ..clear()
        ..add(p);
    } else {
      _liveRect = Rect.fromPoints(p, p);
    }
    setState(() {});
  }

  void _panUpdate(DragUpdateDetails details, Size size) {
    final p = _normalized(details.localPosition, size);
    if (_tool == _Tool.pen) {
      _livePoints.add(p);
    } else if (_liveRect != null) {
      _liveRect = Rect.fromPoints(_liveRect!.topLeft, p);
    }
    setState(() {});
  }

  void _panEnd(Size size) {
    if (_tool == _Tool.pen) {
      if (_livePoints.length > 1) {
        _marks.add(_InkMark(List.of(_livePoints), _penColor));
      }
      _livePoints.clear();
    } else if (_liveRect != null) {
      final rect = _liveRect!;
      if (rect.width > 0.005 && rect.height > 0.005) {
        _marks.add(_RectMarkUi(
          Rect.fromLTRB(
            rect.left.clamp(0, 1),
            rect.top.clamp(0, 1),
            rect.right.clamp(0, 1),
            rect.bottom.clamp(0, 1),
          ),
          _tool == _Tool.highlight ? 'highlight' : 'box',
          _tool == _Tool.highlight ? _yellow : _red,
        ));
      }
      _liveRect = null;
    }
    setState(() {});
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
    if (input == null || _marks.isEmpty) return;
    setState(() {
      _phase = _Phase.running;
      _error = null;
    });
    try {
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'application/pdf',
            displayName: '${baseName(input)}-annotated.pdf',
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _phase = _Phase.edit);
        return;
      }
      final strokes = <InkStroke>[];
      final rects = <RectMark>[];
      for (final mark in _marks) {
        switch (mark) {
          case _InkMark(:final points, :final colorRgb):
            strokes.add(InkStroke(
              points: [
                for (final p in points) ...[p.dx, p.dy],
              ],
              colorRgb: colorRgb,
              width: 0.006,
            ));
          case _RectMarkUi(:final rect, :final mode, :final colorRgb):
            rects.add(RectMark(
              left: rect.left,
              top: rect.top,
              right: rect.right,
              bottom: rect.bottom,
              colorRgb: colorRgb,
              mode: mode,
            ));
        }
      }
      final handle = ref.read(pdfGatewayProvider).annotate(
            input: input,
            pageNumber: _pageNumber,
            strokes: strokes,
            rects: rects,
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
        _error = e is BridgeException ? e.userMessage : 'Saving failed.';
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
      appBar: AppBar(title: const Text('Annotate PDF')),
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
                        Text('Saving annotations…'),
                      ],
                    ),
                  ),
                _Phase.done => _DoneView(
                    name: _output?.displayName ?? 'annotated.pdf',
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
                        // Fit the rendered page inside the available box.
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
                                onPanStart: (d) => _panStart(d, size),
                                onPanUpdate: (d) => _panUpdate(d, size),
                                onPanEnd: (_) => _panEnd(size),
                              ),
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: _OverlayPainter(
                                    marks: _marks,
                                    livePoints: _tool == _Tool.pen
                                        ? _livePoints
                                        : const [],
                                    liveRect: _liveRect,
                                    liveColor: _currentColor(),
                                    tool: _tool,
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
                _ToolButton(
                  icon: Icons.edit_outlined,
                  label: 'Pen',
                  selected: _tool == _Tool.pen,
                  onTap: () => setState(() => _tool = _Tool.pen),
                ),
                const SizedBox(width: SiliphSpacing.xs),
                _ToolButton(
                  icon: Icons.highlight_outlined,
                  label: 'Highlight',
                  selected: _tool == _Tool.highlight,
                  onTap: () => setState(() => _tool = _Tool.highlight),
                ),
                const SizedBox(width: SiliphSpacing.xs),
                _ToolButton(
                  icon: Icons.crop_square_outlined,
                  label: 'Box',
                  selected: _tool == _Tool.box,
                  onTap: () => setState(() => _tool = _Tool.box),
                ),
                const SizedBox(width: SiliphSpacing.md),
                if (_tool == _Tool.pen)
                  for (final color in [_black, _red, _blue])
                    Padding(
                      padding:
                          const EdgeInsets.only(right: SiliphSpacing.xs),
                      child: GestureDetector(
                        onTap: () => setState(() => _penColor = color),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Color(0xFF000000 | color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _penColor == color
                                  ? SiliphColors.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                IconButton(
                  tooltip: 'Undo last mark',
                  icon: const Icon(Icons.undo),
                  onPressed: _marks.isEmpty
                      ? null
                      : () => setState(() => _marks.removeLast()),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _marks.isEmpty || _rendering ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_marks.isEmpty
                  ? 'Draw or mark up the page first'
                  : 'Save annotations'),
            ),
          ),
        ],
      ),
    );
  }

  int _currentColor() => switch (_tool) {
        _Tool.pen => _penColor,
        _Tool.highlight => _yellow,
        _Tool.box => _red,
      };
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SiliphRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SiliphSpacing.sm,
          vertical: SiliphSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? SiliphColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(SiliphRadii.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: selected ? SiliphColors.primary : null),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({
    required this.marks,
    required this.livePoints,
    required this.liveRect,
    required this.liveColor,
    required this.tool,
  });

  final List<_Mark> marks;
  final List<Offset> livePoints;
  final Rect? liveRect;
  final int liveColor;
  final _Tool tool;

  Color _color(int rgb, {double alpha = 1}) =>
      Color.fromRGBO((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF, alpha);

  @override
  void paint(Canvas canvas, Size size) {
    for (final mark in marks) {
      switch (mark) {
        case _InkMark(:final points, :final colorRgb):
          _paintInk(canvas, size, points, _color(colorRgb));
        case _RectMarkUi(:final rect, :final mode, :final colorRgb):
          _paintRect(canvas, size, rect, mode, colorRgb);
      }
    }
    if (livePoints.length > 1) {
      _paintInk(canvas, size, livePoints, _color(liveColor));
    }
    final live = liveRect;
    if (live != null) {
      _paintRect(
        canvas,
        size,
        live,
        tool == _Tool.highlight ? 'highlight' : 'box',
        liveColor,
      );
    }
  }

  void _paintInk(Canvas canvas, Size size, List<Offset> points, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.006 * size.shortestSide
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    final first = _denorm(points.first, size);
    path.moveTo(first.dx, first.dy);
    for (final p in points.skip(1)) {
      final d = _denorm(p, size);
      path.lineTo(d.dx, d.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _paintRect(
    Canvas canvas,
    Size size,
    Rect rect,
    String mode,
    int colorRgb,
  ) {
    final r = Rect.fromLTRB(
      rect.left * size.width,
      rect.top * size.height,
      rect.right * size.width,
      rect.bottom * size.height,
    );
    if (mode == 'highlight') {
      canvas.drawRect(
        r,
        Paint()..color = _color(colorRgb, alpha: 0.35),
      );
    } else {
      canvas.drawRect(
        r,
        Paint()
          ..color = _color(colorRgb)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  Offset _denorm(Offset p, Size size) =>
      Offset(p.dx * size.width, p.dy * size.height);

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) => true;
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
            const Icon(Icons.edit_note_outlined,
                size: 64, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.md),
            Text('Annotate a PDF page',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Draw with a pen, highlight or box regions on one page. The '
              'page text stays selectable.',
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
            Text('Annotations saved',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              '"$name" contains your marks. The original text on the page '
              'is still selectable.',
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
                onPressed: onRestart, child: const Text('Annotate another')),
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
