/// Existing text editing screen (section 2).
///
/// Allows the user to tap existing PDF text and edit it. Shows UI states for:
/// text selected, text editing, text cursor, text box resizing, text moved, text deleted.
/// Includes text formatting controls: font, font size, bold, italic, underline,
/// text color, alignment, line spacing, character spacing.
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

enum _TextEditPhase { select, editing, cursor, resizing, moved, deleted }

/// Represents a region of selected text on a PDF page.
class _TextSelection {
  final Offset start;
  final Offset end;
  final String text;
  final Rect bounds;

  _TextSelection({
    required this.start,
    required this.end,
    required this.text,
    required this.bounds,
  });
}

/// Model for text formatting state.
class _TextFormatting {
  String fontFamily;
  double fontSize;
  FontWeight fontWeight;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  bool isStrikethrough;
  Color textColor;
  TextAlign alignment;
  double lineSpacing;
  double characterSpacing;

  _TextFormatting({
    this.fontFamily = 'Roboto',
    this.fontSize = 12.0,
    this.fontWeight = FontWeight.normal,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.textColor = SiliphColors.onSurface,
    this.alignment = TextAlign.left,
    this.lineSpacing = 1.2,
    this.characterSpacing = 0.0,
  });

  _TextFormatting copyWith({
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    bool? isStrikethrough,
    Color? textColor,
    TextAlign? alignment,
    double? lineSpacing,
    double? characterSpacing,
  }) {
    return _TextFormatting(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      isStrikethrough: isStrikethrough ?? this.isStrikethrough,
      textColor: textColor ?? this.textColor,
      alignment: alignment ?? this.alignment,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      characterSpacing: characterSpacing ?? this.characterSpacing,
    );
  }
}

/// State for the text editing screen.
class TextEditingScreen extends ConsumerStatefulWidget {
  const TextEditingScreen({
    super.key,
    required this.file,
    required this.pageNumber,
    required this.textRect,
    required this.initialText,
    required this.initialFormatting,
  });

  final FileItem file;
  final int pageNumber;
  final Rect textRect; // Position/size of the text region in normalized coords
  final String initialText;
  final _TextFormatting initialFormatting;

  @override
  ConsumerState<TextEditingScreen> createState() =>
      _TextEditingScreenState();
}

class _TextEditingScreenState extends ConsumerState<TextEditingScreen> {
  _TextEditPhase _phase = _TextEditPhase.select;
  String _currentText = '';
  _TextFormatting _formatting;
  bool _isDirty = false;
  String? _error;
  TextEditingController? _controller;
  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();
    _currentText = widget.initialText;
    _formatting = widget.initialFormatting;
    _controller = TextEditingController(text: _currentText);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  // Format text as a PDF text style string
  String _buildTextStyle() {
    final weight = _formatting.fontWeight == FontWeight.bold
        ? 'Bold'
        : _formatting.fontWeight == FontWeight.w600
            ? 'SemiBold'
            : 'Normal';
    final italic = _formatting.isItalic ? 'Italic' : '';
    final underline = _formatting.isUnderline ? 'Underline' : '';
    final strikethrough = _formatting.isStrikethrough ? 'Strikethrough' : '';

    return '$weight $italic $underline $strikethrough '
        'FontSize:${_formatting.fontSize}pt Color:${_formatting.textColor.value} '
        'Align:${_formatting.alignment.index} LineSpace:${_formatting.lineSpacing} '
        'CharSpace:${_formatting.characterSpacing}';
  }

  // Save the edited text back to PDF
  Future<void> _saveText() async {
    setState(() => _isDirty = true);
    setState(() => _phase = _TextEditPhase.select);

    // TODO: Call PDF engine to replace text
    // final handle = ref.read(pdfGatewayProvider).editText(
    //   input: widget.file,
    //   pageNumber: widget.pageNumber,
    //   rect: widget.textRect,
    //   text: _currentText,
    //   style: _buildTextStyle(),
    //   output: /* new output doc */,
    // );
    // await handle.done;

    if (!mounted) return;
    setState(() {
      _phase = _TextEditPhase.select;
      _isDirty = false;
    });
  }

  // Cancel editing and return to selection
  void _cancelEditing() {
    setState(() => _phase = _TextEditPhase.select);
  }

  // Apply bold
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

  // Apply italic
  void _toggleItalic() {
    setState(() {
      _formatting = _formatting.copyWith(
        isItalic: !_formatting.isItalic,
        fontWeight: _formatting.isItalic
            ? FontWeight.normal
            : FontWeight.w600,
      );
    });
  }

  // Apply underline
  void _toggleUnderline() {
    setState(() {
      _formatting = _formatting.copyWith(
        isUnderline: !_formatting.isUnderline,
      );
    });
  }

