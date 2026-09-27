import 'package:flutter/material.dart';

/// Shared width/scroll contract for storefront and admin workspaces.
///
/// The child owns its content; this widget owns the viewport contract so
/// narrow constraints cannot collapse normal text and controls into vertical
/// columns.
class NileResponsiveWorkspace extends StatelessWidget {
  const NileResponsiveWorkspace({
    super.key,
    required this.child,
    this.maxWidth = 1280,
    this.minContentWidth = 640,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    this.scrollDirection = Axis.horizontal,
  });

  final Widget child;
  final double maxWidth;
  final double minContentWidth;
  final EdgeInsetsGeometry padding;
  final Axis scrollDirection;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : minContentWidth;
        final contentWidth = viewportWidth
            .clamp(minContentWidth, maxWidth)
            .toDouble();

        Widget content = SizedBox(
          width: contentWidth,
          child: Padding(
            padding: padding,
            child: child,
          ),
        );

        if (scrollDirection == Axis.horizontal &&
            constraints.hasBoundedWidth &&
            constraints.maxWidth < minContentWidth) {
          content = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: content,
          );
        }

        return Align(
          alignment: Alignment.topCenter,
          child: content,
        );
      },
    );
  }
}
