/// Error / failure state
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'nile_button.dart';

class NileErrorState extends StatelessWidget {
  const NileErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NileSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: NileColors.error),
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
            if (onRetry != null) ...[
              const SizedBox(height: NileSpacing.lg),
              NileButton(
                label: 'Try again',
                onPressed: onRetry,
                fullWidth: false,
                icon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
