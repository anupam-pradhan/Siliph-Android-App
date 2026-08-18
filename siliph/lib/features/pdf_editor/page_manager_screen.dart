/// Page management screen (section 15).
///
/// Actions: add page, delete page, duplicate page, extract page,
/// rearrange pages, rotate page, move page, replace page.
/// Uses page thumbnails. Supports drag-and-drop page reordering.
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

enum _PagePhase { thumbnails, organizing, extracting, deleting, rotating }

/// Page model for thumbnail representation
class _PageModel {
  final int index; // one-based
  final String thumbnailData; // base64 or asset reference
  final bool isSelected;
  final bool isLocked;

  _PageModel({
    required this.index,
    required this.thumbnailData,
    this.isSelected = false,
    this.isLocked = false,
  });

  _PageModel copyWith({
    int? index,
    String? thumbnailData,
    bool? isSelected,
    bool? isLocked,
  }) {
    return _PageModel(
      index: index ?? this.index,
      thumbnailData: thumbnailData ?? this.thumbnailData,
      isSelected: isSelected ?? this.isSelected,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

/// Page management screen
class PageManagerScreen extends ConsumerStatefulWidget {
  const PageManagerScreen({
    super.key,
    required this.file,
  });

  final FileItem file;

  @override
  ConsumerState<PageManagerScreen> createState() => _PageManagerScreenState();
}

class _PageManagerScreenState extends ConsumerState<PageManagerScreen> {
  _PagePhase _phase = _PagePhase.thumbnails;
  int _pageCount = 0;
  List<_PageModel> _pages = [];
  bool _isMultiSelect = false;
  final Set<int> _selectedPages = {};
  _PageModel? _draggedPage;
  Offset? _dropPosition;
  String? _error;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _loadPageCount();
  }

  void _loadPageCount() async {
    try {
      final info = await ref.read(pdfGatewayProvider).inspect(widget.file);
      setState(() {
        _pageCount = info.pageCount;
        _pages = List.generate(_pageCount, (i) => _PageModel(
          index: i + 1,
          thumbnailData: 'thumbnail_$i',
        ));
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not load PDF pages.');
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Toggle page selection
  void _togglePageSelection(int pageIndex) {
    setState(() {
      if (_isMultiSelect) {
        // Toggle selection
        if (_selectedPages.contains(pageIndex)) {
          _selectedPages.remove(pageIndex);
        } else {
          _selectedPages.add(pageIndex);
        }
      } else {
        // Single select - deselect all others
        _selectedPages.clear();
        _selectedPages.add(pageIndex);
        _isMultiSelect = false;
      }
    });
  }

  // Start multi-select
  void _startMultiSelect() {
    setState(() {
      _isMultiSelect = true;
    });
  }

  // Cancel multi-select
  void _cancelMultiSelect() {
    setState(() {
      _isMultiSelect = false;
      _selectedPages.clear();
    });
  }

  // Delete selected pages
  Future<void> _deleteSelectedPages() async {
    if (_selectedPages.isEmpty) return;
    
    // Show confirmation
    if (!mounted) return;
    final shouldDelete = await _showDeleteConfirmation(_selectedPages.length);
    if (shouldDelete == null) return;
    
    if (shouldDelete) {
      setState(() {
        // Remove selected pages (in reverse order to maintain indices)
        final sortedPages = _selectedPages.toList()..sort((a, b) => b.compareTo(a));
        for (final index in sortedPages) {
          _pages.removeAt(index - 1); // -1 because _pages is 0-based but page numbers are 1-based
        }
        _selectedPages.clear();
        _isMultiSelect = false;
        _pageCount = _pages.length;
      });
    }
  }

  // Confirm delete dialog
  Future<bool?> _showDeleteConfirmation(int count) async {
    if (!mounted) return null;
    
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count pages?'),
        content: Text('Are you sure you want to permanently delete these pages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Duplicate page
  void _duplicatePage(int pageIndex) {
    setState(() {
      final insertIndex = pageIndex; // Insert after the selected page
      _pages.insert(insertIndex, _pages[pageIndex - 1].copyWith(
        index: insertIndex + 1,
      ));
      // Update all subsequent indices
      for (int i = insertIndex; i < _pages.length; i++) {
        _pages = _pages..[i] = _pages[i].copyWith(index: i + 1);
      }
    });
  }

  // Rotate page
  void _rotatePage(int pageIndex, {int degrees = 90}) {
    setState(() {
      // Rotate the page
      // TODO: Actual rotation implementation
    });
  }

  // Move page (reorder)
  void _movePage(int fromIndex, int toIndex) {
    setState(() {
      if (fromIndex == toIndex) return;
      
      final _PageModel moved = _pages[fromIndex];
      _pages.removeAt(fromIndex);
      _pages.insert(toIndex, moved);
      
      // Update indices
      for (int i = 0; i < _pages.length; i++) {
        _pages = _pages..[i] = _pages[i].copyWith(index: i + 1);
      }
    });
  }

  // Extract pages
  void _extractPages() {
    if (_selectedPages.isEmpty) return;
    
    setState(() => _phase = _PagePhase.extracting);
    
    // TODO: Extract pages
    // final extracted = await ref.read(pdfGatewayProvider).extractPages(
    //   input: widget.file,
    //   pageNumbers: _selectedPages.toList(),
    // );
    // 
    // if (mounted) {
    //   // Navigate to new PDF with extracted pages
    //   _phase = _PagePhase.thumbnails;
    //   _loadPageCount();
    // }
  }

  // Replace page
  void _replacePage(int pageIndex, FileItem newPage) {
    setState(() {
      _pages[pageIndex - 1] = _PageModel(
        index: pageIndex,
        thumbnailData: 'updated_${pageIndex}',
      );
    });
  }

  // Zoom in/out
  void _toggleZoom() {
    setState(() {
      _zoom = _zoom == 1.0 ? 1.5 : 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Organizer'),
        actions: [
          // Zoom toggle
          IconButton(
            icon: Icon(
              _zoom > 1.0 ? Icons.remove : Icons.add,
            ),
            tooltip: _zoom > 1.0 ? 'Zoom out' : 'Zoom in',
            onPressed: _toggleZoom,
          ),
          // Done button (when not in thumbnail view)
          if (_phase == _PagePhase.thumbnails)
            TextButton(
              onPressed: () {},
              child: const Text('Done'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Phase selector
            _buildPhaseSelector(),

            // Toolbar
            _buildToolbar(),

            // Page area
            Expanded(
              child: _buildPageArea(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseSelector() {
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Wrap(
        spacing: SiliphSpacing.xs,
        children: _PagePhase.values.map((_PagePhase phase) {
          return _PhaseChip(
            phase: phase,
            label: _pageLabel(phase),
            active: _phase == phase,
            onTap: () => setState(() => _phase = phase),
          );
        }).toList(),
      ),
    );
  }

  String _pageLabel(_PagePhase phase) {
    switch (phase) {
      case _PagePhase.thumbnails:
        return 'Thumbnails';
      case _PagePhase.organizing:
        return 'Organize';
      case _PagePhase.extracting:
        return 'Extract';
      case _PagePhase.deleting:
        return 'Delete';
      case _PagePhase.rotating:
        return 'Rotate';
    }
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Row(
        children: [
          // Add page
          Expanded(
            child: _ActionButton(
              icon: Icons.add_outlined,
              label: 'Add Page',
              onTap: () {
                // Show add page options
                _showAddPageOptions();
              },
            ),
          ),
          const SizedBox(width: SiliphSpacing.sm),

          // Delete (multi-select mode)
          if (_isMultiSelect) ...[
            Expanded(
              child: _ActionButton(
                icon: Icons.delete_outlined,
                label: 'Delete ${_selectedPages.length}',
                onTap: _deleteSelectedPages,
                isDestructive: true,
              ),
            ),
          ],
          if (!_isMultiSelect) ...[
            // Single select actions
            Expanded(
              child: _ActionButton(
                icon: Icons.delete_outlined,
                label: 'Delete',
                onTap: () => _showDeleteSingleConfirm(),
                isDestructive: true,
              ),
            ),
          ],
          const SizedBox(width: SiliphSpacing.sm),

          // Duplicate
          Expanded(
            child: _ActionButton(
              icon: Icons.copy_outlined,
              label: 'Duplicate',
              onTap: () => _duplicatePage(_selectedPages.isNotEmpty ? _selectedPages.first : 1),
            ),
          ),
          const SizedBox(width: SiliphSpacing.sm),

          // Rotate
          Expanded(
            child: _ActionButton(
              icon: Icons.rotate_right_outlined,
              label: 'Rotate',
              onTap: () => _rotatePage(_selectedPages.isNotEmpty ? _selectedPages.first : 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _showAddPageOptions() {
    // TODO: Show add page dialog
    return const SizedBox.shrink();
  }

  Widget _showDeleteSingleConfirm() {
    // TODO: Show confirmation dialog
    return const SizedBox.shrink();
  }

  Widget _buildPageArea() {
    if (_pageCount == 0) {
      return const Center(
        child: Text('No pages loaded'),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1 / 1.5,
      ),
      itemCount: _pages.length,
      itemBuilder: (context, index) {
        final page = _pages[index];
        return _PageThumbnail(
          page: page,
          onSelect: () => _togglePageSelection(page.index),
          isSelected: _selectedPages.contains(page.index),
          isMultiSelect: _isMultiSelect,
          onDragStart: () => _draggedPage = page,
          onDrop: () {
            _dropPosition = null;
            _draggedPage = null;
          },
        );
      },
    );
  }
}

// Phase chip
class _PhaseChip extends StatelessWidget {
  final _PagePhase phase;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PhaseChip({
    required this.phase,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
      selectedColor: SiliphColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
    );
  }
}

// Action button
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
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

// Page thumbnail widget
class _PageThumbnail extends ConsumerWidget {
  final _PageModel page;
  final VoidCallback onSelect;
  final bool isSelected;
  final bool isMultiSelect;
  final VoidCallback? onDragStart;
  final VoidCallback? onDrop;

  const _PageThumbnail({
    required this.page,
    required this.onSelect,
    required this.isSelected,
    required this.isMultiSelect,
    this.onDragStart,
    this.onDrop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = isSelected
        ? SiliphColors.primary
        : SiliphColors.surface;

    return GestureDetector(
      onTap: onSelect,
      onPanDown: (_) {
        if (isMultiSelect) {
          // Start multi-select drag
        }
      },
      onPanStart: (_) {
        onDragStart?.call();
      },
      onPanEnd: (_) {
        onDrop?.call();
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: isSelected ? SiliphColors.primary : SiliphColors.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(SiliphRadii.sm),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.pages_outlined,
                size: 32,
                color: SiliphColors.onSurface,
              ),
              const SizedBox(height: SiliphSpacing.xs),
              Text(
                '${page.index}',
                style: TextStyle(
                  color: isSelected ? SiliphColors.onPrimary : SiliphColors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}