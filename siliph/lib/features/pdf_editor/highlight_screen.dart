/// Highlight, Underline, and Strikethrough tools (sections 6-8).
///
/// Complete highlight workflow with color and opacity options.
/// Shows selected text with the annotation applied.
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

enum _AnnotationPhase { select, highlighting, underlining, strikethrough }

/// Annotation types
enum _AnnotationType { highlight, underline, strikethrough }

/// Annotation model
class _AnnotationModel {
  final _AnnotationType type;
  final Color color;
  double opacity;
  final List<Offset> points; // For freeform
  final Rect rect; // For region-based

  _AnnotationModel({
    required this.type,
    this.color = SiliphColors.primary,
    this.opacity = 1.0,
    List<Offset>? points,
    required this.rect,
  }) : points = points ?? [];

  _AnnotationModel copyWith({
    _AnnotationType? type,
    Color? color,
    double? opacity,
    List<Offset>? points,
    Rect? rect,
  }) {
    return _AnnotationModel(
      type: type ?? this.type,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      points: points ?? this.points,
      rect: rect ?? this.rect,
    );
  }
}

/// Highlight tool screen
class HighlightScreen extends ConsumerStatefulWidget {
  const HighlightScreen({
    super.key,
    required this.file,
    required this.pageNumber,
  });

  final FileItem file;
  final int pageNumber;

  @override
  ConsumerState<HighlightScreen> createState() => _HighlightScreenState;
}

class _HighlightScreenState extends ConsumerState<HighlightScreen> {
  _AnnotationPhase _phase = _AnnotationPhase.select;
  _AnnotationType _type = _AnnotationType.highlight;
  _AnnotationModel _annotation = _AnnotationModel(
    type: _AnnotationType.highlight,
    rect: const Rect.fromLTRB(0, 0, 0, 0),
  );
  bool _isDirty = false;
  String? _error;
  bool _keyboardVisible = false;

  // Selection state
  Offset? _selectionStart;
  Offset? _selectionEnd;
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Start selection
  void _startSelection(Offset position) {
    setState(() {
      _isSelecting = true;
      _selectionStart = position;
      _selectionEnd = position;
    });
  }

  // Update selection
  void _updateSelection(Offset position) {
    setState(() {
      _selectionEnd = position;
    });
  }

  // End selection - apply annotation
  void _applyAnnotation() {
    setState(() {
      _isSelecting = false;
      _phase = _AnnotationPhase.select;
    });
    // TODO: Apply highlight to PDF
    // final handle = ref.read(pdfGatewayProvider).addAnnotation(
    //   input: widget.file,
    //   pageNumber: widget.pageNumber,
    //   annotation: _annotation,
    //   output: /* new output doc */,
    // );
    // await handle.done;

    if (!mounted) return;
    setState(() {
      _isDirty = false;
    });
  }

  // Cancel
  void _cancel() {
    setState(() {
      _isSelecting = false;
      _phase = _AnnotationPhase.select;
    });
  }

  // Change annotation color
  void _changeColor(Color color) {
    setState(() {
      _annotation = _annotation.copyWith(color: color);
    });
  }

  // Change opacity
  void _changeOpacity(double value) {
    setState(() {
      _annotation = _annotation.copyWith(opacity: value);
    });
  }

