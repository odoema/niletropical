/// Nile Tropical — Spacing scale (8 / 12 / 16 / 24 base, plus common extras)
/// Enforce via tokens; avoid magic numbers in layouts.
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';

abstract final class NileSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Common edge insets
  static const EdgeInsets pagePadding = EdgeInsets.all(md);
  static const EdgeInsets pagePaddingHorizontal =
      EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets sectionGap = EdgeInsets.only(bottom: lg);

  /// Gap helpers for Flex
  static const double gapXs = xs;
  static const double gapSm = sm;
  static const double gapMd = md;
  static const double gapLg = lg;
}
