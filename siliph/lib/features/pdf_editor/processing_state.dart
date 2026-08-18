/// Processing states (section 31).
/// Editor processing screens for: saving, rendering, applying edits, flattening, exporting.
/// Show progress and current operation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';

/// Processing state widget
class ProcessingState extends ConsumerWidget {
  final _ProcessingStage stage;
  final String message;
  final bool showProgress;
  final VoidCallback? onCancel;

  const ProcessingState({
    required this.stage,
    required this.message,
    this.showProgress = true,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        decoration: BoxDecoration(
          color: SiliphColors.surface,
          borderRadius: BorderRadius.circular(SiliphRadii.lg),
          border: Border.all(color: SiliphColors.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stage-specific indicator
            _buildStageIndicator(),

            const SizedBox(height: SiliphSpacing.lg),

            // Message
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: SiliphSpacing.lg),

            // Progress indicator (when applicable)
            if (showProgress)
              const CircularProgressIndicator()

            else
              const SizedBox.shrink(),

            const SizedBox(height: SiliphSpacing.lg),

            // Cancel button (for long operations)
            if (onCancel != null)
              TextButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildStageIndicator() {
    final iconData;
    final color;

    switch (stage) {
      case _ProcessingStage.saving:
        iconData = Icons.save_outlined;
        color = SiliphColors.primary;
        break;
      case _ProcessingStage.rendering:
        iconData = Icons.image_outlined;
        color = SiliphColors.primary;
        break;
      case _ProcessingStage.applyingEdits:
        iconData = Icons.edit_outlined;
        color = SiliphColors.primary;
        break;
      case _ProcessingStage.flattening:
        iconData = Icons.transform_outlined;
        color = SiliphColors.primary;
        break;
      case _ProcessingStage.exporting:
        iconData = Icons.share_outlined;
        color = SiliphColors.primary;
        break;
    }

    return Icon(iconData, size: 48, color: color);
  }
}

/// Processing stages
enum _ProcessingStage {
  saving,
  rendering,
  applyingEdits,
  flattening,
  exporting,
}