  // Apply strikethrough
  void _toggleStrikethrough() {
    setState(() {
      _formatting = _formatting.copyWith(
        isStrikethrough: !_formatting.isStrikethrough,
      );
    });
  }

  // Change font color
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

  // Font family selection
  void _changeFontFamily(String family) {
    setState(() {
      _formatting = _formatting.copyWith(fontFamily: family);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Text'),
        actions: [
          TextButton(onPressed: _cancelEditing, child: const Text('Cancel')),
          TextButton(onPressed: _saveText, child: const Text('Done')),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Phase-based UI
            _buildPhaseUI(),

            // Text display/editing area
            Expanded(
              child: Center(
                child: _buildTextEditingArea(),
              ),
            ),

            // Formatting toolbar
            _buildFormattingToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseUI() {
    return Switch(
      value: _phase == _TextEditPhase.editing,
      onChanged: (value) {
        setState(() {
          if (value) {
            _phase = _TextEditPhase.editing;
          } else {
            _phase = _TextEditPhase.select;
          }
        });
      },
      activeColor: SiliphColors.primary,
    );
  }

  Widget _buildTextEditingArea() {
    switch (_phase) {
      case _TextEditPhase.select:
        return _TextSelectionView(
          text: _currentText,
          bounds: widget.textRect,
          onTap: () => setState(() => _phase = _TextEditPhase.editing),
        );
      case _TextEditPhase.editing:
        return _TextEditingView(
          controller: _controller!,
          focusNode: _focusNode!,
          onChanged: (text) => setState(() => _currentText = text),
          onSubmit: _saveText,
        );
      case _TextEditPhase.cursor:
        return _CursorView(
          text: _currentText,
          formatting: _formatting,
          onToggleBold: _toggleBold,
          onToggleItalic: _toggleItalic,
          onToggleUnderline: _toggleUnderline,
          onToggleStrikethrough: _toggleStrikethrough,
        );
      case _TextEditPhase.resizing:
        return _ResizingView(
          formatting: _formatting,
          onFontSizeChanged: _changeFontSize,
          onAlignmentChanged: _changeAlignment,
        );
      case _TextEditPhase.moved:
        return _MovedView(
          formatting: _formatting,
          onComplete: _saveText,
        );
      case _TextEditPhase.deleted:
        return const _DeletedView();
    }
  }

  Widget _buildFormattingToolbar() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Font family
            _FormatChip(
              label: 'Font: ${_formatting.fontFamily}',
              onTap: () => _changeFontFamily(_selectFontFamily()),
              selected: true,
            ),
            const SizedBox(width: SiliphSpacing.sm),

            // Font size slider
            _FormatSlider(
              label: 'Size: ${_formatting.fontSize.toInt()}pt',
              min: 8,
              max: 72,
              value: _formatting.fontSize,
              onChanged: _changeFontSize,
            ),
            const SizedBox(width: SiliphSpacing.sm),

            // Bold button
            _ActionButton(
              icon: _formatting.isBold ? Icons.bold_outlined : Icons.bold_outlined,
              onTap: _toggleBold,
              label: 'Bold',
            ),
            const SizedBox(width: SiliphSpacing.sm),

            // Italic button
            _ActionButton(
              icon: _formatting.isItalic ? Icons.italic_outlined : Icons.italic_outlined,
              onTap: _toggleItalic,
              label: 'Italic',
            ),
            const SizedBox(width: SiliphSpacing.sm),

            // Underline button
            _ActionButton(
              icon: _formatting.isUnderline ? Icons.format_underlined_outlined : Icons.format_underlined_outlined,
              onTap: _toggleUnderline,
              label: 'Underline',
            ),
            const SizedBox(width: SiliphSpacing.sm),

            // Strikethrough button
            _ActionButton(
              icon: _formatting.isStrikethrough ? Icons.format_strikethrough_outlined : Icons.format_strikethrough_outlined,
              onTap: _toggleStrikethrough,
              label: 'Strike',
            ),
            const SizedBox(width: SiliphSpacing.sm),

            // Text color
            _ColorButton(
              color: _formatting.textColor,
              onSelected: _changeTextColor,
            ),
            const SizedBox(width: SiliphSpacing.sm),

            // Alignment
            _AlignmentChips(
              alignment: _formatting.alignment,
              onSelected: _changeAlignment,
            ),
            const SizedBox(width: SiliphSpacing.sm),

            // Line spacing
            _FormatSlider(
              label: 'Line: ${_formatting.lineSpacing.toStringAsFixed(1)}x',
              min: 1.0,
              max: 3.0,
              value: _formatting.lineSpacing,
              onChanged: (v) =>
                  setState(() => _formatting = _formatting.copyWith(lineSpacing: v)),
            ),
            const SizedBox(width: SiliphSpacing.sm),

            // Character spacing
            _FormatSlider(
              label: 'Char: ${_formatting.characterSpacing.toStringAsFixed(1)}',
              min: -1.0,
              max: 1.0,
              value: _formatting.characterSpacing,
              onChanged: (v) =>
                  setState(() => _formatting = _formatting.copyWith(characterSpacing: v)),
            ),
          ],
        ),
      ),
    );
  }

  String _selectFontFamily() {
    // In a real app, this would show a dropdown
    return 'Roboto';
  }
}

