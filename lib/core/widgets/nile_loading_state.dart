/// Centered loading indicator with optional message
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NileLoadingState extends StatelessWidget {
  const NileLoadingState({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: NileColors.primary),
          if (message != null) ...[
            const SizedBox(height: NileSpacing.md),
            Text(message!, style: NileTypography.bodyMedium),
          ],
        ],
      ),
    );
  }
}
