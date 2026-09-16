/// Nile Tropical — Design System Color Tokens
/// Primary: deep Nile blue #233E85 per master contract §1–3.
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';

/// Brand and semantic color tokens. Prefer these over hard-coded Color values.
abstract final class NileColors {
  // ── Brand ──────────────────────────────────────────────────────────────
  /// Primary brand — deep Nile blue
  static const Color primary = Color(0xFF233E85);
  static const Color primaryLight = Color(0xFF3A5BA0);
  static const Color primaryDark = Color(0xFF1A2F66);
  static const Color primaryContainer = Color(0xFFE8EEF8);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Secondary — warm sand / shea
  static const Color secondary = Color(0xFF3A5BA0);
  static const Color secondaryLight = Color(0xFF5C7AB8);
  static const Color secondaryDark = Color(0xFF1A2F66);
  static const Color secondaryContainer = Color(0xFFE8EEF8);
  static const Color onSecondary = Color(0xFFFFFFFF);

  /// Accent — premium gold
  static const Color accent = Color(0xFF233E85);
  static const Color accentLight = Color(0xFF3A5BA0);
  static const Color accentDark = Color(0xFF1A2F66);
  static const Color onAccent = Color(0xFFFFFFFF);

  // ── Neutrals ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFFFAFAF7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F0);
  static const Color surfaceDim = Color(0xFFEEEEEA);

  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF5F5F5F);
  static const Color textTertiary = Color(0xFF8A8A8A);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textDisabled = Color(0xFFBDBDBD);

  static const Color border = Color(0xFFE0E0E0);
  static const Color borderStrong = Color(0xFFBDBDBD);
  static const Color divider = Color(0xFFEEEEEE);

  // ── Status (contract §3) ───────────────────────────────────────────────
  static const Color success = Color(0xFF1F7A4D);
  static const Color successContainer = Color(0xFFE6F4EC);
  static const Color onSuccess = Color(0xFFFFFFFF);

  static const Color warning = Color(0xFFB7791F);
  static const Color warningContainer = Color(0xFFFBF0DE);
  static const Color onWarning = Color(0xFFFFFFFF);

  static const Color error = Color(0xFFB42318);
  static const Color errorContainer = Color(0xFFFCE8E6);
  static const Color onError = Color(0xFFFFFFFF);

  static const Color info = Color(0xFF0277BD);
  static const Color infoContainer = Color(0xFFE1F5FE);
  static const Color onInfo = Color(0xFFFFFFFF);

  // ── Overlay / scrim ────────────────────────────────────────────────────
  static const Color scrim = Color(0x99000000);
  static const Color overlay = Color(0x1A000000);
}
