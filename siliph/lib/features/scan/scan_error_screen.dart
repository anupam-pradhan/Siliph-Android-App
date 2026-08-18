/// Scanner error screen with actionable recovery options.
library;

import 'package:flutter/material.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';

enum ScanErrorType {
  cameraUnavailable(
    'Camera Unavailable',
    'Could not access the device camera.',
    Icons.videocam_off_outlined,
  ),
  permissionDenied(
    'Permission Denied',
    'Camera permission is required to scan documents.',
    Icons.lock_outline,
  ),
  processingFailed(
    'Processing Failed',
    'An error occurred while processing the image.',
    Icons.broken_image_outlined,
  ),
  detectionFailed(
    'Detection Failed',
    'Could not detect document edges. Try better lighting.',
    Icons.crop_free,
  ),
  perspectiveFailed(
    'Correction Failed',
    'Perspective correction failed. Try adjusting the corners.',
    Icons.transform,
  ),
  imageTooLarge(
    'Image Too Large',
    'The image exceeds the maximum allowed size.',
    Icons.image_outlined,
  ),
  storageFull(
    'Insufficient Storage',
    'Not enough storage space to save the scan.',
    Icons.storage_outlined,
  );

  const ScanErrorType(this.title, this.message, this.icon);

  final String title;
  final String message;
  final IconData icon;
}

class ScanErrorScreen extends StatelessWidget {
  const ScanErrorScreen({
    super.key,
    required this.errorType,
    this.customMessage,
    required this.onRetry,
    required this.onGoBack,
  });

  final ScanErrorType errorType;
  final String? customMessage;
  final VoidCallback onRetry;
  final VoidCallback onGoBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(SiliphSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SiliphColors.error.withValues(alpha: 0.12),
                  ),
                  child: Icon(errorType.icon, size: 40, color: SiliphColors.error),
                ),
                const SizedBox(height: SiliphSpacing.xl),
                Text(
                  errorType.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: SiliphSpacing.sm),
                Text(
                  customMessage ?? errorType.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SiliphColors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: SiliphSpacing.xl),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: SiliphSpacing.sm),
                OutlinedButton(
                  onPressed: onGoBack,
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
