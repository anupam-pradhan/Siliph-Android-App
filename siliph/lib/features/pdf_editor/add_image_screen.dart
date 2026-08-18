/// Add Image workflow (section 4).
///
/// Options: Photos, Files, Camera. After inserting: Move, Resize, Rotate,
/// Crop, Replace, Opacity, Delete. Shows selected image with resize handles.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';
import '../../generated/siliph_bridge.g.dart';

enum _ImagePhase { selectSource, inserting, editing, selected }

/// State for add image workflow.
class AddImageScreen extends ConsumerStatefulWidget {
  const AddImageScreen({
    super.key,
    required this.file,
  });

  final FileItem file;

  @override
  ConsumerState<AddImageScreen> createState() => _AddImageScreenState();
}

class _AddImageScreenState extends ConsumerState<AddImageScreen> {
  _ImagePhase _phase = _ImagePhase.selectSource;
  File? _selectedImage;
  double _zoom = 1.0;
  double _rotation = 0;
  Offset? _position;
  double _opacity = 1.0;
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

  // Duplicate state
  bool _isDuplicate = false;

  // Crop state
  Offset? _cropStart;
  Offset? _cropEnd;

  // Image selection
  ImageSource? _selectedSource;
  bool _isCamera = false;

  // Focus for camera
  FocusNode? _focusNode;