// Text selection view - shows the selected text with handles
class _TextSelectionView extends StatelessWidget {
  final String text;
  final Rect bounds;
  final VoidCallback onTap;

  const _TextSelectionView({
    required this.text,
    required this.bounds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: bounds.width,
        height: bounds.height,
        color: Colors.transparent,
        child: CustomPaint(
          painter: _TextSelectionPainter(text: text, bounds: bounds),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TextSelectionPainter extends CustomPainter {
  final String text;
  final Rect bounds;

  _TextSelectionPainter({required this.text, required this.bounds});

  @override
  void paint(Canvas canvas) {
    // Draw text background
    final bgPaint = Paint()
      ..color = SiliphColors.primary.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    canvas.drawRect(bounds, bgPaint);

    // Draw text
    final textPaint = Paint()
      ..color = SiliphColors.primary
      ..style = PaintingStyle.fill
      ..fontSize = 14;

    final textSpan = TextSpan(text: text, style: TextStyle(fontSize: 14));
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        bounds.left + 8,
        bounds.top + (bounds.height - textPainter.height) / 2,
      ),
    );

    // Draw selection handles
    final handlePaint = Paint()
      ..color = SiliphColors.primary
      ..style = PaintingStyle.fill;

    final handleSize = 8.0;
    // Four corners + middle handles
    final handles = <Offset>[
      Offset(bounds.left, bounds.top),
      Offset(bounds.right - handleSize, bounds.top),
      Offset(bounds.left, bounds.bottom - handleSize),
      Offset(bounds.right - handleSize, bounds.bottom - handleSize),
      Offset(bounds.left + (bounds.width - handleSize) / 2, bounds.top),
      Offset(bounds.left + (bounds.width - handleSize) / 2, bounds.bottom),
      Offset(bounds.left, bounds.top + (bounds.height - handleSize) / 2),
      Offset(bounds.right - handleSize, bounds.top + (bounds.height - handleSize) / 2),
    ];

    for (final handle in handles) {
      canvas.drawCircle(handle, handleSize / 2, handlePaint);
    }
  }

  @override
  bool shouldRepaint(_TextSelectionPainter oldDelegate) => true;
}

// Text editing view - shows the text field with cursor
class _TextEditingView extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onChanged;
  final VoidCallback onSubmit;

  const _TextEditingView({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        // Handle focus change
      },
      child: GestureDetector(
        onTapUp: (_) {
          // Dismiss keyboard on tap up outside
          FocusScope.of(context).unfocus();
        },
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(SiliphSpacing.md),
          decoration: BoxDecoration(
            color: SiliphColors.surface,
            borderRadius: BorderRadius.circular(SiliphRadii.md),
            border: Border.all(color: SiliphColors.outline),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
            decoration: const InputDecoration(
              hintText: 'Tap to edit text...',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(color: SiliphColors.onSurface),
          ),
        ),
      ),
    );
  }
}

// Cursor view with formatting options
class _CursorView extends StatelessWidget {
  final String text;
  final _TextFormatting formatting;
  final VoidCallback onToggleBold;
  final VoidCallback onToggleItalic;
  final VoidCallback onToggleUnderline;
  final VoidCallback onToggleStrikethrough;

