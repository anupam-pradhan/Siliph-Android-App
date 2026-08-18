/// Draw tool (section 7).
///
/// Pen, pencil, highlighter, eraser tools with color and stroke size controls.
/// States: drawing, erasing, selected drawing, delete drawing.
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
import '../../generated/siliph_bridge.g.dart';

enum _DrawPhase { drawing, erasing, selected, deleting }

/// Drawing state model
class _DrawState {
  final List<Offset> points = [];
  final List<List<Offset>> completedStrokes = [];
  final String tool; // 'pen', 'pencil', 'highlighter', 'eraser'
  final Color color;
  double strokeWidth;
  double opacity;
  bool isErasing;

  _DrawState({
    this.tool = 'pen',
    this.color = SiliphColors.primary,
    this.strokeWidth = 2.0,
    this.opacity = 1.0,
    this.isErasing = false,
  });

  _DrawState copyWith({
    String? tool,
    Color? color,
    double? strokeWidth,
    double? opacity,
    bool? isErasing,
  }) {
    return _DrawState(
      tool: tool ?? this.tool,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      isErasing: isErasing ?? this.isErasing,
    );
  }
}

/// Draw screen
class DrawScreen extends ConsumerStatefulWidget {
  const DrawScreen({
    super.key,
    required this.file,
    required this.pageNumber,
  });

  final FileItem file;
  final int pageNumber;

  @override
  ConsumerState<DrawScreen> createState() => _DrawScreenState;
}

class _DrawScreenState extends ConsumerState<DrawScreen> {
  _DrawPhase _phase = _DrawPhase.drawing;
  _DrawState _drawState = _DrawState();
  bool _isDirty = false;
  String? _error;
  bool _keyboardVisible = false;

  // Selection state for selected drawing
  Offset? _selectionStart;
  Offset? _selectionEnd;
  bool _isSelecting = false;

  // Eraser size
  double _eraserSize = 10.0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Start drawing
  void _startDrawing(Offset position) {
    setState(() {
      _drawState = _drawState.copyWith();
      _drawState.points.add(position);
      _phase = _DrawPhase.drawing;
    });
  }

  // Update drawing
  void _updateDrawing(Offset position) {
    setState(() {
      _drawState.points.add(position);
    });
  }

  // End drawing
  void _endDrawing() {
    setState(() {
      _drawState.completedStrokes.add(List.from(_drawState.points));
      _drawState.points.clear();
      // Check if we should switch to select mode
      if (_drawState.tool != 'eraser') {
        setState(() => _phase = _DrawPhase.selected);
      }
    });
  }

  // Start erasing
  void _startErasing(Offset position) {
    setState(() {
      _drawState = _drawState.copyWith(
        tool: 'eraser',
        isErasing: true,
        points: [position],
      );
      _phase = _DrawPhase.erasing;
    });
  }

  // Update erasing
  void _updateErasing(Offset position) {
    setState(() {
      _drawState.points.add(position);
    });
  }

  // End erasing
  void _endErasing() {
    setState(() {
      _drawState.completedStrokes.add(List.from(_drawState.points));
      _drawState.points.clear();
      _drawState = _drawState.copyWith(
        tool: 'pen',
        isErasing: false,
      );
      setState(() => _phase = _DrawPhase.selected);
    });
  }

  // Toggle tool
  void _toggleTool(String tool) {
    setState(() {
      _drawState = _drawState.copyWith(tool: tool);
      if (tool == 'eraser') {
        _phase = _DrawPhase.erasing;
      } else {
        _phase = _DrawPhase.drawing;
      }
    });
  }

  // Change color
  void _changeColor(Color color) {
    setState(() {
      _drawState = _drawState.copyWith(color: color);
    });
  }

  // Change stroke width
  void _changeStrokeWidth(double width) {
    setState(() {
      _drawState = _drawState.copyWith(strokeWidth: width);
    });
  }

  // Change opacity
  void _changeOpacity(double value) {
    setState(() {
      _drawState = _drawState.copyWith(opacity: value);
    });
  }

  // Select/deselect drawing
  void _selectDrawing() {
    setState(() => _phase = _DrawPhase.selected);
  }

