/// Nile Tropical — Typography scale (Poppins)
/// Display / Headline / Title / Subtitle / Body / Caption / Label / Button
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'nile_colors.dart';

/// Text styles built on Poppins. Use via Theme.of(context).textTheme or
/// NileTypography directly. Falls back to system sans if offline.
abstract final class NileTypography {
  static TextStyle _base({
    required double size,
    required FontWeight weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'Poppins',
      fontSize: size,
      fontWeight: weight,
      color: color ?? NileColors.textPrimary,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Display
  static TextStyle get displayLarge => _base(
        size: 36,
        weight: FontWeight.w700,
        height: 1.2,
      );
  static TextStyle get displayMedium => _base(
        size: 32,
        weight: FontWeight.w700,
        height: 1.2,
      );
  static TextStyle get displaySmall => _base(
        size: 28,
        weight: FontWeight.w700,
        height: 1.25,
      );

  // Headline
  static TextStyle get headlineLarge => _base(
        size: 24,
        weight: FontWeight.w600,
        height: 1.3,
      );
  static TextStyle get headlineMedium => _base(
        size: 22,
        weight: FontWeight.w600,
        height: 1.3,
      );
  static TextStyle get headlineSmall => _base(
        size: 20,
        weight: FontWeight.w600,
        height: 1.3,
      );

  // Title
  static TextStyle get titleLarge => _base(
        size: 18,
        weight: FontWeight.w600,
        height: 1.35,
      );
  static TextStyle get titleMedium => _base(
        size: 16,
        weight: FontWeight.w600,
        height: 1.4,
      );
  static TextStyle get titleSmall => _base(
        size: 14,
        weight: FontWeight.w600,
        height: 1.4,
      );

  // Subtitle
  static TextStyle get subtitleLarge => _base(
        size: 16,
        weight: FontWeight.w500,
        color: NileColors.textSecondary,
        height: 1.4,
      );
  static TextStyle get subtitleMedium => _base(
        size: 14,
        weight: FontWeight.w500,
        color: NileColors.textSecondary,
        height: 1.4,
      );

  // Body
  static TextStyle get bodyLarge => _base(
        size: 16,
        weight: FontWeight.w400,
        height: 1.5,
      );
  static TextStyle get bodyMedium => _base(
        size: 14,
        weight: FontWeight.w400,
        color: NileColors.textSecondary,
        height: 1.5,
      );
  static TextStyle get bodySmall => _base(
        size: 12,
        weight: FontWeight.w400,
        color: NileColors.textSecondary,
        height: 1.45,
      );

  // Caption / Label
  static TextStyle get caption => _base(
        size: 12,
        weight: FontWeight.w400,
        color: NileColors.textTertiary,
        height: 1.4,
      );
  static TextStyle get labelLarge => _base(
        size: 14,
        weight: FontWeight.w500,
        letterSpacing: 0.1,
      );
  static TextStyle get labelMedium => _base(
        size: 12,
        weight: FontWeight.w500,
        letterSpacing: 0.1,
      );
  static TextStyle get labelSmall => _base(
        size: 11,
        weight: FontWeight.w500,
        letterSpacing: 0.2,
        color: NileColors.textTertiary,
      );

  // Button
  static TextStyle get button => _base(
        size: 16,
        weight: FontWeight.w600,
        letterSpacing: 0.2,
      );
  static TextStyle get buttonSmall => _base(
        size: 14,
        weight: FontWeight.w600,
        letterSpacing: 0.2,
      );

  /// Full TextTheme for ThemeData
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );
}