  _AddImageScreenState();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode?.dispose();
    super.dispose();
  }

  // Pick image from source
  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _phase = _ImagePhase.inserting;
      _selectedSource = source;
    });

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (picked != null && mounted) {
        setState(() {
          _selectedImage = File(picked.path);
          _phase = _ImagePhase.editing;
          // Set default position
          _position = const Offset(0.5, 0.5);
          _zoom = 1.0;
          _rotation = 0;
          _opacity = 1.0;
        });
      } else if (mounted) {
        setState(() {
          _phase = _ImagePhase.selectSource;
          _error = 'No image selected';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _ImagePhase.selectSource;
          _error = e.toString();
        });
      }
    }
  }

  // Take a photo
  Future<void> _takePhoto() async {
    _pickImage(ImageSource.camera);
  }

  // Pick from gallery
  Future<void> _pickFromGallery() async {
    _pickImage(ImageSource.gallery);
  }

  // Save the added image
  Future<void> _saveImage() async {
    setState(() => _isDirty = true);

    // TODO: Add image to PDF via engine
    // final handle = ref.read(pdfGatewayProvider).addImage(
    //   input: widget.file,
    //   image: _selectedImage!,
    //   position: _position!,
    //   zoom: _zoom,
    //   rotation: _rotation,
    //   opacity: _opacity,
    //   output: /* new output doc */,
    // );
    // await handle.done;

    if (!mounted) return;
    setState(() {
      _phase = _ImagePhase.selected;
      _isDirty = false;
    });
  }

  // Cancel and remove image
  void _cancelImage() {
    setState(() => _phase = _ImagePhase.selectSource);
    _selectedImage = null;
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
      final dx = position.dx - _dragCurrent!.dx;
      final dy = position.dy - _dragCurrent!.dy;
      // Update zoom based on drag distance
      _zoom = (_zoom + dx / 100).clamp(0.3, 3.0);
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
    final dx = position.dx - _dragStart!.dx;
    final dy = position.dy - _dragStart!.dy;
    setState(() {
      _rotation = atan2(dy, dx);
    });
  }

  // End rotate
  void _endRotate() {
    setState(() {
      _isRotating = false;
      _dragStart = null;
    });
  }

  // Duplicate the image
  void _duplicateImage() {
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

  // Crop the image
  void _cropImage() {
    setState(() {
      _cropStart = _dragStart;
      _cropEnd = _dragCurrent;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Image'),
        actions: [
          TextButton(onPressed: _cancelImage, child: const Text('Cancel')),
          TextButton(onPressed: _saveImage, child: const Text('Done')),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Phase indicator
            _buildPhaseIndicator(),

            // Source selection (only when idle)
            if (_phase == _ImagePhase.selectSource)
              _buildSourceSelection(),

            // Main editing area
            Expanded(
              child: _buildCanvasArea(),
            ),

            // Bottom toolbar
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
            phase: _ImagePhase.selectSource,
            label: 'Source',
            active: _phase == _ImagePhase.selectSource,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _ImagePhase.inserting,
            label: 'Inserting',
            active: _phase == _ImagePhase.inserting,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _ImagePhase.editing,
            label: 'Edit',
            active: _phase == _ImagePhase.editing,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _ImagePhase.selected,
            label: 'Selected',
            active: _phase == _ImagePhase.selected,
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined,
              size: 64, color: SiliphColors.primary),
          const SizedBox(height: SiliphSpacing.md),
          const Text('Add Image',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: SiliphSpacing.xs),
          const Text('Choose where to get the image from:'),
          const SizedBox(height: SiliphSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SourceButton(
                icon: Icons.photo_outlined,
                label: 'Photos',
                onTap: _pickFromGallery,
              ),
              const SizedBox(width: SiliphSpacing.lg),
              _SourceButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: _takePhoto,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: SiliphSpacing.md),
            Text(_error!,
                style: const TextStyle(color: SiliphColors.error)),
          ],
        ],
      ),
    );
  }

  Widget _buildCanvasArea() {
    final imgWidth = (_selectedImage != null ? 300 : 100).toDouble();
    final imgHeight = (_selectedImage != null ? 300 : 100).toDouble();

    return GestureDetector(
      onPanStart: (details) {
        if (_phase == _ImagePhase.editing || _phase == _ImagePhase.selected) {
          _startMove(details.localPosition);
        }
      },
      onPanUpdate: (details) {
        if (_phase == _ImagePhase.editing || _phase == _ImagePhase.selected) {
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
        if (_phase == _ImagePhase.editing || _phase == _ImagePhase.selected) {
          if (_isMoving) _endMove();
          if (_isResizing) _endResize();
          if (_isRotating) _endRotate();
        }
      },
      child: Stack(
        children: [
          // PDF background
          const Positioned(
            top: 50,
            left: 50,
            child: Icon(
              Icons.picture_as_pdf_outlined,
              size: 80,
              color: SiliphColors.outline,
            ),
          ),

          // Image object
          Positioned(
            left: (_position?.dx ?? 0.5) * 300 - imgWidth / 2,
            top: (_position?.dy ?? 0.5) * 300 - imgHeight / 2,
            child: GestureDetector(
              onPanStart: (details) => _startMove(details.localPosition),
              onPanUpdate: (details) => _updateMove(details.localPosition),
              onPanEnd: (_) => _endMove(),
              child: Transform.rotate(
                angle: _rotation,
                child: Container(
                  width: imgWidth * _zoom,
                  height: imgHeight * _zoom,
                  decoration: BoxDecoration(
                    color: SiliphColors.surface,
                    border: Border.all(color: SiliphColors.primary, width: 1),
                    borderRadius: BorderRadius.circular(SiliphRadii.sm),
                  ),
                  child: _selectedImage != null
                      ? Image.file(
                          _selectedImage!,
                          fit: BoxFit.contain,
                        )
                      : const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 40,
                            color: SiliphColors.outline,
                          ),
                        ),
                ),
              ),
            ),
          ),

          // Resize handles
          if (_phase == _ImagePhase.editing || _phase == _ImagePhase.selected)
            _buildImageResizeHandles(imgWidth, imgHeight),

          // Rotation handle
          if (_phase == _ImagePhase.editing || _phase == _ImagePhase.selected)
            _buildRotationHandle(),

          // Opacity slider
          if (_phase == _ImagePhase.selected)
            _buildOpacitySlider(),

          // Crop preview
          if (_phase == _ImagePhase.editing && _cropStart != null && _cropEnd != null)
            _buildCropPreview(imgWidth, imgHeight),
        ],
      ),
    );
  }

  Widget _buildImageResizeHandles(double imgWidth, double imgHeight) {
    return CustomPaint(
      size: Size(300, 300),
      painter: _ImageResizePainter(
        topLeft: _topLeftHandle ?? Offset((_position?.dx ?? 0.5) * 300 - imgWidth / 2, (_position?.dy ?? 0.5) * 300 - imgHeight / 2),
        topRight: _topRightHandle ?? Offset((_position?.dx ?? 0.5) * 300 + imgWidth / 2, (_position?.dy ?? 0.5) * 300 - imgHeight / 2),
        bottomLeft: _bottomLeftHandle ?? Offset((_position?.dx ?? 0.5) * 300 - imgWidth / 2, (_position?.dy ?? 0.5) * 300 + imgHeight / 2),
        bottomRight: _bottomRightHandle ?? Offset((_position?.dx ?? 0.5) * 300 + imgWidth / 2, (_position?.dy ?? 0.5) * 300 + imgHeight / 2),
        color: SiliphColors.primary,
      ),
    );
  }

  Widget _buildCropPreview(double imgWidth, double imgHeight) {
    return CustomPaint(
      size: Size(300, 300),
      painter: _CropPainter(
        start: _cropStart!,
        end: _cropEnd!,
        color: SiliphColors.primary.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildRotationHandle() {
    return CustomPaint(
      size: Size(300, 300),
      painter: _ImageRotatePainter(
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

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Row(
        children: [
          // Replace
          Expanded(
            child: _BottomToolChip(
              icon: Icons.swap_horiz_outlined,
              label: 'Replace',
              onTap: () => _pickFromGallery(),
            ),
          ),
          const SizedBox(width: SiliphSpacing.sm),

          // Crop
          Expanded(
            child: _BottomToolChip(
              icon: Icons.crop_outlined,
              label: 'Crop',
              onTap: _cropImage,
            ),
          ),
          const SizedBox(width: SiliphSpacing.sm),

          // Rotate
          Expanded(
            child: _BottomToolChip(
              icon: Icons.rotate_right_outlined,
              label: 'Rotate',
              onTap: () {
                setState(() {
                  _rotation += 0.5; // 90 degrees approx
                });
              },
            ),
          ),
          const SizedBox(width: SiliphSpacing.sm),

          // Duplicate
          Expanded(
            child: _BottomToolChip(
              icon: Icons.copy_outlined,
              label: 'Duplicate',
              onTap: _duplicateImage,
            ),
          ),
          const SizedBox(width: SiliphSpacing.sm),

          // Delete
          Expanded(
            child: _BottomToolChip(
              icon: Icons.delete_outlined,
              label: 'Delete',
              onTap: _cancelImage,
              isDestructive: true,
            ),
          ),
        ],
      ),
    );
  }
}

// Source button widget
class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SiliphRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SiliphSpacing.lg,
          vertical: SiliphSpacing.md,
        ),
        decoration: BoxDecoration(
          color: SiliphColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(SiliphRadii.md),
          border: Border.all(color: SiliphColors.primary),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.xs),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// Phase chip (reuse)
class _PhaseChip extends StatelessWidget {
  final _ImagePhase phase;
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
      onSelected: (_) {},
      selectedColor: SiliphColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
    );
  }
}

