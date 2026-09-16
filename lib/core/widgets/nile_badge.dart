/// Small status / count badge
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum NileBadgeVariant { primary, success, warning, error, neutral }

class NileBadge extends StatelessWidget {
  const NileBadge({
    super.key,
    required this.label,
    this.variant = NileBadgeVariant.primary,
  });

  final String label;
  final NileBadgeVariant variant;

  Color get _bg {
    switch (variant) {
      case NileBadgeVariant.primary:
        return NileColors.primaryContainer;
      case NileBadgeVariant.success:
        return NileColors.successContainer;
      case NileBadgeVariant.warning:
        return NileColors.warningContainer;
      case NileBadgeVariant.error:
        return NileColors.errorContainer;
      case NileBadgeVariant.neutral:
        return NileColors.surfaceVariant;
    }
  }

  Color get _fg {
    switch (variant) {
      case NileBadgeVariant.primary:
        return NileColors.primary;
      case NileBadgeVariant.success:
        return NileColors.success;
      case NileBadgeVariant.warning:
        return NileColors.warning;
      case NileBadgeVariant.error:
        return NileColors.error;
      case NileBadgeVariant.neutral:
        return NileColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: NileRadius.borderFull,
      ),
      child: Text(
        label,
        style: NileTypography.labelSmall.copyWith(color: _fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
