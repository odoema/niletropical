/// Nile Tropical - Stock Adjustment Screen
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/inventory.dart';
import '../../shared/services/inventory_service.dart';
import '../../shared/providers/product_provider.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedVariantId;
  StockMovementType _type = StockMovementType.adjustment;
  bool _saving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVariantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product variant')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      int qty = int.parse(_quantityController.text);
      // For outbound movements, ensure quantity is negative
      if (_type == StockMovementType.sale ||
          _type == StockMovementType.damage ||
          _type == StockMovementType.expiry) {
        qty = -qty.abs();
      } else if (_type == StockMovementType.purchase ||
          _type == StockMovementType.return_ ||
          _type == StockMovementType.opening) {
        qty = qty.abs();
      }

      await InventoryService.recordMovement(
        productVariantId: _selectedVariantId!,
        type: _type,
        quantity: qty,
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock movement recorded'),
            backgroundColor: NileColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: NileColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Adjustment'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Record a stock movement',
              style: TextStyle(fontSize: 16, color: NileColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // Movement type
            DropdownButtonFormField<StockMovementType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Movement Type *'),
              items: StockMovementType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.label),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),

            // Product variant selector
            productsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Could not load products'),
              data: (products) {
                final variants = <DropdownMenuItem<String>>[];
                for (final p in products) {
                  for (final v in p.variants) {
                    variants.add(DropdownMenuItem(
                      value: v.id,
                      child: Text('${p.name} – ${v.name} (Stock: ${v.stockQuantity})'),
                    ));
                  }
                }
                return DropdownButtonFormField<String>(
                  value: _selectedVariantId,
                  decoration: const InputDecoration(labelText: 'Product Variant *'),
                  items: variants,
                  onChanged: (v) => setState(() => _selectedVariantId = v),
                  validator: (v) => v == null ? 'Required' : null,
                );
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity *',
                helperText: 'Enter positive number. Direction is handled by movement type.',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (int.tryParse(v) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: 'Reference (Order No / PO No)',
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Record Movement'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _saving ? null : () => context.pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
