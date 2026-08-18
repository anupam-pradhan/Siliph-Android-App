/// Success screen after scan is saved.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import 'scan_mode.dart';
import 'scanner_provider.dart';
import 'scanner_state.dart';

class ScanSuccessScreen extends ConsumerWidget {
  const ScanSuccessScreen({super.key, required this.mode});

  final ScanMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scannerProvider(mode));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(SiliphSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SiliphColors.success.withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 48,
                    color: SiliphColors.success,
                  ),
                ),
                const SizedBox(height: SiliphSpacing.xl),
                Text(
                  'Scan Saved',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: SiliphSpacing.xs),
                Text(
                  '${state.pageCount} ${state.pageCount == 1 ? 'page' : 'pages'} saved successfully.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SiliphColors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: SiliphSpacing.xl),

                // File info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(SiliphSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1C26)
                        : const Color(0xFFF9F8FD),
                    borderRadius: BorderRadius.circular(SiliphRadii.lg),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2E2C3A)
                          : SiliphColors.outline,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(mode.icon,
                              color: SiliphColors.categoryScanner, size: 24),
                          const SizedBox(width: SiliphSpacing.sm),
                          Expanded(
                            child: Text(
                              '${state.effectiveFileName}.${state.outputFormat.extension}',
                              style:
                                  Theme.of(context).textTheme.titleSmallStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: SiliphSpacing.xs),
                      Row(
                        children: [
                          _InfoChip(
                              label: '${state.pageCount} ${state.pageCount == 1 ? 'page' : 'pages'}'),
                          const SizedBox(width: SiliphSpacing.xs),
                          _InfoChip(label: state.outputFormat.label),
                          const SizedBox(width: SiliphSpacing.xs),
                          _InfoChip(label: state.quality.label),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SiliphSpacing.xl),

                // Action buttons
                FilledButton.icon(
                  onPressed: () {
                    ref.read(scannerProvider(mode).notifier).restart();
                    context.go(SiliphRoutes.home);
                  },
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Done'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: SiliphSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(scannerProvider(mode).notifier).restart();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan Another'),
                ),
                const SizedBox(height: SiliphSpacing.sm),
                TextButton(
                  onPressed: () {
                    ref.read(scannerProvider(mode).notifier).restart();
                    context.go(SiliphRoutes.recent);
                  },
                  child: const Text('View in Recent'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SiliphSpacing.xs, vertical: SiliphSpacing.xxs),
      decoration: BoxDecoration(
        color: SiliphColors.categoryScanner.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(SiliphRadii.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: SiliphColors.categoryScanner,
            ),
      ),
    );
  }
}
