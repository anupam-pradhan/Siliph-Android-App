/// Link editor (section 11).
///
/// Allow: add link, select existing link, edit link, delete link.
/// Link types: website URL, email, page inside PDF.
/// URL input interface and link preview state.
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

enum _LinkType { website, email, page }
enum _LinkPhase { adding, editing, selected }

/// Link model
class _LinkModel {
  final _LinkType type;
  final String url;
  final String displayText;
  final Rect bounds;
  bool isSelected;

  _LinkModel({
    required this.type,
    this.url = '',
    this.displayText = '',
    required this.bounds,
    this.isSelected = false,
  });

  _LinkModel copyWith({
    _LinkType? type,
    String? url,
    String? displayText,
    Rect? bounds,
    bool? isSelected,
  }) {
    return _LinkModel(
      type: type ?? this.type,
      url: url ?? this.url,
      displayText: displayText ?? this.displayText,
      bounds: bounds ?? this.bounds,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Link editor screen
class LinkEditorScreen extends ConsumerStatefulWidget {
  const LinkEditorScreen({
    super.key,
    required this.file,
    required this.pageNumber,
  });

  final FileItem file;
  final int pageNumber;

  @override
  ConsumerState<LinkEditorScreen> createState() => _LinkEditorScreenState;
}

class _LinkEditorScreenState extends ConsumerState<LinkEditorScreen> {
  _LinkPhase _phase = _LinkPhase.adding;
  _LinkType _linkType = _LinkType.website;
  _LinkModel _link = _LinkModel(
    type: _LinkType.website,
    bounds: const Rect.fromLTRB(0, 0, 100, 30),
  );
  bool _isDirty = false;
  String? _error;
  TextEditingController? _urlController;
  TextEditingController? _displayTextController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _displayTextController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController?.dispose();
    _displayTextController?.dispose();
    super.dispose();
  }

  // Set link type
  void _setLinkType(_LinkType type) {
    setState(() {
      _linkType = type;
      _link = _link.copyWith(type: type);
    });
  }

  // Update URL
  void _updateUrl(String url) {
    setState(() {
      _link = _link.copyWith(url: url);
    });
  }

  // Update display text
  void _updateDisplayText(String text) {
    setState(() {
      _link = _link.copyWith(displayText: text);
    });
  }

  // Apply link
  void _applyLink() {
    setState(() => _phase = _LinkPhase.selected);
    // TODO: Apply link to PDF
    // final handle = ref.read(pdfGatewayProvider).addLink(
    //   input: widget.file,
    //   pageNumber: widget.pageNumber,
    //   link: _link,
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
    setState(() => _phase = _LinkPhase.adding);
    _urlController?.clear();
    _displayTextController?.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link'),
        actions: [
          TextButton(onPressed: _cancel, child: const Text('Cancel')),
          TextButton(onPressed: _applyLink, child: const Text('Done')),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Phase indicator
            _buildPhaseIndicator(),

            // Link type selector
            _buildLinkTypeSelector(),

            // URL/input field
            _buildInputField(),

            // Canvas preview
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
            phase: _LinkPhase.adding,
            label: 'Add',
            active: _phase == _LinkPhase.adding,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _LinkPhase.editing,
            label: 'Edit',
            active: _phase == _LinkPhase.editing,
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _LinkPhase.selected,
            label: 'Selected',
            active: _phase == _LinkPhase.selected,
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Wrap(
        spacing: SiliphSpacing.xs,
        children: _LinkType.values.map((_LinkType type) {
          return _LinkTypeChip(
            linkType: type,
            isSelected: _linkType == type,
            onSelected: _setLinkType,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_linkType == _LinkType.website)...[
            const Text('URL:', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _urlController,
              onChanged: _updateUrl,
              decoration: const InputDecoration(
                hintText: 'https://www.example.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: SiliphSpacing.md),
          ],
          if (_linkType == _LinkType.email)...[
            const Text('Email:', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _urlController,
              onChanged: _updateUrl,
              decoration: const InputDecoration(
                hintText: 'example@example.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: SiliphSpacing.md),
          ],
          if (_linkType == _LinkType.page)...[
            const Text('Page:', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<int>(
              value: 1,
              items: List.generate(10, (index) => DropdownMenuItem(
                value: index + 1,
                child: Text('Page ${index + 1}'),
              )),
              onChanged: (value) {},
            ),
            const SizedBox(height: SiliphSpacing.md),
          ],
          // Display text (always shown)
          const Text('Display text:', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
            controller: _displayTextController,
            onChanged: _updateDisplayText,
            decoration: const InputDecoration(
              hintText: 'Click here',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return GestureDetector(
      onPanStart: (details) {
        if (_phase == _LinkPhase.adding || _phase == _LinkPhase.editing) {
          // Start selection at tap point
          setState(() {});
        }
      },
      onPanUpdate: (details) {
        // Update selection rectangle
      },
      onPanEnd: (_) {
        if (_phase == _LinkPhase.adding) {
          _applyLink();
        }
      },
      child: Stack(
        children: [
          // PDF page area
          const Center(
            child: Icon(
              Icons.picture_as_pdf_outlined,
              size: 100,
              color: SiliphColors.outline,
            ),
          ),
          // Link rectangle preview
          if (_phase == _LinkPhase.adding || _phase == _LinkPhase.editing)
            _LinkRectanglePreview(
              bounds: _link.bounds,
              type: _linkType,
            ),
        ],
      ),
    );
  }
}

// Link type chip
class _LinkTypeChip extends StatelessWidget {
  final _LinkType linkType;
  final bool isSelected;
  final VoidCallback onSelected;

  const _LinkTypeChip({
    required this.linkType,
    required this.isSelected,
    required this.onSelected,
  });

  String _getLabel(_LinkType type) {
    switch (type) {
      case _LinkType.website:
        return 'Website';
      case _LinkType.email:
        return 'Email';
      case _LinkType.page:
        return 'Page';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(_getLabel(linkType)),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: SiliphColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
    );
  }
}

// Phase chip
class _PhaseChip extends StatelessWidget {
  final _LinkPhase phase;
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

// Link rectangle preview
class _LinkRectanglePreview extends StatelessWidget {
  final Rect bounds;
  final _LinkType type;

  const _LinkRectanglePreview({
    required this.bounds,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      _LinkType.website => SiliphColors.primary,
      _LinkType.email => SiliphColors.info,
      _LinkType.page => SiliphColors.tertiary,
    };

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Container(
          width: bounds.width.isFinite ? bounds.width : 100,
          height: bounds.height.isFinite ? bounds.height : 30,
          color: Colors.transparent,
        ),
      ),
    );
  }
}