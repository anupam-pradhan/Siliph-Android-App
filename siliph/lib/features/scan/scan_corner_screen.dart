/// Corner adjustment screen.
///
/// After capture, shows the detected document with draggable corner handles
/// so the user can manually correct the automatic detection.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import 'scan_enhance_screen.dart';
import 'scan_mode.dart';
import 'scanner_provider.dart';
import 'scanner_state.dart';
import 'scan_widgets.dart';

class ScanCornerScreen extends ConsumerStatefulWidget {
  const ScanCornerScreen({
    super.key,
    required this.mode,
    required this.pageId,
  });

  final ScanMode mode;
  final String pageId;

  @override
  ConsumerState<ScanCornerScreen> createState() => _ScanCornerScreenState();
}

class _ScanCornerScreenState extends ConsumerState<ScanCornerScreen> {
  late List<Offset> _corners;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(scannerProvider(widget.mode));
    final page = state.pages.where((p) => p.id == widget.pageId).firstOrNull;
    final rawCorners = page?.corners;

    if (rawCorners != null && rawCorners.length == 8) {
      _corners = List.generate(
        4,
        (i) => Offset(rawCorners[i * 2], rawCorners[i * 2 + 1]),
      );
    } else {
      // Default to full image
      _corners = [
        const Offset(0.05, 0.05),
        const Offset(0.95, 0.05),
        const Offset(0.95, 0.95),
        const Offset(0.05, 0.95),
      ];
    }
  }

  void _onCornerDrag(int index, DragUpdateDetails details, Size size) {
    setState(() {
      final dx = (details.localPosition.dx / size.width).clamp(0.0, 1.0);
      final dy = (details.localPosition.dy / size.height).clamp(0.0, 1.0);
      _corners[index] = Offset(dx, dy);
    });
  }

  void _resetCorners() {
    setState(() {
      _corners = [
        const Offset(0.05, 0.05),
        const Offset(0.95, 0.05),
        const Offset(0.95, 0.95),
        const Offset(0.05, 0.95),
      ];
    });
  }

  Future<void> _confirmCorners() async {
    setState(() => _isProcessing = true);

    final notifier = ref.read(scannerProvider(widget.mode).notifier);
    final state = ref.read(scannerProvider(widget.mode));
    final pageIndex =
        state.pages.indexWhere((p) => p.id == widget.pageId);
    if (pageIndex < 0) return;

    final normalizedCorners = <double>[];
    for (final c in _corners) {
      normalizedCorners.add(c.dx);
      normalizedCorners.add(c.dy);
    }

    final updatedPage = state.pages[pageIndex].copyWith(
      corners: normalizedCorners,
    );
    notifier.updatePage(pageIndex, updatedPage);
    notifier.setPhase(ScanPhase.enhancing);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ScanEnhanceScreen(
          mode: widget.mode,
          pageId: widget.pageId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerProvider(widget.mode));
    final page = state.pages.where((p) => p.id == widget.pageId).firstOrNull;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Adjust Corners'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: _resetCorners,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  children: [
                    // Image display
                    if (page != null)
                      Center(
                        child: _buildImagePreview(page.originalUri, size),
                      ),

                    // Corner handles
                    ...List.generate(4, (i) {
                      return Positioned(
                        left: _corners[i].dx * size.width - 16,
                        top: _corners[i].dy * size.height - 16,
                        child: GestureDetector(
                          onPanUpdate: (d) => _onCornerDrag(i, d, size),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: SiliphColors.categoryScanner,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.open_with,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      );
                    }),

                    // Lines connecting corners
                    CustomPaint(
                      size: size,
                      painter: _CornerLinesPainter(corners: _corners),
                    ),

                    // Corner labels
                    ...List.generate(4, (i) {
                      final labels = ['TL', 'TR', 'BR', 'BL'];
                      return Positioned(
                        left: _corners[i].dx * size.width + 18,
                        top: _corners[i].dy * size.height - 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            labels[i],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),

          // Bottom controls
          Container(
            padding: const EdgeInsets.all(SiliphSpacing.md),
            decoration: const BoxDecoration(
              color: Colors.black,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding:
                          const EdgeInsets.symmetric(vertical: SiliphSpacing.md),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: SiliphSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _isProcessing ? null : _confirmCorners,
                    style: FilledButton.styleFrom(
                      backgroundColor: SiliphColors.categoryScanner,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: SiliphSpacing.md),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(String uri, Size size) {
    // Show image from file path
    if (uri.startsWith('/') || uri.startsWith('file://')) {
      final path = uri.startsWith('file://') ? uri.substring(7) : uri;
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        width: size.width,
        height: size.height,
      );
    }
    // Fallback placeholder
    return Container(
      width: size.width,
      height: size.height,
      color: SiliphColors.surfaceVariant,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 64, color: SiliphColors.outline),
      ),
    );
  }
}

class _CornerLinesPainter extends CustomPainter {
  _CornerLinesPainter({required this.corners});

  final List<Offset> corners;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SiliphColors.categoryScanner
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(corners[0].dx * size.width, corners[0].dy * size.height);
    for (var i = 1; i < 4; i++) {
      path.lineTo(corners[i].dx * size.width, corners[i].dy * size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerLinesPainter oldDelegate) {
    return oldDelegate.corners != corners;
  }
}
