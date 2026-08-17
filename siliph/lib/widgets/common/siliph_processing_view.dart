import 'package:flutter/material.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';

/// Reusable Siliph Processing Screen matching the visual reference standard.
class SiliphProcessingView extends StatelessWidget {
  const SiliphProcessingView({
    super.key,
    required this.title,
    required this.progress,
    this.subtitle = "Please don't close the app",
    this.onCancel,
    this.customSteps,
  });

  final String title;
  final double progress;
  final String subtitle;
  final VoidCallback? onCancel;
  final List<String>? customSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final percent = (progress * 100).clamp(0, 100).toInt();

    final defaultSteps = const [
      'Preparing file',
      'Analyzing content',
      'Compressing',
      'Optimizing',
      'Finalizing',
    ];
    final steps = customSteps ?? defaultSteps;

    // Calculate current active step index based on progress
    final stepIndex = (progress * (steps.length)).floor().clamp(0, steps.length - 1);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: SiliphSpacing.xl,
          vertical: SiliphSpacing.lg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular progress indicator with percentage
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      backgroundColor: isDark
                          ? const Color(0xFF2A2838)
                          : const Color(0xFFEAE7F8),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: theme.textTheme.headlineMediumStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 32,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SiliphSpacing.xl),

            // Operation title & guidance
            Text(
              title,
              style: theme.textTheme.titleLargeStyle.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              subtitle,
              style: theme.textTheme.bodyMediumStyle.copyWith(
                color: isDark ? const Color(0xFF9E9AA8) : SiliphColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SiliphSpacing.xxl),

            // Step-by-step checklist
            Container(
              padding: const EdgeInsets.all(SiliphSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1C26) : const Color(0xFFF9F8FD),
                borderRadius: BorderRadius.circular(SiliphRadii.lg),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E2C3A) : SiliphColors.outline,
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    _buildStepRow(
                      context,
                      stepName: steps[i],
                      isDone: i < stepIndex || progress >= 1.0,
                      isActive: i == stepIndex && progress < 1.0,
                      isLast: i == steps.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: SiliphSpacing.xxl),

            // Cancel button
            if (onCancel != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: SiliphSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SiliphRadii.md),
                    ),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF4A4658) : SiliphColors.outline,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(
    BuildContext context, {
    required String stepName,
    required bool isDone,
    required bool isActive,
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget icon;
    Color textColor;

    if (isDone) {
      icon = Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFF1F9D55),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
      textColor = isDark ? Colors.white : SiliphColors.onSurface;
    } else if (isActive) {
      icon = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF8C70FF) : SiliphColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
      textColor = isDark ? const Color(0xFFC8BFFF) : SiliphColors.primary;
    } else {
      icon = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? const Color(0xFF4A4658) : const Color(0xFFCDC9D8),
            width: 2,
          ),
        ),
      );
      textColor = isDark ? const Color(0xFF757082) : const Color(0xFF9E9AA8);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : SiliphSpacing.sm),
      child: Row(
        children: [
          icon,
          const SizedBox(width: SiliphSpacing.md),
          Text(
            stepName,
            style: theme.textTheme.bodyMediumStyle.copyWith(
              color: textColor,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
