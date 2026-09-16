/// Confirm / destructive action dialog
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'nile_button.dart';
import 'nile_outlined_button.dart';

class NileConfirmDialog extends StatelessWidget {
  const NileConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => NileConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: NileTypography.headlineSmall),
      content: Text(message, style: NileTypography.bodyMedium),
      actions: [
        NileOutlinedButton(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
          fullWidth: false,
        ),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  destructive ? NileColors.error : NileColors.primary,
              foregroundColor: NileColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: NileRadius.borderMd),
              elevation: 0,
              textStyle: NileTypography.button,
            ),
            child: Text(confirmLabel),
          ),
        ),
      ],
      actionsAlignment: MainAxisAlignment.end,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }
}
