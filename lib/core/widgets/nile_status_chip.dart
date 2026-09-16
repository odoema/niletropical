/// Order / shipment status chip
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NileStatusChip extends StatelessWidget {
  const NileStatusChip({
    super.key,
    required this.status,
  });

  final String status;

  static const _map = {
    'pending': (NileColors.warningContainer, NileColors.warning),
    'confirmed': (NileColors.infoContainer, NileColors.info),
    'processing': (NileColors.primaryContainer, NileColors.primary),
    'shipped': (NileColors.primaryContainer, NileColors.primary),
    'out_for_delivery': (NileColors.infoContainer, NileColors.info),
    'delivered': (NileColors.successContainer, NileColors.success),
    'cancelled': (NileColors.errorContainer, NileColors.error),
    'failed': (NileColors.errorContainer, NileColors.error),
    'paid': (NileColors.successContainer, NileColors.success),
    'unpaid': (NileColors.warningContainer, NileColors.warning),
  };

  @override
  Widget build(BuildContext context) {
    final key = status.toLowerCase().replaceAll(' ', '_');
    final colors = _map[key] ?? (NileColors.surfaceVariant, NileColors.textSecondary);
    final label = status.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: NileRadius.borderSm,
      ),
      child: Text(
        label,
        style: NileTypography.labelMedium.copyWith(
          color: colors.$2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
