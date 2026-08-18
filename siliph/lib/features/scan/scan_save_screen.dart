/// Save / export options screen.
///
/// Configure output format, quality, page size, and file name before saving.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import 'scan_mode.dart';
import 'scan_processing_screen.dart';
import 'scanner_provider.dart';
import 'scanner_state.dart';
import 'scan_widgets.dart';

class ScanSaveScreen extends ConsumerStatefulWidget {
  const ScanSaveScreen({super.key, required this.mode});

  final ScanMode mode;

  @override
  ConsumerState<ScanSaveScreen> createState() => _ScanSaveScreenState();
}

class _ScanSaveScreenState extends ConsumerState<ScanSaveScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(scannerProvider(widget.mode));
    _nameController = TextEditingController(text: state.effectiveFileName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final notifier = ref.read(scannerProvider(widget.mode).notifier);
    notifier.setFileName(_nameController.text);
    notifier.setPhase(ScanPhase.saving);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ScanProcessingScreen(mode: widget.mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerProvider(widget.mode));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Save Scan')),
      body: ListView(
        padding: const EdgeInsets.all(SiliphSpacing.md),
        children: [
          // Summary card
          GlassInfoCard(
            child: Row(
              children: [
                Icon(widget.mode.icon,
                    color: SiliphColors.categoryScanner, size: 32),
                const SizedBox(width: SiliphSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${state.pageCount} ${state.pageCount == 1 ? 'page' : 'pages'}',
                        style: Theme.of(context).textTheme.titleMediumStyle,
                      ),
                      Text(
                        widget.mode.title,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SiliphSpacing.lg),

          // File name
          Text('File Name',
              style: Theme.of(context).textTheme.titleSmallStyle),
          const SizedBox(height: SiliphSpacing.xs),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Scan name',
              suffixText: '.${state.outputFormat.extension}',
            ),
          ),
          const SizedBox(height: SiliphSpacing.lg),

          // Output format
          Text('Format',
              style: Theme.of(context).textTheme.titleSmallStyle),
          const SizedBox(height: SiliphSpacing.xs),
          _buildFormatSelector(state, isDark),
          const SizedBox(height: SiliphSpacing.lg),

          // Quality
          Text('Quality',
              style: Theme.of(context).textTheme.titleSmallStyle),
          const SizedBox(height: SiliphSpacing.xs),
          _buildQualitySelector(state, isDark),
          const SizedBox(height: SiliphSpacing.lg),

          // Page size (PDF only)
          if (state.outputFormat == ScanOutputFormat.pdf) ...[
            Text('Page Size',
                style: Theme.of(context).textTheme.titleSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            _buildPageSizeSelector(state, isDark),
            const SizedBox(height: SiliphSpacing.lg),
          ],

          // Estimated file size
          GlassInfoCard(
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: SiliphColors.onSurfaceVariant, size: 20),
                const SizedBox(width: SiliphSpacing.sm),
                Expanded(
                  child: Text(
                    _estimateSize(state),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SiliphSpacing.xl),

          // Save button
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Scan'),
            style: FilledButton.styleFrom(
              backgroundColor: SiliphColors.categoryScanner,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.md),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector(ScannerState state, bool isDark) {
    return Row(
      children: ScanOutputFormat.values.map((format) {
        final isSelected = format == state.outputFormat;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => ref
                  .read(scannerProvider(widget.mode).notifier)
                  .setOutputFormat(format),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? SiliphColors.categoryScanner.withValues(alpha: 0.15)
                      : (isDark
                          ? const Color(0xFF1E1C26)
                          : const Color(0xFFF9F8FD)),
                  borderRadius: BorderRadius.circular(SiliphRadii.md),
                  border: Border.all(
                    color: isSelected
                        ? SiliphColors.categoryScanner
                        : (isDark
                            ? const Color(0xFF2E2C3A)
                            : SiliphColors.outline),
                  ),
                ),
                child: Center(
                  child: Text(
                    format.label,
                    style: TextStyle(
                      color: isSelected
                          ? SiliphColors.categoryScanner
                          : SiliphColors.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQualitySelector(ScannerState state, bool isDark) {
    return Row(
      children: ScanQuality.values.map((quality) {
        final isSelected = quality == state.quality;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => ref
                  .read(scannerProvider(widget.mode).notifier)
                  .setQuality(quality),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? SiliphColors.categoryScanner.withValues(alpha: 0.15)
                      : (isDark
                          ? const Color(0xFF1E1C26)
                          : const Color(0xFFF9F8FD)),
                  borderRadius: BorderRadius.circular(SiliphRadii.md),
                  border: Border.all(
                    color: isSelected
                        ? SiliphColors.categoryScanner
                        : (isDark
                            ? const Color(0xFF2E2C3A)
                            : SiliphColors.outline),
                  ),
                ),
                child: Center(
                  child: Text(
                    quality.label,
                    style: TextStyle(
                      color: isSelected
                          ? SiliphColors.categoryScanner
                          : SiliphColors.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPageSizeSelector(ScannerState state, bool isDark) {
    return Row(
      children: PageSizeOption.values.map((size) {
        final isSelected = size == state.pageSize;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => ref
                  .read(scannerProvider(widget.mode).notifier)
                  .setPageSize(size),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? SiliphColors.categoryScanner.withValues(alpha: 0.15)
                      : (isDark
                          ? const Color(0xFF1E1C26)
                          : const Color(0xFFF9F8FD)),
                  borderRadius: BorderRadius.circular(SiliphRadii.md),
                  border: Border.all(
                    color: isSelected
                        ? SiliphColors.categoryScanner
                        : (isDark
                            ? const Color(0xFF2E2C3A)
                            : SiliphColors.outline),
                  ),
                ),
                child: Center(
                  child: Text(
                    size.label,
                    style: TextStyle(
                      color: isSelected
                          ? SiliphColors.categoryScanner
                          : SiliphColors.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _estimateSize(ScannerState state) {
    final baseSize = state.outputFormat == ScanOutputFormat.pdf ? 200 : 800;
    final multiplier = switch (state.quality) {
      ScanQuality.high => 1.0,
      ScanQuality.medium => 0.6,
      ScanQuality.small => 0.3,
    };
    final estimated = (baseSize * multiplier * state.pageCount).round();
    return 'Estimated size: ~${estimated}KB';
  }
}
