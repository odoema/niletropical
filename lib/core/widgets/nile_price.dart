/// Formatted UGX price display
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';

class NilePrice extends StatelessWidget {
  const NilePrice({
    super.key,
    required this.amount,
    this.style,
    this.showCurrency = true,
    this.strikeThrough = false,
  });

  final num amount;
  final TextStyle? style;
  final bool showCurrency;
  final bool strikeThrough;

  static final _fmt = NumberFormat('#,##0', 'en_UG');

  @override
  Widget build(BuildContext context) {
    final text = showCurrency
        ? '${AppConstants.currencySymbol}${_fmt.format(amount)}'
        : _fmt.format(amount);
    final base = style ?? NileTypography.titleMedium;
    return Text(
      text,
      style: strikeThrough
          ? base.copyWith(
              decoration: TextDecoration.lineThrough,
              color: NileColors.textTertiary,
            )
          : base.copyWith(color: NileColors.primary, fontWeight: FontWeight.w700),
    );
  }
}
