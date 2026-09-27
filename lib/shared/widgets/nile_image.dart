import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shared storefront image primitive.
///
/// Keeps image loading, caching, placeholder and failure behavior consistent
/// without changing the source of truth for image URLs.
class NileImage extends StatelessWidget {
  const NileImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius = BorderRadius.zero,
    this.backgroundColor,
    this.placeholderIcon = Icons.image_outlined,
    this.errorIcon = Icons.broken_image_outlined,
    this.semanticLabel,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String? url;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final IconData placeholderIcon;
  final IconData errorIcon;
  final String? semanticLabel;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = url?.trim() ?? '';
    final background = backgroundColor ?? NileColors.surfaceVariant;

    final child = resolvedUrl.isEmpty
        ? _State(icon: placeholderIcon)
        : CachedNetworkImage(
            imageUrl: resolvedUrl,
            fit: fit,
            alignment: alignment,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: memCacheWidth,
            memCacheHeight: memCacheHeight,
            fadeInDuration: const Duration(milliseconds: 120),
            placeholder: (_, __) => const _Loading(),
            errorWidget: (_, __, ___) => _State(icon: errorIcon),
          );

    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: background,
        child: Semantics(
          image: true,
          label: semanticLabel,
          child: child,
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _State extends StatelessWidget {
  const _State({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        icon,
        color: NileColors.textTertiary,
        size: 32,
      ),
    );
  }
}
