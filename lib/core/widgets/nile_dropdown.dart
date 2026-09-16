/// Nile dropdown / select
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NileDropdown<T> extends StatelessWidget {
  const NileDropdown({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.label,
    this.hint,
    this.validator,
  });

  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      style: NileTypography.bodyLarge,
      dropdownColor: NileColors.surface,
      borderRadius: NileRadius.borderMd,
    );
  }
}
