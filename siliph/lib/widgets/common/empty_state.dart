/// Reusable empty state (section 151).
///
/// Every empty screen answers: what is empty, why, and what to do next.
library;

import 'package:flutter/material.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';

/// A single action offered from an empty state.
class EmptyStateAction {
  const EmptyStateAction(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<EmptyStateAction> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: SiliphColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: SiliphColors.primary),
            ),
            const SizedBox(height: SiliphSpacing.md),
            Text(title, style: textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: SiliphSpacing.xxs),
            Text(
              message,
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: SiliphSpacing.md),
              Wrap(
                spacing: SiliphSpacing.xs,
                runSpacing: SiliphSpacing.xs,
                alignment: WrapAlignment.center,
                children: [
                  for (final action in actions)
                    FilledButton.tonal(
                      onPressed: action.onPressed,
                      child: Text(action.label),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