  const _CursorView({
    required this.text,
    required this.formatting,
    required this.onToggleBold,
    required this.onToggleItalic,
    required this.onToggleUnderline,
    required this.onToggleStrikethrough,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(SiliphSpacing.md),
        decoration: BoxDecoration(
          color: SiliphColors.surface,
          borderRadius: BorderRadius.circular(SiliphRadii.md),
          border: Border.all(color: SiliphColors.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Text with cursor
            Text(
              text,
              style: TextStyle(
                fontFamily: formatting.fontFamily,
                fontSize: formatting.fontSize,
                fontWeight: formatting.fontWeight,
                color: formatting.textColor,
                decoration: formatting.isUnderline
                    ? TextDecoration.underline
                    : null,
                decorationColor: formatting.textColor,
              ),
            ),
            const SizedBox(height: SiliphSpacing.sm),

            // Quick formatting row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickActionButton(
                  icon: formatting.isBold ? Icons.bold : Icons.bold_outlined,
                  onTap: onToggleBold,
                  label: 'B',
                ),
                _QuickActionButton(
                  icon: formatting.isItalic ? Icons.italic : Icons.italic_outlined,
                  onTap: onToggleItalic,
                  label: 'I',
                ),
                _QuickActionButton(
                  icon: formatting.isUnderline ? Icons.format_underlined : Icons.format_underlined_outlined,
                  onTap: onToggleUnderline,
                  label: 'U',
                ),
                _QuickActionButton(
                  icon: formatting.isStrikethrough ? Icons.format_strikethrough : Icons.format_strikethrough_outlined,
                  onTap: onToggleStrikethrough,
                  label: 'S',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Resizing view
class _ResizingView extends StatelessWidget {
  final _TextFormatting formatting;
  final Function(double) onFontSizeChanged;
  final Function(TextAlign) onAlignmentChanged;

  const _ResizingView({
    required this.formatting,
    required this.onFontSizeChanged,
    required this.onAlignmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(SiliphSpacing.md),
        decoration: BoxDecoration(
          color: SiliphColors.surface,
          borderRadius: BorderRadius.circular(SiliphRadii.md),
          border: Border.all(color: SiliphColors.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Resize text panel',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.sm),
            _FormatSlider(
              label: 'Font size: ${formatting.fontSize.toInt()}pt',
              min: 8,
              max: 72,
              value: formatting.fontSize,
              onChanged: onFontSizeChanged,
            ),
            const SizedBox(height: SiliphSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Text('Left'),
                DropdownButton<TextAlign>(
                  value: formatting.alignment,
                  items: const [
                    DropdownMenuItem(value: TextAlign.left, child: Text('Left')),
                    DropdownMenuItem(value: TextAlign.center, child: Text('Center')),
                    DropdownMenuItem(value: TextAlign.right, child: Text('Right')),
                  ],
                  onChanged: onAlignmentChanged,
                ),
                const Text('Right'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Moved view
class _MovedView extends StatelessWidget {
  final _TextFormatting formatting;
  final VoidCallback onComplete;

  const _MovedView({
    required this.formatting,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(SiliphSpacing.md),
        decoration: BoxDecoration(
          color: SiliphColors.surface,
          borderRadius: BorderRadius.circular(SiliphRadii.md),
          border: Border.all(color: SiliphColors.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Text moved', style: TextStyle(fontSize: 18)),
            const SizedBox(height: SiliphSpacing.sm),
            _QuickActionButton(
              icon: Icons.check_circle_outlined,
              onTap: onComplete,
              label: 'Done',
            ),
            const SizedBox(height: SiliphSpacing.sm),
            _QuickActionButton(
              icon: Icons.cancel_outlined,
              onTap: () => _cancelEditing(),
              label: 'Cancel',
            ),
          ],
        ),
      ),
    );
  }
}

// Deleted view
class _DeletedView extends StatelessWidget {
  const _DeletedView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Text deleted'),
    );
  }
}

// Helper widgets

class _FormatChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool selected;

  const _FormatChip({
    required this.label,
    required this.onTap,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: SiliphColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
    );
  }
}

class _FormatSlider extends StatelessWidget {
  final String label;
  final double min;
  final double max;
  final double value;
  final Function(double) onChanged;

  const _FormatSlider({
    required this.label,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String label;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SiliphSpacing.sm,
          vertical: SiliphSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: SiliphColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(SiliphRadii.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: SiliphColors.primary),
            const SizedBox(height: SiliphSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onSelected;

  const _ColorButton({
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Show color picker
        onSelected(color);
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: SiliphColors.outline),
          borderRadius: BorderRadius.circular(SiliphRadii.sm),
        ),
      ),
    );
  }
}

class _AlignmentChips extends StatelessWidget {
  final TextAlign alignment;
  final ValueChanged<TextAlign> onSelected;

  const _AlignmentChips({
    required this.alignment,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SiliphSpacing.xs,
      children: [
        _AlignmentChip(
          alignment: TextAlign.left,
          isSelected: alignment == TextAlign.left,
          onTap: onSelected,
        ),
        _AlignmentChip(
          alignment: TextAlign.center,
          isSelected: alignment == TextAlign.center,
          onTap: onSelected,
        ),
        _AlignmentChip(
          alignment: TextAlign.right,
          isSelected: alignment == TextAlign.right,
          onTap: onSelected,
        ),
      ],
    );
  }
}

class _AlignmentChip extends StatelessWidget {
  final TextAlign alignment;
  final bool isSelected;
  final VoidCallback onTap;

  const _AlignmentChip({
    required this.alignment,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(alignment.toString().split('.').last),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: SiliphColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String label;

  const _QuickActionButton({
    required this.icon,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.sm),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: SiliphSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}