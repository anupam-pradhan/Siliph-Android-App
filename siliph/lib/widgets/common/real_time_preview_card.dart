import 'package:flutter/material.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';

/// Real-time metrics card showing Original -> Estimated size with percentage badge.
class RealTimeMetricsCard extends StatelessWidget {
  const RealTimeMetricsCard({
    super.key,
    required this.originalSizeFormatted,
    required this.estimatedSizeFormatted,
    required this.percentSaved,
    this.estimatedQuality = 'Good',
    this.qualityDescription = 'Balanced quality and file size',
    this.showQualityFooter = true,
  });

  final String originalSizeFormatted;
  final String estimatedSizeFormatted;
  final int percentSaved;
  final String estimatedQuality;
  final String qualityDescription;
  final bool showQualityFooter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1C26) : const Color(0xFFF9F8FD),
        borderRadius: BorderRadius.circular(SiliphRadii.lg),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2C3A) : SiliphColors.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Original size
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original',
                      style: theme.textTheme.bodySmallStyle.copyWith(
                        color: isDark
                            ? const Color(0xFF9E9AA8)
                            : SiliphColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      originalSizeFormatted,
                      style: theme.textTheme.titleMediumStyle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SiliphSpacing.sm),
                child: Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: isDark ? const Color(0xFF757082) : const Color(0xFFA6A2B3),
                ),
              ),

              // Estimated size & percentage badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated',
                      style: theme.textTheme.bodySmallStyle.copyWith(
                        color: isDark
                            ? const Color(0xFF9E9AA8)
                            : SiliphColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          estimatedSizeFormatted,
                          style: theme.textTheme.titleMediumStyle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : SiliphColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F9D55).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$percentSaved% smaller',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F9D55),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (showQualityFooter) ...[
            const SizedBox(height: SiliphSpacing.md),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF2E2C3A) : SiliphColors.outline,
            ),
            const SizedBox(height: SiliphSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated Quality',
                        style: theme.textTheme.bodySmallStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : SiliphColors.onSurface,
                        ),
                      ),
                      Text(
                        qualityDescription,
                        style: theme.textTheme.bodySmallStyle.copyWith(
                          color: isDark
                              ? const Color(0xFF9E9AA8)
                              : SiliphColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F9D55).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    estimatedQuality,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F9D55),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Visual PDF page mockup comparison (Original vs Estimated).
class PdfDocumentComparisonPreview extends StatelessWidget {
  const PdfDocumentComparisonPreview({
    super.key,
    required this.originalSize,
    required this.estimatedSize,
    required this.percentSaved,
  });

  final String originalSize;
  final String estimatedSize;
  final int percentSaved;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Original page mockup
        Expanded(
          child: Container(
            height: 70,
            padding: const EdgeInsets.all(SiliphSpacing.xs),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1C26) : const Color(0xFFF9F8FD),
              borderRadius: BorderRadius.circular(SiliphRadii.sm),
              border: Border.all(
                color: isDark ? const Color(0xFF2E2C3A) : SiliphColors.outline,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF383548) : const Color(0xFFDDD8EC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2C3A) : const Color(0xFFE8E5F2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                Text(
                  'Original: $originalSize',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF9E9AA8) : SiliphColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: SiliphSpacing.sm),

        // Estimated page mockup
        Expanded(
          child: Container(
            height: 70,
            padding: const EdgeInsets.all(SiliphSpacing.xs),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1C26) : const Color(0xFFF9F8FD),
              borderRadius: BorderRadius.circular(SiliphRadii.sm),
              border: Border.all(
                color: isDark ? const Color(0xFF3E3A52) : const Color(0xFFD6D0F2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF8C70FF).withValues(alpha: 0.3) : const Color(0xFF5B3FE4).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF8C70FF).withValues(alpha: 0.2) : const Color(0xFF5B3FE4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      estimatedSize,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$percentSaved% smaller',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F9D55),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