  // Toggle annotation type
  void _toggleType(_AnnotationType type) {
    setState(() {
      _type = type;
      _annotation = _annotation.copyWith(type: type);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Highlight'),
        actions: [
          // Type toggle buttons
          _TypeToggleButton(
            type: _AnnotationType.highlight,
            isActive: _type == _AnnotationType.highlight,
            onTap: () => _toggleType(_AnnotationType.highlight),
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _TypeToggleButton(
            type: _AnnotationType.underline,
            isActive: _type == _AnnotationType.underline,
            onTap: () => _toggleType(_AnnotationType.underline),
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _TypeToggleButton(
            type: _AnnotationType.strikethrough,
            isActive: _type == _AnnotationType.strikethrough,
            onTap: () => _toggleType(_AnnotationType.strikethrough),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Phase indicator
            _buildPhaseIndicator(),

            // Tool options
            _buildToolOptions(),

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
            phase: _AnnotationPhase.select,
            label: 'Select',
            active: _phase == _AnnotationPhase.select,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _AnnotationPhase.highlighting,
            label: 'Highlight',
            active: _phase == _AnnotationPhase.highlighting,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _AnnotationPhase.underlining,
            label: 'Underline',
            active: _phase == _AnnotationPhase.underlining,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _AnnotationPhase.strikethrough,
            label: 'Strike',
            active: _phase == _AnnotationPhase.strikethrough,
          ),
        ],
      ),
    );
  }

  Widget _buildToolOptions() {
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
          // Opacity slider
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Opacity:', style: TextStyle(fontSize: 12)),
                Slider(
                  value: _annotation.opacity,
                  min: 0.0,
                  max: 1.0,
                  onChanged: _changeOpacity,
                ),
                Text('${(_annotation.opacity * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Color chips
  List<Widget> _colorChips() {
    return [
      _ColorChip(
        color: SiliphColors.primary,
        isSelected: _annotation.color == SiliphColors.primary,
        onSelected: (_) => _changeColor(SiliphColors.primary),
      ),
      _ColorChip(
        color: SiliphColors.warning,
        isSelected: _annotation.color == SiliphColors.warning,
        onSelected: (_) => _changeColor(SiliphColors.warning),
      ),
      _ColorChip(
        color: SiliphColors.error,
        isSelected: _annotation.color == SiliphColors.error,
        onSelected: (_) => _changeColor(SiliphColors.error),
      ),
      _ColorChip(
        color: SiliphColors.info,
        isSelected: _annotation.color == SiliphColors.info,
        onSelected: (_) => _changeColor(SiliphColors.info),
      ),
    ];
  }

  Widget _buildCanvas() {
    return GestureDetector(
      onPanStart: (details) {
        if (_phase == _AnnotationPhase.select) {
          _startSelection(details.localPosition);
        }
      },
      onPanUpdate: (details) {
        if (_phase == _AnnotationPhase.select) {
          _updateSelection(details.localPosition);
        }
      },
      onPanEnd: (_) {
        if (_phase == _AnnotationPhase.select) {
          _applyAnnotation();
        }
      },
      child: Stack(
        children: [
          // PDF page area
          const Center(
            child: Icon(
              Icons.picture_as_pdf_outlined,
              size: 100,
              color: SiliffColors.outline,
            ),
          ),
          // Selection rectangle
          if (_isSelecting)
            _SelectionRectangle(
              start: _selectionStart!,
              end: _selectionEnd!,
            ),
        ],
      ),
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

// Phase chip
class _PhaseChip extends StatelessWidget {
  final _AnnotationPhase phase;
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

// Type toggle button
class _TypeToggleButton extends StatelessWidget {
  final _AnnotationType type;
  final bool isActive;
  final VoidCallback onTap;

  const _TypeToggleButton({
    required this.type,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(_typeLabel(type)),
      selected: isActive,
      onSelected: (_) => onTap(),
      selectedColor: SiliphColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
    );
  }

  String _typeLabel(_AnnotationType type) {
    switch (type) {
      case _AnnotationType.highlight:
        return 'Highlight';
      case _AnnotationType.underline:
        return 'Underline';
      case _AnnotationType.strikethrough:
        return 'Strikethrough';
    }
  }
}

// Selection rectangle
class _SelectionRectangle extends StatelessWidget {
  final Offset start;
  final Offset end;

  const _SelectionRectangle({
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    final left = start.dx < end.dx ? start.dx : end.dx;
    final top = start.dy < end.dy ? start.dy : end.dy;
    final width = (end.dx - start.dx).abs();
    final height = (end.dy - start.dy).abs();

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: SiliphColors.primary.withValues(alpha: 0.3),
        border: Border.all(color: SiliphColors.primary, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Container(
          width: width,
          height: height,
          color: Colors.transparent,
        ),
      ),
    );
  }
}