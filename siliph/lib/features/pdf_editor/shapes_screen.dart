/// Shapes tool (section 8).
///
/// Rectangle, rounded rectangle, circle, ellipse, line, arrow, checkmark, cross.
/// Properties: fill, border, border width, color, opacity.
/// Allow: move, resize, rotate, delete.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';
import '../../generated/siliph_bridge.g.dart';

enum _ShapeType { rectangle, roundedRect, circle, ellipse, line, arrow, checkmark, cross }

/// Shape model
class _ShapeModel {
  final _ShapeType type;
  final Rect rect;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  double opacity;
  double rotation;
  bool isSelected;

  _ShapeModel({
    required this.type,
    required this.rect,
    this.fillColor = Colors.transparent,
    this.borderColor = SiliphColors.primary,
    this.borderWidth = 1,
    this.opacity = 1.0,
    this.rotation = 0,
    this.isSelected = false,
  });

  _ShapeModel copyWith({
    _ShapeType? type,
    Rect? rect,
    Color? fillColor,
    Color? borderColor,
    double? borderWidth,
    double? opacity,
    double? rotation,
    bool? isSelected,
  }) {
    return _ShapeModel(
      type: type ?? this.type,
      rect: rect ?? this.rect,
      fillColor: fillColor ?? this.fillColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      opacity: opacity ?? this.opacity,
      rotation: rotation ?? this.rotation,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Shapes screen
class ShapesScreen extends ConsumerStatefulWidget {
  const ShapesScreen({
    super.key,
    required this.file,
    required this.pageNumber,
  });

  final FileItem file;
  final int pageNumber;

  @override
  ConsumerState<ShapesScreen> createState() => _ShapesScreenState;
}

class _ShapesScreenState extends ConsumerState<ShapesScreen> {
  _ShapeType _type = _ShapeType.rectangle;
  _ShapeModel _shape = _ShapeModel(
    type: _ShapeType.rectangle,
    rect: const Rect.fromLTRB(0, 0, 100, 100),
  );
  bool _isDirty = false;
  String? _error;

  // Object control state
  bool _isMoving = false;
  bool _isResizing = false;
  bool _isRotating = false;
  Offset? _dragStart;
  Offset? _dragCurrent;

  // Resize handles
  Offset? _topLeftHandle;
  Offset? _topRightHandle;
  Offset? _bottomLeftHandle;
  Offset? _bottomRightHandle;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Start creating shape
  void _startCreate(Offset position) {
    setState(() {
      _shape = _shape.copyWith(
        rect: Rect.fromLTWH(position.dx, position.dy, 0, 0),
      );
    });
  }

  // Update shape while creating
  void _updateCreate(Offset position) {
    setState(() {
      final rect = _shape.rect;
      _shape = _shape.copyWith(
        rect: Rect.fromLTWH(
          rect.left.min(position.dx),
          rect.top.min(position.dy),
          (position.dx - rect.left).abs(),
          (position.dy - rect.top).abs(),
        ),
      );
    });
  }

  // Finish creating shape
  void _finishCreate() {
    setState(() {});
  }

  // Start moving
  void _startMove(Offset position) {
    setState(() {
      _isMoving = true;
      _dragStart = position;
    });
  }

  // Update move
  void _updateMove(Offset position) {
    setState(() {
      final width = _shape.rect.width;
      final height = _shape.rect.height;
      _shape = _shape.copyWith(
        rect: Rect.fromLTWH(
          position.dx - width / 2,
          position.dy - height / 2,
          width,
          height,
        ),
      );
    });
  }

  // End move
  void _endMove() {
    setState(() {
      _isMoving = false;
      _dragStart = null;
    });
  }

  // Start resizing
  void _startResize(Offset handlePos, Offset position) {
    setState(() {
      _isResizing = true;
      _dragStart = handlePos;
      _dragCurrent = position;
    });
  }

  // Update resize
  void _updateResize(Offset position) {
    setState(() {
      final dx = position.dx - _dragCurrent!.dx;
      final dy = position.dy - _dragCurrent!.dy;
      final rect = _shape.rect;
      switch (_dragStart) {
        case _topLeftHandle:
          _shape = _shape.copyWith(
            rect: Rect.fromLTWH(
              rect.left + dx,
              rect.top + dy,
              rect.right - dx,
              rect.bottom - dy,
            ),
          );
          break;
        case _topRightHandle:
          _shape = _shape.copyWith(
            rect: Rect.fromLTWH(
              rect.left,
              rect.top + dy,
              rect.right + dx,
              rect.bottom - dy,
            ),
          );
          break;
        case _bottomLeftHandle:
          _shape = _shape.copyWith(
            rect: Rect.fromLTWH(
              rect.left + dx,
              rect.top,
              rect.right - dx,
              rect.bottom - dy,
            ),
          );
          break;
        case _bottomRightHandle:
          _shape = _shape.copyWith(
            rect: Rect.fromLTWH(
              rect.left,
              rect.top,
              rect.right + dx,
              rect.bottom - dy,
            ),
          );
          break;
      }
      _dragCurrent = position;
    });
  }

  // End resize
  void _endResize() {
    setState(() {
      _isResizing = false;
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  // Start rotating
  void _startRotate(Offset position) {
    setState(() {
      _isRotating = true;
      _dragStart = position;
    });
  }

  // Update rotate
  void _updateRotate(Offset position) {
    final dx1 = _dragStart!.dx - _shape.rect.center.dx;
    final dy1 = _dragStart!.dy - _shape.rect.center.dy;
    final dx2 = position.dx - _shape.rect.center.dx;
    final dy2 = position.dy - _shape.rect.center.dy;
    final angle = dy2.atan2(dx2) - dy1.atan2(dx1);
    setState(() {
      _shape = _shape.copyWith(rotation: _shape.rotation + angle);
    });
  }

  // End rotate
  void _endRotate() {
    setState(() {
      _isRotating = false;
      _dragStart = null;
    });
  }

  // Change shape type
  void _changeType(_ShapeType type) {
    setState(() {
      _type = type;
      _shape = _shape.copyWith(type: type);
    });
  }

  // Change fill color
  void _changeFillColor(Color color) {
    setState(() {
      _shape = _shape.copyWith(fillColor: color);
    });
  }

  // Change border color
  void _changeBorderColor(Color color) {
    setState(() {
      _shape = _shape.copyWith(borderColor: color);
    });
  }

  // Change border width
  void _changeBorderWidth(double width) {
    setState(() {
      _shape = _shape.copyWith(borderWidth: width);
    });
  }

  // Change opacity
  void _changeOpacity(double value) {
    setState(() {
      _shape = _shape.copyWith(opacity: value);
    });
  }

  // Toggle selection
  void _toggleSelection() {
    setState(() {
      _shape = _shape.copyWith(isSelected: !_shape.isSelected);
    });
  }

  // Delete shape
  void _deleteShape() {
    setState(() {
      _isDirty = true;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // Duplicate shape
  void _duplicateShape() {
    setState(() {
      _shape = _shape.copyWith(isSelected: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shapes'),
        actions: [
          if (_shape.isSelected)
            IconButton(
              icon: const Icon(Icons.delete_outlined),
              tooltip: 'Delete',
              onPressed: _deleteShape,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildToolbar(),
            Expanded(
              child: _buildCanvas(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShapeTypeSelector(
            type: _type,
            onSelected: _changeType,
          ),
          const SizedBox(height: SiliphSpacing.md),
          Row(
            children: [
              Expanded(
                child: _ActionChip(
                  label: _shape.isSelected ? 'Done' : 'Select',
                  icon: _shape.isSelected ? Icons.check_outlined : Icons.select_outlined,
                  onTap: _toggleSelection,
                  isSelected: _shape.isSelected,
                ),
              ),
              const SizedBox(width: SiliphSpacing.sm),
              Expanded(
                child: _ActionChip(
                  label: 'Duplicate',
                  icon: Icons.copy_outlined,
                  onTap: _duplicateShape,
                ),
              ),
            ],
          ),
          const SizedBox(height: SiliphSpacing.md),
          _ColorChips(
            label: 'Fill',
            color: _shape.fillColor,
            onSelected: _changeFillColor,
          ),
          const SizedBox(height: SiliphSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _BorderWidthSlider(
                  width: _shape.borderWidth,
                  onChanged: _changeBorderWidth,
                ),
              ),
              const SizedBox(width: SiliphSpacing.sm),
              Expanded(
                child: _ColorChips(
                  label: 'Border',
                  color: _shape.borderColor,
                  onSelected: _changeBorderColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: SiliphSpacing.sm),
          Row(
            children: [
              const Text('Opacity:', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _shape.opacity,
                  min: 0.0,
                  max: 1.0,
                  onChanged: _changeOpacity,
                ),
              ),
              Text('${(_shape.opacity * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return GestureDetector(
      onPanStart: (details) {
        if (!_shape.isSelected) {
          _startCreate(details.localPosition);
        } else {
          _startMove(details.localPosition);
        }
      },
      onPanUpdate: (details) {
        if (!_shape.isSelected) {
          _updateCreate(details.localPosition);
        } else if (_isMoving) {
          _updateMove(details.localPosition);
        } else if (_isResizing) {
          _updateResize(details.localPosition);
        } else if (_isRotating) {
          _updateRotate(details.localPosition);
        }
      },
      onPanEnd: (_) {
        if (!_shape.isSelected) {
          _finishCreate();
        } else if (_isMoving) {
          _endMove();
        } else if (_isResizing) {
          _endResize();
        } else if (_isRotating) {
          _endRotate();
        }
      },
      child: CustomPaint(
        painter: _ShapePainter(shape: _shape),
        size: const Size(300, 300),
      ),
    );
  }
}

// Shape type selector
class _ShapeTypeSelector extends StatelessWidget {
  final _ShapeType type;
  final ValueChanged<_ShapeType> onSelected;

  const _ShapeTypeSelector({
    required this.type,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SiliphSpacing.xs,
      children: [
        _ShapeChip(
          shapeType: _ShapeType.rectangle,
          isSelected: type == _ShapeType.rectangle,
          onSelected: onSelected,
        ),
        _ShapeChip(
          shapeType: _ShapeType.roundedRect,
          isSelected: type == _ShapeType.roundedRect,
          onSelected: onSelected,
        ),
        _ShapeChip(
          shapeType: _ShapeType.circle,
          isSelected: type == _ShapeType.circle,
          onSelected: onSelected,
        ),
        _ShapeChip(
          shapeType: _ShapeType.ellipse,
          isSelected: type == _ShapeType.ellipse,
          onSelected: onSelected,
        ),
        _ShapeChip(
          shapeType: _ShapeType.line,
          isSelected: type == _ShapeType.line,
          onSelected: onSelected,
        ),
        _ShapeChip(
          shapeType: _ShapeType.arrow,
          isSelected: type == _ShapeType.arrow,
          onSelected: onSelected,
        ),
        _ShapeChip(
          shapeType: _ShapeType.checkmark,
          isSelected: type == _ShapeType.checkmark,
          onSelected: onSelected,
        ),
        _ShapeChip(
          shapeType: _ShapeType.cross,
          isSelected: type == _ShapeType.cross,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

// Shape chip
class _ShapeChip extends StatelessWidget {
  final _ShapeType shapeType;
  final bool isSelected;
  final VoidCallback onSelected;

  const _ShapeChip({
    required this.shapeType,
    required this.isSelected,
    required this.onSelected,
  });

  String _getChipLabel(_ShapeType type) {
    switch (type) {
      case _ShapeType.rectangle:
        return 'Rect';
      case _ShapeType.roundedRect:
        return 'Rounded';
      case _ShapeType.circle:
        return 'Circle';
      case _ShapeType.ellipse:
        return 'Ellipse';
      case _ShapeType.line:
        return 'Line';
      case _ShapeType.arrow:
        return 'Arrow';
      case _ShapeType.checkmark:
        return 'Check';
      case _ShapeType.cross:
        return 'Cross';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(_getChipLabel(shapeType)),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: SiliphColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
    );
  }
}

// Action chip
class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: SiliphSpacing.xs),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: SiliphColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
    );
  }
}

// Border width slider
class _BorderWidthSlider extends StatelessWidget {
  final double width;
  final Function(double) onChanged;

  const _BorderWidthSlider({
    required this.width,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Width:', style: TextStyle(fontSize: 12)),
        Slider(
          value: width,
          min: 0,
          max: 10,
          divisions: 20,
          onChanged: onChanged,
        ),
        Text('${width.toStringAsFixed(1)}px', style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// Color chips reusable
class _ColorChips extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onSelected;

  const _ColorChips({
    required this.label,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: SiliphSpacing.xs),
        Wrap(
          spacing: SiliphSpacing.xs,
          children: [
            _ColorChip(
              color: SiliphColors.primary,
              isSelected: color == SiliphColors.primary,
              onSelected: (_) => onSelected(SiliphColors.primary),
            ),
            _ColorChip(
              color: SiliphColors.warning,
              isSelected: color == SiliphColors.warning,
              onSelected: (_) => onSelected(SiliphColors.warning),
            ),
            _ColorChip(
              color: SiliphColors.error,
              isSelected: color == SiliphColors.error,
              onSelected: (_) => onSelected(SiliphColors.error),
            ),
            _ColorChip(
              color: SiliphColors.info,
              isSelected: color == SiliphColors.info,
              onSelected: (_) => onSelected(SiliphColors.info),
            ),
          ],
        ),
      ],
    );
  }
}

// Color chip
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

// Shape painter
class _ShapePainter extends CustomPainter {
  final _ShapeModel shape;

  _ShapePainter({required this.shape});

  @override
  bool get shouldRepaint => true;

  @override
  void paint(Canvas canvas) {
    // Save transformation
    final center = shape.rect.center;
    canvas.translate(center.dx, center.dy);
    canvas.rotate(shape.rotation);
    translate(-center.dx, -center.dy);

    final fillPaint = Paint()
      ..color = shape.fillColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = shape.borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth: shape.borderWidth
      ..strokeCap = StrokeCap.round;

    switch (shape.type) {
      case _ShapeType.rectangle:
        if (shape.fillColor.alpha > 0) {
          canvas.drawRect(shape.rect, fillPaint);
        }
        canvas.drawRect(shape.rect, strokePaint);
        break;
      case _ShapeType.roundedRect:
        final radius = min(shape.rect.width, shape.rect.height) / 6;
        if (shape.fillColor.alpha > 0) {
          canvas.drawRRect(
            RRect.fromLTRBR(
              shape.rect.left,
              shape.rect.top,
              shape.rect.right,
              shape.rect.bottom,
              Radius.elliptical(radius, radius),
            ),
            fillPaint,
          );
        }
        canvas.drawRRect(
          RRect.fromLTRBR(
            shape.rect.left,
            shape.rect.top,
            shape.rect.right,
            shape.rect.bottom,
            Radius.elliptical(radius, radius),
          ),
          strokePaint,
        );
        break;
      case _ShapeType.circle:
        final center = shape.rect.center;
        final radius = min(shape.rect.width, shape.rect.height) / 2;
        if (shape.fillColor.alpha > 0) {
          canvas.drawCircle(center, radius, fillPaint);
        }
        canvas.drawCircle(center, radius, strokePaint);
        break;
      case _ShapeType.ellipse:
        final center = shape.rect.center;
        final rx = shape.rect.width / 2;
        final ry = shape.rect.height / 2;
        if (shape.fillColor.alpha > 0) {
          canvas.drawOval(
            Rect.fromLTWH(shape.rect.left, shape.rect.top, shape.rect.width, shape.rect.height),
            fillPaint,
          );
        }
        canvas.drawOval(
          Rect.fromLTWH(shape.rect.left, shape.rect.top, shape.rect.width, shape.rect.height),
          strokePaint,
        );
        break;
      case _ShapeType.line:
        final start = Offset(shape.rect.left, shape.rect.center.dy);
        final end = Offset(shape.rect.right, shape.rect.center.dy);
        canvas.drawLine(start, end, strokePaint);
        final capSize = shape.borderWidth * 2;
        canvas.drawLine(
          Offset(start.dx - capSize, start.dy),
          Offset(start.dx + capSize, start.dy),
          strokePaint,
        );
        canvas.drawLine(
          Offset(end.dx - capSize, end.dy),
          Offset(end.dx + capSize, end.dy),
          strokePaint,
        );
        break;
      case _ShapeType.arrow:
        final start = Offset(shape.rect.left, shape.rect.center.dy);
        final end = Offset(shape.rect.right, shape.rect.center.dy);
        canvas.drawLine(start, end, strokePaint);
        final headSize = shape.borderWidth * 3;
        final angle = atan2(end.dy - start.dy, end.dx - start.dx);
        final left = Offset(
          end.dx - headSize * cos(angle - pi / 6),
          end.dy - headSize * sin(angle - pi / 6),
        );
        final right = Offset(
          end.dx - headSize * cos(angle + pi / 6),
          end.dy - headSize * sin(angle + pi / 6),
        );
        canvas.drawLine(end, left, strokePaint);
        canvas.drawLine(end, right, strokePaint);
        break;
      case _ShapeType.checkmark:
        final checkPaint = Paint()
          ..color = shape.borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth: shape.borderWidth
          ..strokeCap = StrokeCap.round;
        final center = shape.rect.center;
        final size = min(shape.rect.width, shape.rect.height) / 3;
        canvas.drawLine(
          Offset(center.dx - size, center.dy),
          Offset(center.dx, center.dy + size),
          checkPaint,
        );
        canvas.drawLine(
          Offset(center.dx, center.dy + size),
          Offset(center.dx + size, center.dy - size),
          checkPaint,
        );
        break;
      case _ShapeType.cross:
        final crossPaint = Paint()
          ..color = shape.borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth: shape.borderWidth
          ..strokeCap = StrokeCap.round;
        final center = shape.rect.center;
        final size = min(shape.rect.width, shape.rect.height) / 3;
        canvas.drawLine(
          Offset(center.dx - size, center.dy - size),
          Offset(center.dx + size, center.dy + size),
          crossPaint,
        );
        canvas.drawLine(
          Offset(center.dx - size, center.dy + size),
          Offset(center.dx + size, center.dy - size),
          crossPaint,
        );
        break;
    }
  }
}