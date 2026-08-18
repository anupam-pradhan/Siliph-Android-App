/// Multi-page scan review screen.
///
/// Shows page thumbnails, large preview, and controls for adding,
/// reordering, deleting, and editing pages before export.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import 'scan_camera_screen.dart';
import 'scan_enhance_screen.dart';
import 'scan_mode.dart';
import 'scan_save_screen.dart';
import 'scanner_provider.dart';
import 'scanner_state.dart';

class ScanReviewScreen extends ConsumerStatefulWidget {
  const ScanReviewScreen({super.key, required this.mode});

  final ScanMode mode;

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  int _selectedIndex = 0;
  late List<ScannedPage> _pages;

  @override
  void initState() {
    super.initState();
    _pages = ref.read(scannerProvider(widget.mode)).pages;
  }

  void _refreshPages() {
    setState(() {
      _pages = ref.read(scannerProvider(widget.mode)).pages;
      if (_selectedIndex >= _pages.length) {
        _selectedIndex = (_pages.length - 1).clamp(0, _pages.length);
      }
    });
  }

  void _deletePage(int index) {
    if (index < 0 || index >= _pages.length) return;
    final notifier = ref.read(scannerProvider(widget.mode).notifier);
    notifier.removePage(index);
    _refreshPages();
  }

  void _reorderPages(int oldIndex, int newIndex) {
    final notifier = ref.read(scannerProvider(widget.mode).notifier);
    notifier.reorderPage(oldIndex, newIndex);
    _refreshPages();
  }

  void _editPage(int index) {
    if (index < 0 || index >= _pages.length) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanEnhanceScreen(
          mode: widget.mode,
          pageId: _pages[index].id,
        ),
      ),
    ).then((_) => _refreshPages());
  }

  void _addPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanCameraScreen(mode: widget.mode),
      ),
    ).then((_) => _refreshPages());
  }

  void _proceedToSave() {
    if (_pages.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanSaveScreen(mode: widget.mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerProvider(widget.mode));
    _pages = state.pages;

    return Scaffold(
      appBar: AppBar(
        title: Text('Review Scan (${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Page',
            onPressed: _addPage,
          ),
        ],
      ),
      body: _pages.isEmpty
          ? _buildEmptyView()
          : Column(
              children: [
                // Large preview
                Expanded(
                  child: _buildPreview(_pages[_selectedIndex]),
                ),

                // Page actions bar
                _buildActionBar(),

                // Thumbnail strip
                _buildThumbnailStrip(),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.document_scanner_outlined,
              size: 64, color: SiliphColors.outline),
          const SizedBox(height: SiliphSpacing.md),
          Text('No pages scanned yet',
              style: Theme.of(context).textTheme.titleMediumStyle),
          const SizedBox(height: SiliphSpacing.sm),
          FilledButton.icon(
            onPressed: _addPage,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Scan First Page'),
            style: FilledButton.styleFrom(
              backgroundColor: SiliphColors.categoryScanner,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ScannedPage page) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (page.originalUri.startsWith('/') ||
              page.originalUri.startsWith('file://'))
            Image.file(
              File(page.originalUri.startsWith('file://')
                  ? page.originalUri.substring(7)
                  : page.originalUri),
              fit: BoxFit.contain,
            )
          else
            const Center(
              child: Icon(Icons.image_outlined,
                  size: 64, color: SiliphColors.outline),
            ),
          // Page number badge
          Positioned(
            top: SiliphSpacing.sm,
            left: SiliphSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: SiliphSpacing.sm, vertical: SiliphSpacing.xxs),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(SiliphRadii.full),
              ),
              child: Text(
                '${_selectedIndex + 1} / ${_pages.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          // Filter badge
          if (page.filter != ScanFilter.original)
            Positioned(
              top: SiliphSpacing.sm,
              right: SiliphSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: SiliphSpacing.sm, vertical: SiliphSpacing.xxs),
                decoration: BoxDecoration(
                  color: SiliphColors.categoryScanner,
                  borderRadius: BorderRadius.circular(SiliphRadii.full),
                ),
                child: Text(
                  page.filter.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SiliphSpacing.md,
        vertical: SiliphSpacing.xs,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: SiliphColors.divider),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.edit_outlined,
            label: 'Edit',
            onTap: () => _editPage(_selectedIndex),
          ),
          _ActionButton(
            icon: Icons.rotate_right_outlined,
            label: 'Rotate',
            onTap: () {
              final notifier =
                  ref.read(scannerProvider(widget.mode).notifier);
              final page = _pages[_selectedIndex];
              notifier.updatePage(
                _selectedIndex,
                page.copyWith(rotation: (page.rotation + 90) % 360),
              );
              _refreshPages();
            },
          ),
          _ActionButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            onTap: () => _deletePage(_selectedIndex),
            isDestructive: true,
          ),
          if (_selectedIndex > 0)
            _ActionButton(
              icon: Icons.arrow_back_ios,
              label: 'Move',
              onTap: () {
                _reorderPages(_selectedIndex, _selectedIndex - 1);
                setState(() => _selectedIndex--);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnailStrip() {
    return SizedBox(
      height: 90,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: SiliphSpacing.sm, vertical: SiliphSpacing.xs),
        itemCount: _pages.length,
        onReorder: _reorderPages,
        itemBuilder: (context, index) {
          final page = _pages[index];
          final isSelected = index == _selectedIndex;
          return GestureDetector(
            key: ValueKey(page.id),
            onTap: () => setState(() => _selectedIndex = index),
            child: Container(
              width: 60,
              height: 76,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SiliphRadii.sm),
                border: Border.all(
                  color: isSelected
                      ? SiliphColors.categoryScanner
                      : SiliphColors.outline,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular((SiliphRadii.sm - 1).toDouble()),
                    child: SizedBox.expand(
                      child: ColoredBox(color: SiliphColors.surfaceVariant),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.md),
        child: FilledButton.icon(
          onPressed: _pages.isEmpty ? null : _proceedToSave,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(
            _pages.length == 1
                ? 'Save Scan'
                : 'Save ${_pages.length} Pages as PDF',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: SiliphColors.categoryScanner,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.md),
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? SiliphColors.error : SiliphColors.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
