/// Siliph design tokens: color.
///
/// Light theme is the default (master prompt sections 54, 163).
/// All UI color references must go through [SiliphColors] / the
/// resolved [ColorScheme]; never hardcode colors in widgets.
library;

import 'package:flutter/material.dart';

/// Centralized Siliph palette values.
abstract final class SiliphColors {
  // Brand ------------------------------------------------------------------
  /// Siliph purple primary.
  static const Color primary = Color(0xFF5B3FE4);
  static const Color primaryDark = Color(0xFF452EC4);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFE7E0FF);
  static const Color onPrimaryContainer = Color(0xFF2A1B70);

  // Surfaces ---------------------------------------------------------------
  static const Color background = Color(0xFFFAF9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF2F0F7);
  static const Color onSurface = Color(0xFF1C1B22);
  static const Color onSurfaceVariant = Color(0xFF6B6880);
  static const Color outline = Color(0xFFE3E0EA);
  static const Color divider = Color(0xFFEAE7F0);

  // Semantic ---------------------------------------------------------------
  static const Color success = Color(0xFF1F9D55);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFD93025);
  static const Color info = Color(0xFF2563EB);

  // Category accents (used for tool category chips/icons).
  static const Color categoryPdf = Color(0xFFE5484D);
  static const Color categoryImage = Color(0xFF3E9BFF);
  static const Color categoryScanner = Color(0xFF12A594);
  static const Color categoryOcr = Color(0xFF8E4EC6);
  static const Color categoryFiles = Color(0xFFF76B15);
  static const Color categorySecurity = Color(0xFF6E56CF);
  static const Color categoryUtilities = Color(0xFF0091FF);
  static const Color categoryAi = Color(0xFFDB61B2);

  /// Builds the light [ColorScheme] used by the app theme.
  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: Color(0xFF7A6FF0),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFEDEAFF),
      onSecondaryContainer: Color(0xFF3B3390),
      tertiary: Color(0xFF12A594),
      onTertiary: Color(0xFFFFFFFF),
      error: error,
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: divider,
      shadow: Color(0x1A1C1B22),
      scrim: Color(0x661C1B22),
      inverseSurface: Color(0xFF2A2930),
      onInverseSurface: Color(0xFFF4F2F8),
      inversePrimary: Color(0xFFCDBDFF),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF7F5FB),
      surfaceContainer: Color(0xFFF2F0F7),
      surfaceContainerHigh: Color(0xFFECE9F3),
      surfaceContainerHighest: Color(0xFFE6E3EE),
    );
  }

  /// Builds the dark [ColorScheme]. Light is the product default; dark is an
  /// opt-in appearance setting (section 83).
  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFCDBDFF),
      onPrimary: Color(0xFF34227E),
      primaryContainer: Color(0xFF452EC4),
      onPrimaryContainer: Color(0xFFE7E0FF),
      secondary: Color(0xFFC3BBFF),
      onSecondary: Color(0xFF3B3390),
      secondaryContainer: Color(0xFF4A41A6),
      onSecondaryContainer: Color(0xFFEDEAFF),
      tertiary: Color(0xFF6FE3D2),
      onTertiary: Color(0xFF00443C),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF17161C),
      onSurface: Color(0xFFF4F2F8),
      onSurfaceVariant: Color(0xFFB9B5C6),
      outline: Color(0xFF3A3844),
      outlineVariant: Color(0xFF2A2930),
      shadow: Color(0x66000000),
      scrim: Color(0x99000000),
      inverseSurface: Color(0xFFF4F2F8),
      onInverseSurface: Color(0xFF2A2930),
      inversePrimary: Color(0xFF5B3FE4),
      surfaceContainerLowest: Color(0xFF101014),
      surfaceContainerLow: Color(0xFF1C1B22),
      surfaceContainer: Color(0xFF211F28),
      surfaceContainerHigh: Color(0xFF28262F),
      surfaceContainerHighest: Color(0xFF2F2D37),
    );
  }
}
