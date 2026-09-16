/// Empty list / no-data state
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'nile_button.dart';

class NileEmptyState extends StatelessWidget {
  const NileEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NileSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: NileColors.textTertiary),
            const SizedBox(height: NileSpacing.md),
            Text(title, style: NileTypography.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: NileSpacing.xs),
              Text(
                message!,
                style: NileTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: NileSpacing.lg),
              NileButton(
                label: actionLabel!,
                onPressed: onAction,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
