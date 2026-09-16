/// Nile Tropical — App Theme
/// Rebuilt around #233E85 deep Nile blue + Poppins per master contract §1–3.
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nile_colors.dart';
import 'nile_radius.dart';
import 'nile_typography.dart';

export 'nile_colors.dart';
export 'nile_spacing.dart';
export 'nile_radius.dart';
export 'nile_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: NileColors.primary,
      onPrimary: NileColors.onPrimary,
      primaryContainer: NileColors.primaryContainer,
      onPrimaryContainer: NileColors.primaryDark,
      secondary: NileColors.secondary,
      onSecondary: NileColors.onSecondary,
      secondaryContainer: NileColors.secondaryContainer,
      onSecondaryContainer: NileColors.secondaryDark,
      tertiary: NileColors.accent,
      onTertiary: NileColors.onAccent,
      error: NileColors.error,
      onError: NileColors.onError,
      errorContainer: NileColors.errorContainer,
      onErrorContainer: NileColors.error,
      surface: NileColors.surface,
      onSurface: NileColors.textPrimary,
      surfaceContainerHighest: NileColors.surfaceVariant,
      onSurfaceVariant: NileColors.textSecondary,
      outline: NileColors.border,
      outlineVariant: NileColors.divider,
      shadow: Colors.black.withValues(alpha: 0.08),
      scrim: NileColors.scrim,
      inverseSurface: NileColors.textPrimary,
      onInverseSurface: NileColors.surface,
      inversePrimary: NileColors.primaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: NileColors.background,
      primaryColor: NileColors.primary,
      textTheme: NileTypography.textTheme,
      fontFamily: NileTypography.bodyLarge.fontFamily,

      appBarTheme: AppBarTheme(
        backgroundColor: NileColors.surface,
        foregroundColor: NileColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: NileTypography.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: const IconThemeData(color: NileColors.textPrimary, size: 24),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NileColors.primary,
          foregroundColor: NileColors.onPrimary,
          disabledBackgroundColor: NileColors.border,
          disabledForegroundColor: NileColors.textDisabled,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: NileRadius.borderMd),
          elevation: 0,
          textStyle: NileTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NileColors.primary,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: NileColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: NileRadius.borderMd),
          textStyle: NileTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NileColors.primary,
          textStyle: NileTypography.buttonSmall,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NileColors.primary,
          foregroundColor: NileColors.onPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: NileRadius.borderMd),
          textStyle: NileTypography.button,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NileColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: NileRadius.borderMd,
          borderSide: const BorderSide(color: NileColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: NileRadius.borderMd,
          borderSide: const BorderSide(color: NileColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: NileRadius.borderMd,
          borderSide: const BorderSide(color: NileColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: NileRadius.borderMd,
          borderSide: const BorderSide(color: NileColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: NileRadius.borderMd,
          borderSide: const BorderSide(color: NileColors.error, width: 2),
        ),
        labelStyle: NileTypography.bodyMedium,
        hintStyle: NileTypography.bodyMedium.copyWith(
          color: NileColors.textTertiary,
        ),
        errorStyle: NileTypography.caption.copyWith(color: NileColors.error),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: NileColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: NileRadius.borderLg,
          side: const BorderSide(color: NileColors.border),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: NileColors.surfaceVariant,
        selectedColor: NileColors.primaryContainer,
        labelStyle: NileTypography.labelMedium,
        side: const BorderSide(color: NileColors.border),
        shape: RoundedRectangleBorder(borderRadius: NileRadius.borderSm),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      dividerTheme: const DividerThemeData(
        color: NileColors.divider,
        thickness: 1,
        space: 1,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: NileColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: NileRadius.borderLg),
        titleTextStyle: NileTypography.headlineSmall,
        contentTextStyle: NileTypography.bodyMedium,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NileColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        showDragHandle: true,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: NileColors.textPrimary,
        contentTextStyle: NileTypography.bodyMedium.copyWith(
          color: NileColors.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: NileRadius.borderSm),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: NileColors.surface,
        indicatorColor: NileColors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return NileTypography.labelSmall.copyWith(
              color: NileColors.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return NileTypography.labelSmall;
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: NileColors.primary, size: 24);
          }
          return const IconThemeData(color: NileColors.textSecondary, size: 24);
        }),
        height: 64,
        elevation: 0,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NileColors.primary,
        linearTrackColor: NileColors.primaryContainer,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: NileColors.primary,
        foregroundColor: NileColors.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: NileRadius.borderMd),
      ),
    );
  }
}

/// Temporary alias so existing screens that import AppColors keep compiling
/// during the P3–P8 migration. Prefer NileColors in new code.
typedef AppColors = NileColors;
