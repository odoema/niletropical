/// Nile Tropical - Customer Addresses
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/config/env.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/auth_service.dart';

class AccountAddressesScreen extends StatefulWidget {
  const AccountAddressesScreen({super.key});

  @override
  State<AccountAddressesScreen> createState() => _AccountAddressesScreenState();
}

class _AccountAddressesScreenState extends State<AccountAddressesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Look up the customers row by user_id (the live production customer identity), NOT by email — email is optional on customers
  /// and unindexed, and matching on auth_user_id makes RLS work.
  Future<Map<String, dynamic>?> _findCustomer() async {
    return await SupabaseService.client
        .from('customers')
        .select('id, full_name, phone, email')
        .eq('user_id', AuthService.user!.id)
        .maybeSingle();
  }

  Future<void> _load() async {
    if (!Env.isConfigured || AuthService.user == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in to manage addresses.';
      });
      return;
    }
    try {
      final customer = await _findCustomer();
      if (customer == null) {
        setState(() {
          _loading = false;
          _rows = const [];
        });
        return;
      }
      final rows = await SupabaseService.client
          .from('customer_addresses')
          .select()
          .eq('customer_id', customer['id']);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _add() async {
    if (!Env.isConfigured || AuthService.user == null) return;

    final fullName = TextEditingController();
    final phone = TextEditingController();
    final city = TextEditingController();
    final line = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // If the customer row already exists, pre-fill name/phone from it and
    // hide those fields — they're not per-address.
    final existing = await _findCustomer();
    final needsProfile = existing == null;
    if (existing != null) {
      fullName.text = existing['full_name']?.toString() ?? '';
      phone.text = existing['phone']?.toString() ?? '';
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add address'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (needsProfile) ...[
                  TextFormField(
                    controller: fullName,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone (e.g. +2567…)',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().length < 9)
                        ? 'Enter a real phone number'
                        : null,
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: city,
                  decoration:
                      const InputDecoration(labelText: 'City / area'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: line,
                  decoration:
                      const InputDecoration(labelText: 'Address line'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // Insert a customer row if needed. Setting user_id is essential
      // — RLS on customer_addresses joins on customers.user_id, so a
      // row without it is invisible on the next page load. We NEVER
      // fabricate a phone number: the dialog validation above already
      // required a real one when creating the profile.
      var customer = existing;
      customer ??= await SupabaseService.client
          .from('customers')
          .insert({
            'user_id': AuthService.user!.id,
            'full_name': fullName.text.trim(),
            'phone': phone.text.trim(),
            'email': AuthService.user!.email,
          })
          .select('id, full_name, phone, email')
          .single();

      await SupabaseService.client.from('customer_addresses').insert({
        'customer_id': customer['id'],
        'city_town': city.text.trim(),
        'address_line': line.text.trim(),
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save address: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NileAppBar(title: 'Addresses'),
      body: _loading
          ? const NileLoadingState()
          : _error != null
              ? NileEmptyState(title: 'Addresses', message: _error)
              : _rows.isEmpty
                  ? const NileEmptyState(
                      title: 'No saved addresses',
                      message: 'Add an address to reuse it at checkout.',
                      icon: Icons.location_on_outlined,
                    )
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (_, i) {
                        final a = _rows[i];
                        return ListTile(
                          title: Text(a['address_line']?.toString() ?? ''),
                          subtitle: Text(
                            '${a['city_town'] ?? ''}${a['is_default'] == true ? ' · default' : ''}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'default') {
                                await SupabaseService.client
                                    .from('customer_addresses')
                                    .update({'is_default': false})
                                    .eq('customer_id', a['customer_id']);
                                await SupabaseService.client
                                    .from('customer_addresses')
                                    .update({'is_default': true})
                                    .eq('id', a['id']);
                                await _load();
                              } else if (v == 'delete') {
                                await SupabaseService.client
                                    .from('customer_addresses')
                                    .delete()
                                    .eq('id', a['id']);
                                await _load();
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'default', child: Text('Set default')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
    );
  }
}
