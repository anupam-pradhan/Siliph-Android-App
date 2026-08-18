/// Enhancement / filter screen.
///
/// After perspective correction, shows filter options and rotation controls.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import 'scan_mode.dart';
import 'scan_review_screen.dart';
import 'scanner_provider.dart';
import 'scanner_state.dart';
import 'scan_widgets.dart';

class ScanEnhanceScreen extends ConsumerStatefulWidget {
  const ScanEnhanceScreen({
    super.key,
    required this.mode,
    required this.pageId,
  });

  final ScanMode mode;
  final String pageId;

  @override
  ConsumerState<ScanEnhanceScreen> createState() => _ScanEnhanceScreenState();
}

class _ScanEnhanceScreenState extends ConsumerState<ScanEnhanceScreen> {
  ScanFilter _selectedFilter = ScanFilter.document;
  int _rotation = 0;
  double _brightness = 0;
  double _contrast = 0;
  bool _showAdjustments = false;

  void _applyFilter(ScanFilter filter) {
    setState(() => _selectedFilter = filter);
  }

  void _rotateClockwise() {
    setState(() => _rotation = (_rotation + 90) % 360);
  }

  void _rotateCounterClockwise() {
    setState(() => _rotation = (_rotation - 90 + 360) % 360);
  }

  void _confirm() {
    final notifier = ref.read(scannerProvider(widget.mode).notifier);
    final state = ref.read(scannerProvider(widget.mode));
    final pageIndex = state.pages.indexWhere((p) => p.id == widget.pageId);
    if (pageIndex < 0) return;

    final page = state.pages[pageIndex].copyWith(
      filter: _selectedFilter,
      rotation: _rotation,
    );
    notifier.updatePage(pageIndex, page);

    // For single-page scan (ID card), check if we need the back side
    if (state.isIdCardMode && state.idCardSide == IdCardSide.front && state.pageCount == 1) {
      notifier.advanceIdCardSide();
      notifier.goToCapture();
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    // Go to review
    notifier.goToReview();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ScanReviewScreen(mode: widget.mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerProvider(widget.mode));
    final page = state.pages.where((p) => p.id == widget.pageId).firstOrNull;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Enhance Scan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Adjustments',
            onPressed: () =>
                setState(() => _showAdjustments = !_showAdjustments),
          ),
        ],
      ),
      body: Column(
        children: [
          // Image preview
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (page != null)
                  Transform.rotate(
                    angle: _rotation * 3.14159265 / 180,
                    child: _buildImagePreview(page.originalUri),
                  ),
                // Filter label
                Positioned(
                  top: SiliphSpacing.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SiliphSpacing.md,
                      vertical: SiliphSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(SiliphRadii.full),
                    ),
                    child: Text(
                      _selectedFilter.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Adjustment sliders (toggled)
          if (_showAdjustments)
            Container(
              padding: const EdgeInsets.all(SiliphSpacing.md),
              color: Colors.black,
              child: Column(
                children: [
                  _buildSlider('Brightness', _brightness, (v) {
                    setState(() => _brightness = v);
                  }),
                  const SizedBox(height: SiliphSpacing.xs),
                  _buildSlider('Contrast', _contrast, (v) {
                    setState(() => _contrast = v);
                  }),
                ],
              ),
            ),

          // Rotation controls
          Container(
            padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.xs),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.rotate_left, color: Colors.white),
                  onPressed: _rotateCounterClockwise,
                  tooltip: 'Rotate Left',
                ),
                const SizedBox(width: SiliphSpacing.xl),
                Text(
                  '$_rotation°',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: SiliphSpacing.xl),
                IconButton(
                  icon: const Icon(Icons.rotate_right, color: Colors.white),
                  onPressed: _rotateClockwise,
                  tooltip: 'Rotate Right',
                ),
              ],
            ),
          ),

          // Filter chips
          Container(
            height: 64,
            color: Colors.black,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: SiliphSpacing.md),
              itemCount: ScanFilter.values.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: SiliphSpacing.xs),
              itemBuilder: (context, index) {
                final filter = ScanFilter.values[index];
                final isSelected = filter == _selectedFilter;
                return GestureDetector(
                  onTap: () => _applyFilter(filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: SiliphSpacing.sm,
                      vertical: SiliphSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? SiliphColors.categoryScanner
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(SiliphRadii.full),
                    ),
                    child: Center(
                      child: Text(
                        filter.label,
                        style: TextStyle(
                          color:
                              isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Confirm button
          Container(
            padding: const EdgeInsets.all(SiliphSpacing.md),
            decoration: const BoxDecoration(color: Colors.black),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(
                          vertical: SiliphSpacing.md),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: SiliphSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: SiliphColors.categoryScanner,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: SiliphSpacing.md),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
      String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: -1,
            max: 1,
            activeColor: SiliphColors.categoryScanner,
            inactiveColor: Colors.white24,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(String uri) {
    if (uri.startsWith('/') || uri.startsWith('file://')) {
      final path = uri.startsWith('file://') ? uri.substring(7) : uri;
      return Image.file(
        File(path),
        fit: BoxFit.contain,
      );
    }
    return const Center(
      child: Icon(Icons.image_outlined, size: 64, color: SiliphColors.outline),
    );
  }
}