// Bottom tool chip (reuse pattern)
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
          border: Border.all(
            color: isDestructive ? SiliphColors.error : SiliphColors.primary,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18,
                color: isDestructive ? SiliphColors.error : SiliphColors.primary),
            const SizedBox(width: SiliphSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// Image resize painter
class _ImageResizePainter extends CustomPainter {
  final Offset? topLeft;
  final Offset? topRight;
  final Offset? bottomLeft;
  final Offset? bottomRight;
  final Color color;

  _ImageResizePainter({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final handleSize = 12.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final handles = <Offset?>[topLeft, topRight, bottomLeft, bottomRight];
    for (final handle in handles) {
      if (handle != null) {
        canvas.drawCircle(handle, handleSize / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ImageResizePainter oldDelegate) => true;
}

// Image rotate painter
class _ImageRotatePainter extends CustomPainter {
  final Color color;
  final double angle;

  _ImageRotatePainter({required this.color, required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final handleSize = 16.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(150, 150);
    final dx = handleSize * sin(angle);
    final dy = handleSize * cos(angle);
    final rotated = Offset(center.dx + dx, center.dy - dy);

    canvas.drawCircle(rotated, handleSize / 2, paint);
  }

  @override
  bool shouldRepaint(_ImageRotatePainter oldDelegate) => true;
}

// Crop painter
class _CropPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;

  _CropPainter({required this.start, required this.end, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(
      start.dx,
      start.dy,
      end.dx - start.dx,
      end.dy - start.dy,
    );

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) => true;
}