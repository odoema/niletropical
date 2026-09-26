import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shared image frame for the admin console.
///
/// The frame keeps image geometry stable across desktop/tablet/mobile while
/// allowing each image type to choose its semantic fit:
/// - cover: banners, media thumbnails, catalogue previews
/// - contain: product-packaging inspection where cropping would hide detail
class AdminImageFrame extends StatelessWidget {
  const AdminImageFrame({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.aspectRatio = 1,
    this.borderRadius = 12,
    this.backgroundColor,
    this.fallbackIcon = Icons.image_outlined,
    this.label,
  });

  final String? url;
  final BoxFit fit;
  final double aspectRatio;
  final double borderRadius;
  final Color? backgroundColor;
  final IconData fallbackIcon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = url?.trim() ?? '';

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: ColoredBox(
          color: backgroundColor ?? NileColors.surfaceVariant,
          child: resolvedUrl.isEmpty
              ? _Fallback(icon: fallbackIcon, label: label)
              : Image.network(
                  resolvedUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: fit,
                  alignment: Alignment.center,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) =>
                      _Fallback(icon: Icons.broken_image_outlined, label: label),
                ),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: NileColors.textTertiary),
          if (label != null) ...[
            const SizedBox(height: 6),
            Text(
              label!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: NileTypography.bodySmall.copyWith(
                color: NileColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
