/// Siliph design tokens: typography (sections 54, 162).
library;

import 'package:flutter/material.dart';

/// Non-null accessors for Siliph text styles. The Siliph [TextTheme] built
/// by [SiliphTypography.build] fully specifies every style, so screens use
/// these instead of scattering null checks.
extension SiliphTextStyles on TextTheme {
  TextStyle get displaySmallStyle => displaySmall ?? const TextStyle();
  TextStyle get headlineMediumStyle => headlineMedium ?? const TextStyle();
  TextStyle get headlineSmallStyle => headlineSmall ?? const TextStyle();
  TextStyle get titleLargeStyle => titleLarge ?? const TextStyle();
  TextStyle get titleMediumStyle => titleMedium ?? const TextStyle();
  TextStyle get bodyLargeStyle => bodyLarge ?? const TextStyle();
  TextStyle get bodyMediumStyle => bodyMedium ?? const TextStyle();
  TextStyle get bodySmallStyle => bodySmall ?? const TextStyle();
  TextStyle get labelLargeStyle => labelLarge ?? const TextStyle();
  TextStyle get labelMediumStyle => labelMedium ?? const TextStyle();
  TextStyle get labelSmallStyle => labelSmall ?? const TextStyle();
}

/// Builds the Siliph [TextTheme]. Uses the default Material font stack;
/// sizes/weights follow the Display/Headline/Title/Body/Label/Caption scale.
abstract final class SiliphTypography {
  static TextTheme build(Brightness brightness) {
    final Color onSurface =
        brightness == Brightness.light ? const Color(0xFF1C1B22) : const Color(0xFFF4F2F8);
    final Color muted =
        brightness == Brightness.light ? const Color(0xFF6B6880) : const Color(0xFFB9B5C6);

    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: onSurface,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: onSurface,
        height: 1.25,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.35,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.35,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: onSurface, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14, color: onSurface, height: 1.45),
      bodySmall: TextStyle(fontSize: 13, color: muted, height: 1.4),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: onSurface,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: onSurface,
        letterSpacing: 0.2,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: muted,
        letterSpacing: 0.4,
      ),
    );
  }
}
