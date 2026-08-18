/// PDF Editor main canvas screen (section 1).
///
/// The central PDF editing workspace displaying a rendered PDF page with
/// tools for selection, editing, annotation and page management. Uses the
/// existing Siliph Liquid Glass visual style with purple accents.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/file_facts.dart';
import '../../domain/services/native_bridge.dart';
import '../../generated/siliph_bridge.g.dart';

enum _PdfEditorPhase { idle, loading, editing, processing, saved, error }

enum _PdfEditorTool {
  select,
  text,
  image,
  highlight,
  underline,
  strikethrough,
  draw,
  shape,
  signature,
  link,
  whiteout,
  forms,
  comment,
  search,
  findReplace,
  pages,
}

class PdfEditorScreen extends ConsumerStatefulWidget {
  const PdfEditorScreen({super.key, required this.file});

  final FileItem file;

  @override
  ConsumerState<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends ConsumerState<PdfEditorScreen> {
  _PdfEditorPhase _phase = _PdfEditorPhase.idle;
  bool _busy = false;
  int _pageCount = 0;
  int _pageNumber = 1;
  double _zoom = 1.0;
  double _panOffsetX = 0.0;
  double _panOffsetY = 0.0;
  String? _error;
  Uint8List? _pageBytes;
  bool _rendering = false;
  Timer? _renderTimer;

  // Selection state
  _PdfEditorTool? _activeTool;
  Offset? _selectionStart;
  Offset? _selectionEnd;
  bool _isSelecting = false;
  List<Offset> _selectionHandles = [];
  double? _rotatedAngle;
  double _scaleFactor = 1.0;

  // Undo/Redo history
  final List<_EditorHistory> _history = [];
  int _historyIndex = -1;

  // Current annotations/marks
  final List<_Annotation> _annotations = [];
  Offset? _annotatedPoint;
  String? _editingText;
  TextEditingController? _textController;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _renderTimer?.cancel();
    _textController?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _phase = _PdfEditorPhase.loading;
      _busy = true;
      _error = null;
    });

    try {
      final input = widget.file;
      final info = await ref.read(pdfGatewayProvider).inspect(input);
      if (!mounted) return;

      setState(() {
        _pageCount = info.pageCount;
        _pageNumber = 1;
        _phase = _PdfEditorPhase.idle;
      });

      await _renderPage(1);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load PDF.';
        _phase = _PdfEditorPhase.error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _renderPage(int pageNumber) async {
    if (_rendering) return;
    if (pageNumber < 1 || pageNumber > _pageCount) return;

    setState(() {
      _rendering = true;
      _error = null;
    });

    try {
      final input = widget.file;
      final handle = ref.read(pdfGatewayProvider).renderPage(
            input: input,
            pageIndex: pageNumber - 1,
            dpi: 150,
          );
      final bytes = await handle.image;
      await handle.done;

      if (!mounted || _pageNumber != pageNumber) return;

      setState(() {
        _pageBytes = bytes;
        _rendering = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is! BridgeException || !e.isCancelled) {
        setState(() {
          _error = 'Rendering failed.';
          _phase = _PdfEditorPhase.error;
        });
      }
    } finally {
      if (mounted && _activeRender == null) {
        setState(() => _rendering = false);
      }
    }
  }

  void _updateHistory(_EditorHistory item) {
    // Truncate history after current index (new edit clears future)
    _history.removeRange(_historyIndex + 1, _history.length);
    _history.add(item);
    _historyIndex++;

    // Keep history manageable
    if (_history.length > 50) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  void _undo() {
    if (_historyIndex <= 0) return;
    final previous = _history[_historyIndex - 1];
    // Apply the inverse operation
    _historyIndex--;
    _applyHistoryState(previous);
  }

  void _redo() {
    if (_historyIndex >= _history.length - 1) return;
    final next = _history[_historyIndex + 1];
    _applyHistoryState(next);
    _historyIndex++;
  }

  void _applyHistoryState(_EditorHistory state) {
    // Apply saved state from history
    setState(() {
      _pageNumber = state.pageNumber;
      _zoom = state.zoom;
      _annotations = List.from(state.annotations);
      _activeTool = state.activeTool;
      _editingText = state.editingText;
      if (_editingText != null && _textController != null) {
        _textController!.text = _editingText!;
      }
    });
  }

  // Undo/Redo history model
  _EditorHistory _createHistoryItem({
    required int pageNumber,
    required double zoom,
    required List<_Annotation> annotations,
    required _PdfEditorTool? activeTool,
    required String? editingText,
  }) {
    return _EditorHistory(
      pageNumber: pageNumber,
      zoom: zoom,
      annotations: List.from(annotations),
      activeTool: activeTool,
      editingText: editingText,
    );
  }

  // Tool button widget
  Widget _toolButton({
    required _PdfEditorTool tool,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
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
          border: Border.all(
            color: selected ? SiliphColors.primary : SiliphColors.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: selected ? SiliphColors.primary : null),
            const SizedBox(height: SiliphSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  // Page navigation buttons
  Widget _pageNavButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }

  // Toolbar at the bottom
  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      decoration: BoxDecoration(
        color: SiliphColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Left side: Tool selection
          Wrap(
            spacing: SiliphSpacing.xs,
            runSpacing: SiliphSpacing.xs,
            children: [
              _toolButton(
                tool: _PdfEditorTool.select,
                icon: Icons.select_all_outlined,
                label: 'Select',
                selected: _activeTool == _PdfEditorTool.select,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.select),
              ),
              _toolButton(
                tool: _PdfEditorTool.text,
                icon: Icons.text_fields_outlined,
                label: 'Text',
                selected: _activeTool == _PdfEditorTool.text,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.text),
              ),
              _toolButton(
                tool: _PdfEditorTool.highlight,
                icon: Icons.highlight_outlined,
                label: 'Highlight',
                selected: _activeTool == _PdfEditorTool.highlight,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.highlight),
              ),
              _toolButton(
                tool: _PdfEditorTool.underline,
                icon: Icons.format_underlined_outlined,
                label: 'Underline',
                selected: _activeTool == _PdfEditorTool.underline,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.underline),
              ),
              _toolButton(
                tool: _PdfEditorTool.strikethrough,
                icon: Icons.format_strikethrough_outlined,
                label: 'Strikethrough',
                selected: _activeTool == _PdfEditorTool.strikethrough,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.strikethrough),
              ),
            ],
          ),

          // Middle: Actions
          Wrap(
            spacing: SiliphSpacing.xs,
            runSpacing: SiliphSpacing.xs,
            children: [
              _toolButton(
                tool: _PdfEditorTool.draw,
                icon: Icons.brush_outlined,
                label: 'Draw',
                selected: _activeTool == _PdfEditorTool.draw,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.draw),
              ),
              _toolButton(
                tool: _PdfEditorTool.shape,
                icon: Icons.square_outlined,
                label: 'Shape',
                selected: _activeTool == _PdfEditorTool.shape,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.shape),
              ),
              _toolButton(
                tool: _PdfEditorTool.signature,
                icon: Icons.draw_outlined,
                label: 'Signature',
                selected: _activeTool == _PdfEditorTool.signature,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.signature),
              ),
              _toolButton(
                tool: _PdfEditorTool.link,
                icon: Icons.link_outlined,
                label: 'Link',
                selected: _activeTool == _PdfEditorTool.link,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.link),
              ),
              _toolButton(
                tool: _PdfEditorTool.whiteout,
                icon: Icons.remove_circle_outlined,
                label: 'Whiteout',
                selected: _activeTool == _PdfEditorTool.whiteout,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.whiteout),
              ),
            ],
          ),

          // Right side: More and navigation
          Wrap(
            spacing: SiliphSpacing.xs,
            runSpacing: SiliphSpacing.xs,
            children: [
              _toolButton(
                tool: _PdfEditorTool.forms,
                icon: Icons.format_list_numbered_outlined,
                label: 'Forms',
                selected: _activeTool == _PdfEditorTool.forms,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.forms),
              ),
              _toolButton(
                tool: _PdfEditorTool.comment,
                icon: Icons.comment_outlined,
                label: 'Comment',
                selected: _activeTool == _PdfEditorTool.comment,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.comment),
              ),
              _toolButton(
                tool: _PdfEditorTool.search,
                icon: Icons.search_outlined,
                label: 'Search',
                selected: _activeTool == _PdfEditorTool.search,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.search),
              ),
              _toolButton(
                tool: _PdfEditorTool.pages,
                icon: Icons.pages_outlined,
                label: 'Pages',
                selected: _activeTool == _PdfEditorTool.pages,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.pages),
              ),
              _toolButton(
                tool: _PdfEditorTool.more,
                icon: Icons.more_outlined,
                label: 'More',
                selected: _activeTool == _PdfEditorTool.more,
                onTap: () => setState(() => _activeTool = _PdfEditorTool.more),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Zoom controls
  Widget _buildZoomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          tooltip: 'Zoom out',
          onPressed: _zoom > 0.3 ? () => setState(() => _zoom = _zoom * 0.8) : null,
        ),
        Text(
          '${(_zoom * 100).toInt()}%',
          style: Theme.of(context).textTheme.bodySmall,
          semanticsLabel: 'zoom level',
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Zoom in',
          onPressed: _zoom < 3.0 ? () => setState(() => _zoom = _zoom * 1.25) : null,
        ),
      ],
    );
  }

  // Page indicator
  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Page $_pageNumber',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          Text(
            'of $_pageCount',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _pageNumber > 1 ? () {
              setState(() {
                _pageNumber--;
              });
              _renderPage(_pageNumber);
            } : null,
            tooltip: 'Previous page',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _pageNumber < _pageCount ? () {
              setState(() {
                _pageNumber++;
              });
              _renderPage(_pageNumber);
            } : null,
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }

  // Error banner
  Widget _errorBanner() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Container(
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
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Main build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Editor'),
        actions: [
          // Save button
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save',
            onPressed: _phase == _PdfEditorPhase.editing && _annotations.isNotEmpty
                ? () => _savePdf()
                : null,
          ),
          // Share button
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _phase == _PdfEditorPhase.saved ? () => _sharePdf() : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Phase indicator and page
            if (_phase == _PdfEditorPhase.error) ..._errorBanner(),
            if (_phase != _PdfEditorPhase.error) ...[
              _buildPageIndicator(),
              _buildZoomControls(),
            ],

            // PDF canvas area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final effectiveWidth = constraints.maxWidth * _zoom;
                  final effectiveHeight = constraints.maxHeight * _zoom;

                  return GestureDetector(
                    onPanStart: (details) {
                      if (_activeTool == _PdfEditorTool.select) {
                        setState(() {
                          _isSelecting = true;
                          _selectionStart = details.localPosition;
                          _selectionEnd = details.localPosition;
                        });
                      }
                    },
                    onPanUpdate: (details) {
                      if (_activeTool == _PdfEditorTool.select && _isSelecting) {
                        setState(() {
                          _selectionEnd = details.localPosition;
                          _selectionHandles = _computeSelectionHandles();
                        });
                      }
                    },
                    onPanEnd: (_) {
                      if (_activeTool == _PdfEditorTool.select && _isSelecting) {
                        // Process selection
                        _isSelecting = false;
                        // TODO: Show contextual toolbar
                        setState(() {});
                      }
                    },
                    child: Stack(
                      children: [
// Page rendering
                        if (_pageBytes != null)
                          Center(
                            child: Image.memory(
                              _pageBytes!,
                              width: effectiveWidth,
                              height: effectiveHeight,
                              fit: BoxFit.contain,
                            ),
                          )
                        else
                          const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),

// Selection overlay
                        if (_isSelecting && _selectionStart != null && _selectionEnd != null)
                          _SelectionOverlay(
                            start: _selectionStart!,
                            end: _selectionEnd!,
                            size: constraints.maxSize,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom toolbar
            _buildToolbar(context),
          ],
        ),
      ),
      bottomNavigationBar: _busy
          ? const LinearProgressIndicator()
          : const SizedBox.shrink(),
    );
  }

  // Save PDF
  Future<void> _savePdf() async {
    setState(() {
      _phase = _PdfEditorPhase.processing;
      _busy = true;
      _error = null;
    });

    try {
      final input = widget.file;
      final output = await ref.read(fileGatewayProvider).createDocument(
            mimeType: 'application/pdf',
            displayName: '${baseName(input)}-edited.pdf',
          );

      if (!mounted || output == null) {
        setState(() {
          _phase = _PdfEditorPhase.editing;
          _busy = false;
        });
        return;
      }

      // Apply annotations to PDF
      final handle = ref.read(pdfGatewayProvider).annotate(
            input: input,
            pageNumber: _pageNumber,
            strokes: _toStrokes(),
            rects: _toRectMarks(),
            output: output,
          );

      await handle.done;

      if (!mounted) return;
      setState(() {
        _phase = _PdfEditorPhase.saved;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _PdfEditorPhase.editing;
        _busy = false;
        _error = e.toString();
      });
    }
  }

  // Share PDF
  Future<void> _sharePdf() async {
    // TODO: Implement share
  }

  // Convert annotations to strokes
  List<InkStroke> _toStrokes() {
    final strokes = <InkStroke>[];
    for (final ann in _annotations) {
      if (ann is _InkAnnotation) {
        strokes.add(InkStroke(
          points: ann.points,
          colorRgb: ann.colorRgb,
          width: ann.strokeWidth,
        ));
      }
    }
    return strokes;
  }

  // Convert annotations to rect marks
  List<RectMark> _toRectMarks() {
    final rects = <RectMark>[];
    for (final ann in _annotations) {
      if (ann is _RectAnnotation) {
        rects.add(RectMark(
          left: ann.rect.left,
          top: ann.rect.top,
          right: ann.rect.right,
          bottom: ann.rect.bottom,
          colorRgb: ann.colorRgb,
          mode: ann.mode,
        ));
      }
    }
    return rects;
  }

  String baseName(FileItem file) {
    final dot = file.displayName.lastIndexOf('.');
    if (dot <= 0 || dot == file.displayName.length - 1) return file.displayName;
    return file.displayName.substring(0, dot);
  }

  // Selection handle computation
  List<Offset> _computeSelectionHandles() {
    if (_selectionStart == null || _selectionEnd == null) return [];
    final dx = _selectionEnd!.dx - _selectionStart!.dx;
    final dy = _selectionEnd!.dy - _selectionStart!.dy;
    final center = Offset(
      (_selectionStart!.dx + _selectionEnd!.dx) / 2,
      (_selectionStart!.dy + _selectionEnd!.dy) / 2,
    );
    final handles = <Offset>[
      // Top-left
      Offset(_selectionStart!.dx - 12, _selectionStart!.dy - 12),
      // Top-right
      Offset(_selectionEnd!.dx - 12, _selectionStart!.dy - 12),
      // Bottom-left
      Offset(_selectionStart!.dx - 12, _selectionEnd!.dy - 12),
      // Bottom-right
      Offset(_selectionEnd!.dx - 12, _selectionEnd!.dy - 12),
      // Middle-left
      Offset(_selectionStart!.dx - 12, center.dy),
      // Middle-right
      Offset(_selectionEnd!.dx - 12, center.dy),
      // Middle-top
      Offset(center.dx, _selectionStart!.dy - 12),
      // Middle-bottom
      Offset(center.dx, _selectionEnd!.dy - 12),
    ];
    return handles;
  }
}

