/// Nile outlined secondary button
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NileOutlinedButton extends StatelessWidget {
  const NileOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: NileColors.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final button = SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        child: child,
      ),
    );

    if (!fullWidth) {
      return button;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // A Row can provide an unbounded width. In that situation,
        // let the button use its natural width instead of requesting
        // double.infinity.
        if (!constraints.hasBoundedWidth) {
          return button;
        }

        return SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: loading ? null : onPressed,
            child: child,
          ),
        );
      },
    );
  }
}