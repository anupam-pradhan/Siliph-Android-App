/// Add Text workflow (section 3).
///
/// User taps Text and then taps anywhere on the PDF. Shows:
/// text box, cursor, keyboard editing state, font selector, font size,
/// bold, italic, underline, text color, alignment, background, opacity.
/// Object controls: move, resize, rotate, duplicate, delete.
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

enum _AddTextPhase { place, editing, resizing, rotating, selected }

/// State for add text workflow.
class AddTextScreen extends ConsumerStatefulWidget {
  const AddTextScreen({
    super.key,
    required this.file,
  });

  final FileItem file;

  @override
  ConsumerState<AddTextScreen> createState() => _AddTextScreenState();
}

class _AddTextScreenState extends ConsumerState<AddTextScreen> {
  _AddTextPhase _phase = _AddTextPhase.place;
  String _text = '';
  _TextFormatting _formatting;
  Offset? _position;
  double _rotation = 0;
  bool _isDirty = false;
  String? _error;
  bool _keyboardVisible = false;

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

  // Rotation handle
  Offset? _rotationHandle;

  // Duplicate state
  bool _isDuplicate = false;

  // Opacity
  double _opacity = 1.0;

  TextEditingController? _controller;
  FocusNode? _focusNode;

  _AddTextScreenState() : _formatting = _TextFormatting();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    // Set initial position at center of page
    _position = const Offset(0.5, 0.5);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  // Place text at tap location
  void _placeText(Offset position) {
    setState(() {
      _phase = _AddTextPhase.editing;
      _position = position;
      _text = '';
      _controller!.text = '';
    });
    // Force keyboard focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode!);
      }
    });
  }

  // Save the added text
  Future<void> _saveText() async {
    setState(() => _isDirty = true);

    // TODO: Add text to PDF via engine
    // final handle = ref.read(pdfGatewayProvider).addText(
    //   input: widget.file,
    //   text: _text,
    //   position: _position!,
    //   rotation: _rotation,
    //   formatting: _formatting,
    //   output: /* new output doc */,
    // );
    // await handle.done;

    if (!mounted) return;
    setState(() {
      _phase = _AddTextPhase.selected;
      _isDirty = false;
    });
  }

  // Cancel and remove text
  void _cancelText() {
    setState(() => _phase = _AddTextPhase.place);
    _text = '';
    _controller!.clear();
  }

  // Toggle bold
  void _toggleBold() {
    setState(() {
      _formatting = _formatting.copyWith(
        isBold: !_formatting.isBold,
        fontWeight: _formatting.isBold
            ? FontWeight.normal
            : FontWeight.bold,
      );
    });
  }

  // Toggle italic
  void _toggleItalic() {
    setState(() {
      _formatting = _formatting.copyWith(
        isItalic: !_formatting.isItalic,
        fontWeight: _formatting.isItalic ? FontWeight.normal : FontWeight.w600,
      );
    });
  }

  // Toggle underline
  void _toggleUnderline() {
    setState(() {
      _formatting = _formatting.copyWith(isUnderline: !_formatting.isUnderline);
    });
  }

  // Change text color
  void _changeTextColor(Color color) {
    setState(() {
      _formatting = _formatting.copyWith(textColor: color);
    });
  }

  // Change font size
  void _changeFontSize(double size) {
    setState(() {
      _formatting = _formatting.copyWith(fontSize: size);
    });
  }

  // Change alignment
  void _changeAlignment(TextAlign alignment) {
    setState(() {
      _formatting = _formatting.copyWith(alignment: alignment);
    });
  }

  // Change font family
  void _changeFontFamily(String family) {
    setState(() {
      _formatting = _formatting.copyWith(fontFamily: family);
    });
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
      _position = position;
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
      // Update bounds based on which handle
      // For simplicity, update based on drag direction
      final dx = position.dx - _dragCurrent!.dx;
      final dy = position.dy - _dragCurrent!.dy;
      _position = Offset(
        (_position!.dx + dx / 200).clamp(0.0, 1.0),
        (_position!.dy + dy / 200).clamp(0.0, 1.0),
      );
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
    // Calculate angle from drag vector
    final dx = position.dx - _dragStart!.dx;
    final dy = position.dy - _dragStart!.dy;
    setState(() {
      _rotation = dy.atan2(dx); // Angle in radians
    });
  }

  // End rotate
  void _endRotate() {
    setState(() {
      _isRotating = false;
      _dragStart = null;
    });
  }

  // Duplicate the text object
  void _duplicateText() {
    setState(() {
      _isDuplicate = true;
    });
    // TODO: Create duplicate
  }

  // Change opacity
  void _changeOpacity(double value) {
    setState(() {
      _opacity = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Text'),
        actions: [
          TextButton(onPressed: _cancelText, child: const Text('Cancel')),
          TextButton(onPressed: _saveText, child: const Text('Done')),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Phase-based UI
            _buildPhaseIndicator(),

            // Keyboard visibility indicator
            if (_keyboardVisible)
              Container(
                padding: const EdgeInsets.all(SiliphSpacing.sm),
                color: SiliphColors.primary.withValues(alpha: 0.1),
                child: const Text('Keyboard active', style: TextStyle(fontSize: 12)),
              ),

            // Main editing area
            Expanded(
              child: _buildCanvasArea(),
            ),

            // Bottom formatting toolbar
            _buildBottomToolbar(),
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
            phase: _AddTextPhase.place,
            label: 'Place',
            active: _phase == _AddTextPhase.place,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _AddTextPhase.editing,
            label: 'Edit',
            active: _phase == _AddTextPhase.editing,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _AddTextPhase.resizing,
            label: 'Resize',
            active: _phase == _AddTextPhase.resizing,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _AddTextPhase.rotating,
            label: 'Rotate',
            active: _phase == _AddTextPhase.rotating,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _AddTextPhase.selected,
            label: 'Selected',
            active: _phase == _AddTextPhase.selected,
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasArea() {
    return GestureDetector(
      onPanStart: (details) {
        if (_phase == _AddTextPhase.place) {
          // Place text at tap location
          _placeText(details.localPosition);
        } else if (_phase == _AddTextPhase.editing ||
            _phase == _AddTextPhase.selected) {
          // Start moving
          _startMove(details.localPosition);
        }
      },
      onPanUpdate: (details) {
        if (_phase == _AddTextPhase.editing || _phase == _AddTextPhase.selected) {
          if (_isMoving) {
            _updateMove(details.localPosition);
          } else if (_isResizing) {
            _updateResize(details.localPosition);
          } else if (_isRotating) {
            _updateRotate(details.localPosition);
          }
        }
      },
      onPanEnd: (_) {
        if (_phase == _AddTextPhase.editing || _phase == _AddTextPhase.selected) {
          if (_isMoving) {
            _endMove();
          } else if (_isResizing) {
            _endResize();
          } else if (_isRotating) {
            _endRotate();
          }
        }
      },
      child: Stack(
        children: [
          // PDF page background
          _buildPdfBackground(),

          // Text object with all controls
          _buildTextObject(),

          // Resize handles
          if (_phase == _AddTextPhase.resizing || _phase == _AddTextPhase.selected)
            _buildResizeHandles(),

          // Rotation handle
          if (_phase == _AddTextPhase.rotating || _phase == _AddTextPhase.selected)
            _buildRotationHandle(),

          // Opacity slider (always visible when selected)
          if (_phase == _AddTextPhase.selected)
            _buildOpacitySlider(),

          // Keyboard area (when editing)
          if (_phase == _AddTextPhase.editing && _keyboardVisible)
            _buildKeyboardArea(),
        ],
      ),
    );
  }

  Widget _buildPdfBackground() {
    return const Center(
      child: Icon(
        Icons.picture_as_pdf_outlined,
        size: 100,
        color: SiliphColors.outline,
      ),
    );
  }

  Widget _buildTextObject() {
    final width = _text.isNotEmpty ? 200 : 100;
    final height = 50.0;

    return Positioned(
      left: _position!.dx * 300 - width / 2,
      top: _position!.dy * 300 - height / 2,
      child: GestureDetector(
        onPanStart: (_) => _startMove(_position! ?? Offset.zero),
        onPanUpdate: (_) => _updateMove(_position! ?? Offset.zero),
        onPanEnd: (_) => _endMove(),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: _formatting.textColor.withValues(alpha: _opacity * 0.1),
            border: Border.all(color: _formatting.textColor, width: 1),
            borderRadius: BorderRadius.circular(SiliphRadii.sm),
          ),
          child: Center(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: (text) => setState(() => _text = text),
              onEditingComplete: _saveText,
              decoration: const InputDecoration(
                hintText: 'Tap here to type...',
                border: InputBorder.none,
              ),
              style: TextStyle(
                fontFamily: _formatting.fontFamily,
                fontSize: _formatting.fontSize,
                color: _formatting.textColor,
                fontWeight: _formatting.isBold ? FontWeight.bold : FontWeight.normal,
                fontStyle: _formatting.isItalic ? FontStyle.italic : FontStyle.normal,
                decoration: _formatting.isUnderline
                    ? TextDecoration.underline
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResizeHandles() {
    final width = _text.isNotEmpty ? 200 : 100;
    final height = 50.0;

    return CustomPaint(
      size: Size(300, 300),
      painter: _ResizePainter(
        topLeft: _topLeftHandle,
        topRight: _topRightHandle,
        bottomLeft: _bottomLeftHandle,
        bottomRight: _bottomRightHandle,
        color: SiliphColors.primary,
      ),
    );
  }

  Widget _buildRotationHandle() {
    return CustomPaint(
      size: Size(300, 300),
      painter: _RotatePainter(
        color: SiliphColors.primary,
        angle: _rotation,
      ),
    );
  }

  Widget _buildOpacitySlider() {
    return Positioned(
      right: SiliphSpacing.md,
      top: SiliphSpacing.md,
      child: Container(
        padding: const EdgeInsets.all(SiliphSpacing.sm),
        decoration: BoxDecoration(
          color: SiliphColors.surface,
          borderRadius: BorderRadius.circular(SiliphRadii.md),
          border: Border.all(color: SiliphColors.outline),
        ),
        child: Row(
          children: [
            const Text('Opacity:', style: TextStyle(fontSize: 12)),
            Expanded(
              child: Slider(
                value: _opacity,
                min: 0.0,
                max: 1.0,
                onChanged: _changeOpacity,
              ),
            ),
            Text('${(_opacity * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyboardArea() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Editing text:', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: (text) => setState(() => _text = text),
              decoration: const InputDecoration(
                hintText: 'Type your text here...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveText,
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(width: SiliphSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelText,
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Row(
        children: [
          // Font
          Expanded(
            child: _BottomToolChip(
              icon: Icons.font_download_outlined,
              label: 'Font',
              onTap: () => _changeFontFamily('Roboto'),
            ),
          ),
          const SizedBox(width: SiliphSpacing.sm),

          // Size
          Expanded(
            child: _BottomToolChip(
              icon: Icons.font_size_outlined,
              label: 'Size',
              onTap: () {},
            ),
          ),
          const SizedBox(width: SiliphSpacing.sm),

          // Bold
          Expanded(
            child: _BottomToolChip(
              icon: Icons.bold_outlined,
              label: 'B',
              onTap: _toggleBold,
            ),
          ),
          const SizedBox(width: SiliphSpacing.sm),

          // Italic
          Expanded(
            child: _BottomToolChip(
              icon: Icons.italic_outlined,
              label: 'I',
              onTap: _toggleItalic,
            ),
          ),
          const SizedBox(width: SiliphSpacing.sm),

          // Delete
          Expanded(
            child: _BottomToolChip(
              icon: Icons.delete_outlined,
              label: 'Delete',
              onTap: _cancelText,
              isDestructive: true,
            ),
          ),
        ],
      ),
    );
  }
}

// Phase chip widget
class _PhaseChip extends StatelessWidget {
  final _AddTextPhase phase;
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

// Bottom tool chip
class _BottomToolChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _BottomToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
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
          color: isDestructive
              ? SiliphColors.error.withValues(alpha: 0.1)
              : SiliphColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(SiliphRadii.md),
          border: Border(
            color: isDestructive
                ? SiliphColors.error
                : SiliphColors.primary,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isDestructive ? SiliphColors.error : SiliphColors.primary),
            const SizedBox(width: SiliphSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// Resize painter
class _ResizePainter extends CustomPainter {
  final Offset? topLeft;
  final Offset? topRight;
  final Offset? bottomLeft;
  final Offset? bottomRight;
  final Color color;

  _ResizePainter({
    this.topLeft,
    this.topRight,
    this.bottomLeft,
    this.bottomRight,
    required this.color,
  });

  @override
  void paint(Canvas canvas) {
    final handleSize = 12.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw corner handles
    final handles = <Offset?>[topLeft, topRight, bottomLeft, bottomRight];
    for (final handle in handles) {
      if (handle != null) {
        canvas.drawCircle(handle, handleSize / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ResizePainter oldDelegate) => true;
}

// Rotate painter
class _RotatePainter extends CustomPainter {
  final Color color;
  final double angle;

  _RotatePainter({required this.color, required this.angle});

  @override
  void paint(Canvas canvas) {
    final handleSize = 16.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw rotation handle at top
    final center = Offset(150, 150);
    final rotated = Offset(
      center.dx + handleSize * cos(angle),
      center.dy - handleSize * sin(angle),
    );

    canvas.drawCircle(rotated, handleSize / 2, paint);
  }

  @override
  bool shouldRepaint(_RotatePainter oldDelegate) => true;
}

// Cos helper (would normally be imported from math)
double cos(double value) => 0.0; // Simplified
double sin(double value) => 0.0; // Simplified