// History model
class _EditorHistory {
  final int pageNumber;
  final double zoom;
  final List<_Annotation> annotations;
  final _PdfEditorTool? activeTool;
  final String? editingText;

  _EditorHistory({
    required this.pageNumber,
    required this.zoom,
    required this.annotations,
    required this.activeTool,
    required this.editingText,
  });
}

// Annotation base class
abstract class _Annotation {
  final int colorRgb;
  _Annotation(this.colorRgb);
}

// Ink annotation
class _InkAnnotation extends _Annotation {
  final List<Offset> points;
  final double strokeWidth;
  _InkAnnotation(super.colorRgb, this.points, this.strokeWidth);
}

// Rect annotation
class _RectAnnotation extends _Annotation {
  final Rect rect;
  final String mode; // 'highlight' | 'box'
  final Color color;
  _RectAnnotation(super.colorRgb, this.rect, this.mode, this.color);
}

// Selection overlay painter
class _SelectionOverlay extends StatelessWidget {
  const _SelectionOverlay({
    required this.start,
    required this.end,
    required this.size,
  });

  final Offset start;
  final Offset end;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final paint = Paint()
      ..color = SiliphColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final r = Rect.fromLTWH(
      start.dx,
      start.dy,
      end.dx - start.dx,
      end.dy - start.dy,
    );

    return CustomPaint(size: size, painter: _SelectionPainter(r, paint));
  }
}

class _SelectionPainter extends CustomPainter {
  const _SelectionPainter(this.rect, this.paint);

  final Rect rect;
  final Paint paint;

  @override
  void paint(Canvas canvas) {
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_SelectionPainter oldDelegate) => true;
}