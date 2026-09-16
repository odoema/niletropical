/// Search input with clear
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NileSearchField extends StatefulWidget {
  const NileSearchField({
    super.key,
    this.controller,
    this.hint = 'Search…',
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<NileSearchField> createState() => _NileSearchFieldState();
}

class _NileSearchFieldState extends State<NileSearchField> {
  late final TextEditingController _controller;
  bool _owned = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _owned = true;
    }
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (_owned) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: NileTypography.bodyLarge,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search, color: NileColors.textTertiary),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged?.call('');
                },
              )
            : null,
        filled: true,
        fillColor: NileColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: NileRadius.borderFull,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: NileRadius.borderFull,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: NileRadius.borderFull,
          borderSide: const BorderSide(color: NileColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
