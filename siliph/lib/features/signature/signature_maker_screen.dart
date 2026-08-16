/// Signature Maker workflow (section 50 tool-screen standard).
///
/// Draws a signature with touch gestures on a white canvas and saves it as
/// a PNG through the SAF save-as dialog. The PNG bytes are app-generated
/// UI output (capped small payload), not bulk file content.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';

enum _Phase { draw, saving, done }

class SignatureMakerScreen extends ConsumerStatefulWidget {
  const SignatureMakerScreen({super.key});

  @override
  ConsumerState<SignatureMakerScreen> createState() =>
      _SignatureMakerScreenState();
}

class _SignatureMakerScreenState extends ConsumerState<SignatureMakerScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = const [];
  _Phase _phase = _Phase.draw;
  double _strokeWidth = 4;
  String? _error;
  String? _savedName;

  bool get _hasInk => _strokes.isNotEmpty || _current.isNotEmpty;

  void _clear() => setState(() {
        _strokes.clear();
        _current = const [];
      });

  void _undo() => setState(() {
        if (_strokes.isNotEmpty) _strokes.removeLast();
      });

  Future<void> _save() async {
    if (!_hasInk) return;
    setState(() => _error = null);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Canvas is not ready');
      // Rasterize before swapping the canvas for the spinner: the layer
      // must stay attached while the engine captures it.
      final image = await boundary.toImage(pixelRatio: 2);
      final byteData =
          (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final bytes = Uint8List.sublistView(byteData);
      image.dispose();

      if (!mounted) return;
      setState(() => _phase = _Phase.saving);
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'image/png',
            displayName: 'signature.png',
          );
      if (!mounted) return;
      if (output == null) {
        setState(() => _phase = _Phase.draw);
        return; // User cancelled the save dialog.
      }
      await ref.read(imageToolsGatewayProvider).writeImageBytes(
            output: output,
            png: bytes,
          );
      if (!mounted) return;
      setState(() {
        _savedName = output.displayName;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.draw;
        _error = e is BridgeException ? e.userMessage : 'Saving failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signature Maker')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.draw => _DrawView(
                    boundaryKey: _boundaryKey,
                    strokes: _strokes,
                    current: _current,
                    strokeWidth: _strokeWidth,
                    onStrokeWidth: (value) =>
                        setState(() => _strokeWidth = value),
                    onPanStart: (details) =>
                        setState(() => _current = [details.localPosition]),
                    onPanUpdate: (details) =>
                        setState(() => _current = [..._current, details.localPosition]),
                    onPanEnd: () => setState(() {
                          if (_current.length > 1) _strokes.add(_current);
                          _current = const [];
                        }),
                    onUndo: _undo,
                    onClear: _clear,
                    hasInk: _hasInk,
                    onSave: _save,
                  ),
                _Phase.saving => const Center(
                    child: CircularProgressIndicator(),
                  ),
                _Phase.done => _DoneView(
                    name: _savedName ?? 'signature.png',
                    onRestart: () => setState(() {
                          _phase = _Phase.draw;
                          _strokes.clear();
                          _current = const [];
                          _savedName = null;
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

class _DrawView extends StatelessWidget {
  const _DrawView({
    required this.boundaryKey,
    required this.strokes,
    required this.current,
    required this.strokeWidth,
    required this.onStrokeWidth,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onUndo,
    required this.onClear,
    required this.hasInk,
    required this.onSave,
  });

  final GlobalKey boundaryKey;
  final List<List<Offset>> strokes;
  final List<Offset> current;
  final double strokeWidth;
  final ValueChanged<double> onStrokeWidth;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final VoidCallback onPanEnd;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final bool hasInk;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sign below',
              style: Theme.of(context).textTheme.titleMediumStyle),
          const SizedBox(height: SiliphSpacing.xs),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SiliphRadii.lg),
              child: GestureDetector(
                onPanStart: onPanStart,
                onPanUpdate: onPanUpdate,
                onPanEnd: (_) => onPanEnd(),
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: CustomPaint(
                    painter: _SignaturePainter(
                      strokes: strokes,
                      current: current,
                      strokeWidth: strokeWidth,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.sm),
          Row(
            children: [
              const Icon(Icons.line_weight, size: 18),
              Expanded(
                child: Slider(
                  value: strokeWidth,
                  min: 2,
                  max: 10,
                  divisions: 8,
                  onChanged: onStrokeWidth,
                ),
              ),
              TextButton(onPressed: onUndo, child: const Text('Undo')),
              TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: hasInk ? onSave : null,
              icon: const Icon(Icons.gesture_outlined),
              label: Text(hasInk ? 'Save PNG' : 'Draw a signature first'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({
    required this.strokes,
    required this.current,
    required this.strokeWidth,
  });

  final List<List<Offset>> strokes;
  final List<Offset> current;
  final double strokeWidth;

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) {
      if (points.length == 1) canvas.drawCircle(points.first, strokeWidth / 2, paint);
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.white, BlendMode.srcOver);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }
    _drawStroke(canvas, current, paint);
    // Baseline hint for the signature.
    canvas.drawLine(
      Offset(24, size.height - 32),
      Offset(size.width - 24, size.height - 32),
      Paint()
        ..color = Colors.grey.shade300
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
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
            Text('Signature saved',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              'Saved as "$name" with a transparent-free white background, '
              'ready to stamp onto PDFs.',
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
