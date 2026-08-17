import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';

/// Reusable Siliph Success Screen matching the visual reference standard.
class SiliphSuccessView extends StatelessWidget {
  const SiliphSuccessView({
    super.key,
    required this.source,
    required this.output,
    required this.onDone,
    this.title = 'All done!',
    this.subtitle = 'Your file has been processed successfully.',
    this.viewButtonLabel = 'View File',
    this.onView,
    this.onShare,
    this.onSaveToDevice,
    this.customDetails,
  });

  final FileItem source;
  final FileItem output;
  final VoidCallback onDone;
  final String title;
  final String subtitle;
  final String viewButtonLabel;
  final VoidCallback? onView;
  final VoidCallback? onShare;
  final VoidCallback? onSaveToDevice;
  final String? customDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final saved = source.sizeBytes > 0 &&
        output.sizeBytes > 0 &&
        source.sizeBytes > output.sizeBytes;
    final percent = saved
        ? (((source.sizeBytes - output.sizeBytes) / source.sizeBytes) * 100).round()
        : 0;

    final isPdf = output.displayName.toLowerCase().endsWith('.pdf');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: SiliphSpacing.lg,
          vertical: SiliphSpacing.md,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Confetti and celebration checkmark
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(120, 120),
                    painter: _ConfettiPainter(isDark: isDark),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1F9D55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SiliphSpacing.lg),

            // Headline and subtitle
            Text(
              title,
              style: theme.textTheme.headlineSmallStyle.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 26,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SiliphSpacing.xxs),
            Text(
              subtitle,
              style: theme.textTheme.bodyMediumStyle.copyWith(
                color: isDark ? const Color(0xFF9E9AA8) : SiliphColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SiliphSpacing.xl),

            // Result File Card matching reference
            Container(
              padding: const EdgeInsets.all(SiliphSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1C26) : const Color(0xFFF9F8FD),
                borderRadius: BorderRadius.circular(SiliphRadii.lg),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E2C3A) : SiliphColors.outline,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isPdf
                          ? const Color(0xFFE5484D).withValues(alpha: 0.12)
                          : const Color(0xFF3E9BFF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(SiliphRadii.md),
                    ),
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.image,
                      color: isPdf
                          ? const Color(0xFFE5484D)
                          : const Color(0xFF3E9BFF),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: SiliphSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          output.displayName,
                          style: theme.textTheme.titleSmallStyle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              customDetails ??
                                  (output.formattedSize.isEmpty
                                      ? 'Completed'
                                      : output.formattedSize),
                              style: theme.textTheme.bodySmallStyle.copyWith(
                                color: isDark
                                    ? const Color(0xFF9E9AA8)
                                    : SiliphColors.onSurfaceVariant,
                              ),
                            ),
                            if (saved) ...[
                              const SizedBox(width: SiliphSpacing.sm),
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
                                  '$percent% smaller',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F9D55),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SiliphSpacing.xxl),

            // Action Buttons
            if (onView != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onView,
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF8C70FF)
                        : SiliphColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SiliphRadii.md),
                    ),
                  ),
                  child: Text(
                    viewButtonLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SiliphSpacing.sm),
            ],

            if (onShare != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onShare,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SiliphRadii.md),
                    ),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF4A4658) : SiliphColors.outline,
                    ),
                  ),
                  child: const Text('Share'),
                ),
              ),
              const SizedBox(height: SiliphSpacing.sm),
            ],

            if (onSaveToDevice != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSaveToDevice,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SiliphRadii.md),
                    ),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF4A4658) : SiliphColors.outline,
                    ),
                  ),
                  child: const Text('Save to Device'),
                ),
              ),
              const SizedBox(height: SiliphSpacing.sm),
            ],

            TextButton(
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for festive confetti dots around the success badge.
class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFF1F9D55),
      const Color(0xFF5B3FE4),
      const Color(0xFFF76B15),
      const Color(0xFF3E9BFF),
      const Color(0xFFDB61B2),
      const Color(0xFFE5484D),
    ];

    final center = Offset(size.width / 2, size.height / 2);
    final count = 12;
    final radius = size.width * 0.44;

    for (var i = 0; i < count; i++) {
      final angle = (i * (2 * math.pi / count)) + 0.2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      final dotRadius = (i % 3 == 0) ? 3.5 : 2.5;
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
