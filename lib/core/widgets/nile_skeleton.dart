import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lightweight skeleton primitives for storefront loading states.
///
/// Uses Flutter's built-in animation rather than adding another package.
class NileSkeleton extends StatefulWidget {
  const NileSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<NileSkeleton> createState() => _NileSkeletonState();
}

class _NileSkeletonState extends State<NileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Opacity(
        opacity: 0.58 + (_controller.value * 0.22),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: NileColors.surfaceVariant,
            borderRadius: widget.borderRadius,
          ),
        ),
      ),
    );
  }
}

class NileProductSkeleton extends StatelessWidget {
  const NileProductSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(
            aspectRatio: 1,
            child: NileSkeleton(
              borderRadius: BorderRadius.zero,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(NileSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                NileSkeleton(height: 14),
                SizedBox(height: 8),
                NileSkeleton(width: 90, height: 12),
                SizedBox(height: 12),
                NileSkeleton(width: 110, height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NileProductGridSkeleton extends StatelessWidget {
  const NileProductGridSkeleton({
    super.key,
    this.itemCount = 6,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, __) => const NileProductSkeleton(),
    );
  }
}

class NileHeroSkeleton extends StatelessWidget {
  const NileHeroSkeleton({
    super.key,
    this.height = 420,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return NileSkeleton(
      height: height,
      borderRadius: BorderRadius.circular(20),
    );
  }
}
