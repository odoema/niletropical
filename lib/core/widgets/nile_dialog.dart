/// Standard alert dialog wrapper
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'nile_button.dart';
import 'nile_outlined_button.dart';

class NileDialog extends StatelessWidget {
  const NileDialog({
    super.key,
    required this.title,
    this.content,
    this.confirmLabel = 'OK',
    this.cancelLabel,
    this.onConfirm,
    this.onCancel,
  });

  final String title;
  final Widget? content;
  final String confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    Widget? content,
    String confirmLabel = 'OK',
    String? cancelLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => NileDialog(
        title: title,
        content: content,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: cancelLabel != null ? () => Navigator.of(ctx).pop(false) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: NileTypography.headlineSmall),
      content: content,
      actions: [
        if (cancelLabel != null)
          NileOutlinedButton(
            label: cancelLabel!,
            onPressed: onCancel ?? () => Navigator.of(context).pop(false),
            fullWidth: false,
          ),
        NileButton(
          label: confirmLabel,
          onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
          fullWidth: false,
        ),
      ],
      actionsAlignment: MainAxisAlignment.end,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }
}
