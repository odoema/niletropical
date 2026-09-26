/// Error / failure state
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../errors/error_reporter.dart';
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

  String? get _displayMessage {
    if (message == null) return null;
    final text = message!;
    final technical = text.contains('Exception') ||
        text.contains('PostgrestException') ||
        text.contains('PGRST') ||
        text.contains('PostgrestException(') ||
        RegExp(r'\bcode:\s*[0-9A-Z]{4,}\b').hasMatch(text);
    return technical ? ErrorReporter.friendlyMessage(text) : text;
  }

  @override
  Widget build(BuildContext context) {
    final displayMessage = _displayMessage;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NileSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: NileColors.error),
            const SizedBox(height: NileSpacing.md),
            Text(title, style: NileTypography.titleLarge, textAlign: TextAlign.center),
            if (displayMessage != null) ...[
              const SizedBox(height: NileSpacing.xs),
              Text(
                displayMessage,
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
