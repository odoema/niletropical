/// Nile card surface
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NileCard extends StatelessWidget {
  const NileCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(NileSpacing.md),
      child: child,
    );

    return Card(
      margin: margin ?? EdgeInsets.zero,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: NileRadius.borderLg,
              child: content,
            )
          : content,
    );
  }
}
