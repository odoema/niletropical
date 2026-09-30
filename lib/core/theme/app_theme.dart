/// Nile Tropical — App Theme
/// Rebuilt around #233E85 deep Nile blue + Poppins per master contract §1–3.
/// UI refresh 2026-09-30: component polish only — brand colour tokens unchanged.
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
      primaryTextTheme: NileTypography.textTheme.apply(
        bodyColor: NileColors.onPrimary,
        displayColor: NileColors.onPrimary,
      ),
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      hoverColor: NileColors.primary.withValues(alpha: 0.04),
      focusColor: NileColors.primary.withValues(alpha: 0.12),
      highlightColor: NileColors.primary.withValues(alpha: 0.06),

      appBarTheme: AppBarTheme(
        backgroundColor: NileColors.surface,
        foregroundColor: NileColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        shadowColor: NileColors.border,
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
          shadowColor: NileColors.primary.withValues(alpha: 0.35),
          textStyle: NileTypography.button,
        ).copyWith(
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered) ? 3.0 : 0.0,
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return NileColors.onPrimary.withValues(alpha: 0.14);
            }
            if (states.contains(WidgetState.hovered)) {
              return NileColors.onPrimary.withValues(alpha: 0.08);
            }
            return null;
          }),
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
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered)
                ? NileColors.primaryContainer
                : null,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NileColors.primary,
          textStyle: NileTypography.buttonSmall,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: NileRadius.borderSm),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NileColors.primary,
          foregroundColor: NileColors.onPrimary,
          disabledBackgroundColor: NileColors.border,
          disabledForegroundColor: NileColors.textDisabled,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: NileRadius.borderMd),
          textStyle: NileTypography.button,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: NileColors.textPrimary,
          highlightColor: NileColors.primary.withValues(alpha: 0.08),
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
        hoverColor: NileColors.primaryContainer.withValues(alpha: 0.35),
        labelStyle: NileTypography.bodyMedium,
        floatingLabelStyle: NileTypography.bodyMedium.copyWith(
          color: NileColors.primary,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: NileColors.textTertiary,
        suffixIconColor: NileColors.textTertiary,
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
          side: BorderSide(color: NileColors.border.withValues(alpha: 0.7)),
        ),
        surfaceTintColor: Colors.transparent,
        shadowColor: NileColors.primary.withValues(alpha: 0.12),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: NileColors.surfaceVariant,
        selectedColor: NileColors.primaryContainer,
        checkmarkColor: NileColors.primary,
        labelStyle: NileTypography.labelMedium.copyWith(
          color: NileColors.textPrimary,
        ),
        secondaryLabelStyle: NileTypography.labelMedium.copyWith(
          color: NileColors.primary,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: NileColors.border),
        shape: RoundedRectangleBorder(borderRadius: NileRadius.borderFull),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      dividerTheme: const DividerThemeData(
        color: NileColors.divider,
        thickness: 1,
        space: 1,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: NileColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: NileRadius.borderXl),
        titleTextStyle: NileTypography.headlineSmall,
        contentTextStyle: NileTypography.bodyMedium,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NileColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: NileColors.borderStrong,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: NileColors.primaryDark,
        contentTextStyle: NileTypography.bodyMedium.copyWith(
          color: NileColors.onPrimary,
        ),
        actionTextColor: NileColors.onPrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: NileRadius.borderMd),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: NileColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: NileColors.border,
        indicatorColor: NileColors.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: NileRadius.borderFull,
        ),
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
        height: 66,
        elevation: 1,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NileColors.primary,
        linearTrackColor: NileColors.primaryContainer,
        circularTrackColor: NileColors.primaryContainer,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: NileColors.primary,
        foregroundColor: NileColors.onPrimary,
        elevation: 2,
        hoverElevation: 4,
        focusElevation: 4,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: NileRadius.borderLg),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: NileColors.surface,
        indicatorColor: NileColors.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: NileRadius.borderFull,
        ),
        selectedIconTheme:
            const IconThemeData(color: NileColors.primary, size: 24),
        unselectedIconTheme:
            const IconThemeData(color: NileColors.textSecondary, size: 24),
        selectedLabelTextStyle: NileTypography.labelMedium.copyWith(
          color: NileColors.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: NileTypography.labelMedium.copyWith(
          color: NileColors.textSecondary,
        ),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: NileColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: NileColors.primary,
        unselectedLabelColor: NileColors.textSecondary,
        labelStyle: NileTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: NileTypography.labelLarge,
        indicatorColor: NileColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: NileColors.divider,
        overlayColor: WidgetStatePropertyAll(
          NileColors.primary.withValues(alpha: 0.06),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: NileColors.textSecondary,
        textColor: NileColors.textPrimary,
        titleTextStyle: NileTypography.titleSmall,
        subtitleTextStyle: NileTypography.bodySmall,
        selectedColor: NileColors.primary,
        selectedTileColor: NileColors.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: NileRadius.borderMd),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: NileColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: NileColors.primary.withValues(alpha: 0.18),
        textStyle: NileTypography.bodyMedium.copyWith(
          color: NileColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: NileRadius.borderMd,
          side: const BorderSide(color: NileColors.divider),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: NileColors.primaryDark,
          borderRadius: NileRadius.borderSm,
        ),
        textStyle: NileTypography.labelMedium.copyWith(
          color: NileColors.onPrimary,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),

      badgeTheme: BadgeThemeData(
        backgroundColor: NileColors.error,
        textColor: NileColors.onError,
        textStyle: NileTypography.labelSmall.copyWith(
          color: NileColors.onError,
          fontWeight: FontWeight.w700,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NileColors.primary
              : null,
        ),
        checkColor: const WidgetStatePropertyAll(NileColors.onPrimary),
        side: const BorderSide(color: NileColors.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: NileRadius.borderXs),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NileColors.primary
              : NileColors.borderStrong,
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NileColors.onPrimary
              : NileColors.borderStrong,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NileColors.primary
              : NileColors.surfaceVariant,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NileColors.primary
              : NileColors.border,
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: NileColors.textSecondary,
          selectedForegroundColor: NileColors.primary,
          selectedBackgroundColor: NileColors.primaryContainer,
          side: const BorderSide(color: NileColors.border),
          textStyle: NileTypography.labelLarge,
        ),
      ),

      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0.0),
        backgroundColor: const WidgetStatePropertyAll(NileColors.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: const WidgetStatePropertyAll(
          BorderSide(color: NileColors.border),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: NileRadius.borderFull),
        ),
        textStyle: WidgetStatePropertyAll(
          NileTypography.bodyLarge,
        ),
        hintStyle: WidgetStatePropertyAll(
          NileTypography.bodyMedium.copyWith(color: NileColors.textTertiary),
        ),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.dragged)
              ? NileColors.primary.withValues(alpha: 0.55)
              : NileColors.primary.withValues(alpha: 0.25),
        ),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(6.0),
      ),
    );
  }
}

/// Temporary alias so existing screens that import AppColors keep compiling
/// during the P3–P8 migration. Prefer NileColors in new code.
typedef AppColors = NileColors;
