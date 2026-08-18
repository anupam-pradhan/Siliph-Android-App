/// Shared scanner UI widgets.
///
/// All widgets use the existing Siliph Liquid Glass design tokens.
/// Scanner accent color: [SiliphColors.categoryScanner] (#12A594 teal).
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import 'scanner_state.dart';

/// Draws the document detection frame and detected corners over the camera.
class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    super.key,
    required this.detectedCorners,
    required this.status,
    this.showFrame = true,
  });

  final List<double>? detectedCorners;
  final CameraStatus status;
  final bool showFrame;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DetectionOverlayPainter(
        corners: detectedCorners,
        status: status,
        showFrame: showFrame,
      ),
      size: Size.infinite,
    );
  }
}

class _DetectionOverlayPainter extends CustomPainter {
  _DetectionOverlayPainter({
    required this.corners,
    required this.status,
    required this.showFrame,
  });

  final List<double>? corners;
  final CameraStatus status;
  final bool showFrame;

  @override
  void paint(Canvas canvas, Size size) {
    if (showFrame) {
      _drawFrameOverlay(canvas, size);
    }
    if (corners != null && corners!.length == 8) {
      _drawDocumentBoundary(canvas, size);
    }
  }

  void _drawFrameOverlay(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final path = Path()..addRect(Offset.zero & size);
    final margin = size.shortestSide * 0.1;
    final frameRect = Rect.fromLTWH(
      margin,
      margin + size.height * 0.05,
      size.width - margin * 2,
      size.height - margin * 2 - size.height * 0.1,
    );
    final framePath = Path()
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(4)));
    final cutout = Path.combine(PathOperation.difference, path, framePath);
    canvas.drawPath(cutout, overlayPaint);
    _drawCornerBrackets(canvas, frameRect);
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect) {
    final bracketPaint = Paint()
      ..color = SiliphColors.categoryScanner
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final len = min(rect.shortestSide * 0.08, 30.0);
    final cornersList = [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];

    for (var i = 0; i < 4; i++) {
      final center = cornersList[i];
      final dx = i == 0 || i == 3 ? 1.0 : -1.0;
      final dy = i == 0 || i == 1 ? 1.0 : -1.0;
      canvas.drawLine(center, center + Offset(dx * len, 0), bracketPaint);
      canvas.drawLine(center, center + Offset(0, dy * len), bracketPaint);
    }
  }

  void _drawDocumentBoundary(Canvas canvas, Size size) {
    final pts = <Offset>[];
    for (var i = 0; i < 4; i++) {
      pts.add(Offset(
          corners![i * 2] * size.width, corners![i * 2 + 1] * size.height));
    }

    final borderPaint = Paint()
      ..color = SiliphColors.categoryScanner
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < 4; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();
    canvas.drawPath(path, borderPaint);

    final cornerPaint = Paint()
      ..color = SiliphColors.categoryScanner
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final pt in pts) {
      canvas.drawCircle(pt, 8, cornerPaint);
      canvas.drawCircle(pt, 8, outlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionOverlayPainter oldDelegate) {
    return oldDelegate.corners != corners || oldDelegate.status != status;
  }
}

/// Shows the current detection status message.
class ScannerStatusBanner extends StatelessWidget {
  const ScannerStatusBanner({super.key, required this.status});

  final CameraStatus status;

  @override
  Widget build(BuildContext context) {
    final isSteady = status == CameraStatus.holdSteady;
    final isDetected = status == CameraStatus.detected;
    final isError = status == CameraStatus.permissionDenied ||
        status == CameraStatus.cameraUnavailable ||
        status == CameraStatus.poorLighting;

    Color bgColor;
    Color textColor;
    IconData? icon;

    if (isSteady || isDetected) {
      bgColor = SiliphColors.categoryScanner.withValues(alpha: 0.15);
      textColor = SiliphColors.categoryScanner;
      icon = isSteady ? Icons.check_circle_outline : Icons.crop_free;
    } else if (isError) {
      bgColor = SiliphColors.error.withValues(alpha: 0.1);
      textColor = SiliphColors.error;
      icon = Icons.error_outline;
    } else {
      bgColor = Colors.black.withValues(alpha: 0.5);
      textColor = Colors.white;
      icon = null;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(status),
        padding: const EdgeInsets.symmetric(
          horizontal: SiliphSpacing.md,
          vertical: SiliphSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(SiliphRadii.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: SiliphSpacing.xxs),
            ],
            Text(
              status.message,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The main capture button for the scanner.
class CaptureButton extends StatelessWidget {
  const CaptureButton({
    super.key,
    required this.onTap,
    this.isCapturing = false,
    this.isEnabled = true,
  });

  final VoidCallback onTap;
  final bool isCapturing;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    return GestureDetector(
      onTap: isEnabled && !isCapturing ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled ? Colors.white : Colors.white.withValues(alpha: 0.4),
          border: Border.all(
            color: isEnabled
                ? SiliphColors.categoryScanner
                : SiliphColors.categoryScanner.withValues(alpha: 0.3),
            width: 4,
          ),
          boxShadow: [
            if (isEnabled)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Center(
          child: isCapturing
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: SiliphColors.categoryScanner,
                  ),
                )
              : Container(
                  width: size - 16,
                  height: size - 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEnabled
                        ? SiliphColors.categoryScanner
                        : SiliphColors.categoryScanner.withValues(alpha: 0.3),
                  ),
                ),
        ),
      ),
    );
  }
}

/// A circular control button for the scanner toolbar.
class ScannerControlButton extends StatelessWidget {
  const ScannerControlButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? SiliphColors.categoryScanner.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.4),
          ),
          child: Icon(
            icon,
            color: isActive ? SiliphColors.categoryScanner : Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of scanned page thumbnails.
class PageThumbnailStrip extends StatelessWidget {
  const PageThumbnailStrip({
    super.key,
    required this.pages,
    this.selectedIndex,
    this.onTap,
    this.onDelete,
  });

  final List<ScannedPage> pages;
  final int? selectedIndex;
  final ValueChanged<int>? onTap;
  final ValueChanged<int>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SiliphSpacing.md),
        itemCount: pages.length,
        separatorBuilder: (_, _) => const SizedBox(width: SiliphSpacing.xs),
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: onTap != null ? () => onTap!(index) : null,
            child: Stack(
              children: [
                Container(
                  width: 56,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SiliphRadii.sm),
                    border: Border.all(
                      color: isSelected
                          ? SiliphColors.categoryScanner
                          : SiliphColors.outline,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular((SiliphRadii.sm - 1).toDouble()),
                    child: ColoredBox(
                      color: SiliphColors.surfaceVariant,
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMediumStyle
                              .copyWith(color: SiliphColors.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                ),
                if (onDelete != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => onDelete!(index),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SiliphColors.error,
                          border:
                              Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.close,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// An info card using the Siliph Liquid Glass surface pattern.
class GlassInfoCard extends StatelessWidget {
  const GlassInfoCard({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding ?? const EdgeInsets.all(SiliphSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1C26) : const Color(0xFFF9F8FD),
        borderRadius: BorderRadius.circular(SiliphRadii.lg),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2C3A) : SiliphColors.outline,
        ),
      ),
      child: child,
    );
  }
}

/// Scanner error banner with icon and message.
class ScannerErrorBanner extends StatelessWidget {
  const ScannerErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.sm),
      decoration: BoxDecoration(
        color: SiliphColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SiliphRadii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: SiliphColors.error, size: 20),
          const SizedBox(width: SiliphSpacing.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