  // Delete drawing
  void _deleteDrawing() {
    setState(() {
      _drawState.completedStrokes.clear();
      _phase = _DrawPhase.deleting;
    });
    // TODO: Actually delete
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _phase = _DrawPhase.drawing);
      }
    });
  }

  // Undo last stroke
  void _undo() {
    setState(() {
      if (_drawState.completedStrokes.isNotEmpty) {
        _drawState.completedStrokes.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw'),
        actions: [
          // Undo button
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _drawState.completedStrokes.isEmpty ? null : _undo,
          ),
          // Redo button (would need redo stack)
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Phase indicator
            _buildPhaseIndicator(),

            // Tool selector
            _buildToolSelector(),

            // Color and size controls
            _buildControlPanel(),

            // Canvas area
            Expanded(
              child: _buildCanvas(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseIndicator() {
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Row(
        children: [
          _PhaseChip(
            phase: _DrawPhase.drawing,
            label: 'Draw',
            active: _phase == _DrawPhase.drawing,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _DrawPhase.erasing,
            label: 'Erase',
            active: _phase == _DrawPhase.erasing,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _DrawPhase.selected,
            label: 'Select',
            active: _phase == _DrawPhase.selected,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _DrawPhase.deleting,
            label: 'Delete',
            active: _phase == _DrawPhase.deleting,
          ),
        ],
      ),
    );
  }

  Widget _buildToolSelector() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Wrap(
        spacing: SiliphSpacing.xs,
        runSpacing: SiliphSpacing.xs,
        children: [
          _ToolButton(
            icon: Icons.brush_outlined,
            label: 'Pen',
            isSelected: _drawState.tool == 'pen',
            onTap: () => _toggleTool('pen'),
          ),
          _ToolButton(
            icon: Icons.pencil_outlined,
            label: 'Pencil',
            isSelected: _drawState.tool == 'pencil',
            onTap: () => _toggleTool('pencil'),
          ),
          _ToolButton(
            icon: Icons.highlight_outlined,
            label: 'Highlight',
            isSelected: _drawState.tool == 'highlighter',
            onTap: () => _toggleTool('highlighter'),
          ),
          _ToolButton(
            icon: Icons.erase_outlined,
            label: 'Eraser',
            isSelected: _drawState.tool == 'eraser',
            onTap: () => _toggleTool('eraser'),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Row(
        children: [
          // Color palette
          Expanded(
            child: Wrap(
              spacing: SiliphSpacing.sm,
              children: _colorChips(),
            ),
          ),
          const SizedBox(width: SiliphSpacing.md),
          // Stroke width slider
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Width:', style: TextStyle(fontSize: 12)),
                Slider(
                  value: _drawState.strokeWidth,
                  min: 0.5,
                  max: 10,
                  onChanged: _changeStrokeWidth,
                ),
                Text('${_drawState.strokeWidth.toStringAsFixed(1)}px',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: SiliphSpacing.md),
          // Opacity slider
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Opacity:', style: TextStyle(fontSize: 12)),
                Slider(
                  value: _drawState.opacity,
                  min: 0.0,
                  max: 1.0,
                  onChanged: _changeOpacity,
                ),
                Text('${(_drawState.opacity * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return GestureDetector(
      onPanStart: (details) {
        _startDrawing(details.localPosition);
      },
      onPanUpdate: (details) {
        if (_phase == _DrawPhase.erasing) {
          _updateErasing(details.localPosition);
        } else {
          _updateDrawing(details.localPosition);
        }
      },
      onPanEnd: (_) {
        if (_phase == _DrawPhase.erasing) {
          _endErasing();
        } else {
          _endDrawing();
        }
      },
      child: CustomPaint(
        painter: _DrawPainter(drawState: _drawState),
        size: Size.infinite,
        // Fit: match parent size would be set by parent
      ),
    );
  }
}

// Tool button widget
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

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
          color: isSelected
              ? SiliphColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(SiliphRadii.md),
          border: Border.all(
            color: isSelected ? SiliphColors.primary : SiliphColors.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: isSelected ? SiliphColors.primary : null),
            const SizedBox(height: SiliphSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// Phase chip
class _PhaseChip extends StatelessWidget {
  final _DrawPhase phase;
  final String label;
  final bool active;

  const _PhaseChip({
    required this.phase,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _phase = phase),
      selectedColor: SiliphColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
    );
  }
}

// Color chips
class _ColorChip extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onSelected;

  const _ColorChip({
    required this.color,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: Colors.transparent,
      backgroundColor: Colors.transparent,
    );
  }
}

// Draw painter
class _DrawPainter extends CustomPainter {
  final _DrawState drawState;

  _DrawPainter({required this.drawState});

  @override
  void paint(Canvas canvas) {
    final strokePaint = Paint()
      ..color = drawState.color
      ..style = PaintingStyle.stroke
      ..strokeWidth: drawState.strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw completed strokes
    for (final stroke in drawState.completedStrokes) {
      if (stroke.length < 2) {
        canvas.drawCircle(
          stroke.first,
          drawState.strokeWidth / 2,
          strokePaint..color = drawState.color.withValues(alpha: drawState.opacity),
        );
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path,
          paint..color = drawState.color.withValues(alpha: drawState.opacity));
    }

    // Draw in-progress stroke
    if (drawState.points.length >= 2) {
      final path = Path()..moveTo(drawState.points.first.dx, drawState.points.first.dy);
      for (final point in drawState.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path,
          paint..color = drawState.color.withValues(alpha: drawState.opacity));
    }
  }

  @override
  bool shouldRepaint(_DrawPainter oldDelegate) => true;
}