import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/supabase_service.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});
  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Management'),
        bottom: const TabBar(isScrollable: true, tabs: [
          Tab(icon: Icon(Icons.category_outlined), text: 'Categories'),
          Tab(icon: Icon(Icons.local_offer_outlined), text: 'Coupons'),
          Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Delivery'),
        ]),
      ),
      body: TabBarView(controller: _tabs, children: const [
        _CategoriesTab(), _CouponsTab(), _DeliveryTab(),
      ]),
    );
  }
}

class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();
  @override State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() { loading = false; error = 'Supabase is not configured.'; }); return;
    }
    setState(() { loading = true; error = null; });
    try {
      final result = await SupabaseService.client.from('categories')
          .select('id,name,slug,sort_order,is_active').order('sort_order').order('name');
      if (!mounted) return;
      setState(() { rows = List<Map<String, dynamic>>.from(result); loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString(); });
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final slug = TextEditingController(text: row?['slug']?.toString() ?? '');
    final order = TextEditingController(text: row?['sort_order']?.toString() ?? '0');
    var active = row?['is_active'] != false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
        title: Text(row == null ? 'Add category' : 'Edit category'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug')),
          const SizedBox(height: 12),
          TextField(controller: order, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Display order')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active'), value: active, onChanged: (v) => setState(() => active = v)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: name.text.trim().isEmpty || slug.text.trim().isEmpty ? null : () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      )),
    );
    if (ok != true) { name.dispose(); slug.dispose(); order.dispose(); return; }
    try {
      final payload = {'name': name.text.trim(), 'slug': slug.text.trim().toLowerCase(),
        'sort_order': int.tryParse(order.text.trim()) ?? 0, 'is_active': active};
      if (row == null) await SupabaseService.client.from('categories').insert(payload);
      else await SupabaseService.client.from('categories').update(payload).eq('id', row['id']);
      await _load();
    } catch (e) { _snack(e); }
    finally { name.dispose(); slug.dispose(); order.dispose(); }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete category?'),
      content: const Text('Products remain but lose this category.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: NileColors.error),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok != true) return;
    try { await SupabaseService.client.from('categories').delete().eq('id', row['id']); await _load(); }
    catch (e) { _snack(e); }
  }

  void _snack(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Action failed: ' + e.toString()), backgroundColor: NileColors.error));
  }

  @override
  Widget build(BuildContext context) => _ManagementList(
    title: 'Product categories', loading: loading, error: error, onRefresh: _load,
    onAdd: () => _edit(), empty: 'No categories configured.',
    children: rows.map((row) => ListTile(
      leading: const CircleAvatar(child: Icon(Icons.category_outlined)),
      title: Text(row['name']?.toString() ?? 'Category'),
      subtitle: Text((row['slug']?.toString() ?? '') + ' • Order ' + (row['sort_order']?.toString() ?? '0')),
      trailing: Wrap(children: [
        Switch(value: row['is_active'] == true, onChanged: (_) => _edit(row)),
        IconButton(onPressed: () => _delete(row), icon: const Icon(Icons.delete_outline)),
      ]),
      onTap: () => _edit(row),
    )).toList(),
  );
}

class _CouponsTab extends StatefulWidget {
  const _CouponsTab();
  @override State<_CouponsTab> createState() => _CouponsTabState();
}

class _CouponsTabState extends State<_CouponsTab> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!Env.isConfigured) {
      setState(() { loading = false; error = 'Supabase is not configured.'; }); return;
    }
    setState(() { loading = true; error = null; });
    try {
      final result = await SupabaseService.client.from('coupons').select().order('created_at', ascending: false);
      if (!mounted) return;
      setState(() { rows = List<Map<String, dynamic>>.from(result); loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString(); });
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final code = TextEditingController(text: row?['code']?.toString() ?? '');
    final value = TextEditingController(text: row?['value']?.toString() ?? '');
    final maxUses = TextEditingController(text: row?['max_uses']?.toString() ?? '');
    var type = row?['discount_type']?.toString() ?? 'percentage';
    var active = row?['is_active'] != false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
        title: Text(row == null ? 'Add coupon' : 'Edit coupon'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: code, textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Coupon code')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: type, decoration: const InputDecoration(labelText: 'Discount type'),
            items: const [
              DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
              DropdownMenuItem(value: 'fixed_amount', child: Text('Fixed amount')),
            ],
            onChanged: (v) => setState(() => type = v ?? type),
          ),
          const SizedBox(height: 12),
          TextField(controller: value, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Value')),
          const SizedBox(height: 12),
          TextField(controller: maxUses, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Maximum uses (optional)')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active'),
            value: active, onChanged: (v) => setState(() => active = v)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: code.text.trim().isEmpty || double.tryParse(value.text.trim()) == null
                ? null : () => Navigator.pop(ctx, true),
            child: const Text('Save')),
        ],
      )),
    );
    if (ok != true) { code.dispose(); value.dispose(); maxUses.dispose(); return; }
    try {
      final payload = {'code': code.text.trim().toUpperCase(), 'discount_type': type,
        'value': double.parse(value.text.trim()),
        'max_uses': maxUses.text.trim().isEmpty ? null : int.tryParse(maxUses.text.trim()),
        'is_active': active};
      if (row == null) await SupabaseService.client.from('coupons').insert(payload);
      else await SupabaseService.client.from('coupons').update(payload).eq('id', row['id']);
      await _load();
    } catch (e) { _snack(e); }
    finally { code.dispose(); value.dispose(); maxUses.dispose(); }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete coupon?'),
      content: Text('Delete ' + (row['code']?.toString() ?? 'coupon') + '?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: NileColors.error),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok != true) return;
    try { await SupabaseService.client.from('coupons').delete().eq('id', row['id']); await _load(); }
    catch (e) { _snack(e); }
  }

  void _snack(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Action failed: ' + e.toString()), backgroundColor: NileColors.error));
  }

  @override
  Widget build(BuildContext context) => _ManagementList(
    title: 'Coupons', loading: loading, error: error, onRefresh: _load, onAdd: () => _edit(),
    empty: 'No coupons configured.',
    children: rows.map((row) {
      final discount = row['discount_type']?.toString() == 'percentage'
          ? (row['value']?.toString() ?? '0') + '%'
          : 'UGX ' + (row['value']?.toString() ?? '0');
      final usage = 'Used ' + (row['used_count']?.toString() ?? '0') +
          (row['max_uses'] == null ? '' : ' / ' + row['max_uses'].toString());
      return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.local_offer_outlined)),
        title: Text(row['code']?.toString() ?? 'Coupon'),
        subtitle: Text(discount + ' • ' + usage),
        trailing: Wrap(children: [
          Chip(label: Text(row['is_active'] == true ? 'Active' : 'Inactive')),
          IconButton(onPressed: () => _delete(row), icon: const Icon(Icons.delete_outline)),
        ]),
        onTap: () => _edit(row),
      );
    }).toList(),
  );
}

class _DeliveryTab extends StatelessWidget {
  const _DeliveryTab();
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(children: const [
      TabBar(tabs: [Tab(text: 'Zones'), Tab(text: 'Partners'), Tab(text: 'Couriers')]),
      Expanded(child: TabBarView(children: [_DeliveryZonesTab(), _PartnersTab(), _CouriersTab()])),
    ]),
  );
}

class _DeliveryZonesTab extends _SimpleTableTab {
  const _DeliveryZonesTab();
  @override State<_SimpleTableTab> createState() => _DeliveryZonesState();
}

class _DeliveryZonesState extends _SimpleTableState {
  @override String get title => 'Delivery zones';
  @override String get table => 'delivery_zones';
  @override List<String> get columns => const ['name', 'delivery_fee', 'estimated_days', 'is_active'];

  @override Future<void> create() async {
    final form = await _zoneForm(context);
    if (form == null) return;
    try {
      await SupabaseService.client.rpc('admin_create_delivery_zone', params: {
        'p_name': form['name'], 'p_delivery_fee': form['delivery_fee'],
        'p_estimated_days': form['estimated_days'], 'p_notes': form['notes'],
      });
      await load();
    } catch (e) { snack(e); }
  }

  @override Future<void> editRow(Map<String, dynamic> row) async {
    final form = await _zoneForm(context, row);
    if (form == null) return;
    try { await SupabaseService.client.from(table).update(form).eq('id', row['id']); await load(); }
    catch (e) { snack(e); }
  }
}

class _PartnersTab extends _SimpleTableTab {
  const _PartnersTab();
  @override State<_SimpleTableTab> createState() => _PartnersState();
}

class _PartnersState extends _SimpleTableState {
  @override String get title => 'Delivery partners';
  @override String get table => 'delivery_partners';
  @override List<String> get columns => const ['name', 'type', 'phone', 'is_active'];

  @override Future<void> create() => _partnerEdit();
  @override Future<void> editRow(Map<String, dynamic> row) => _partnerEdit(row);

  Future<void> _partnerEdit([Map<String, dynamic>? row]) async {
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final phone = TextEditingController(text: row?['phone']?.toString() ?? '');
    final contact = TextEditingController(text: row?['contact_person']?.toString() ?? '');
    final terminal = TextEditingController(text: row?['terminal']?.toString() ?? '');
    var type = row?['type']?.toString() ?? 'other';
    var active = row?['is_active'] != false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
        title: Text(row == null ? 'Add delivery partner' : 'Edit delivery partner'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          DropdownButtonFormField<String>(
            initialValue: type, decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'bus', child: Text('Bus')),
              DropdownMenuItem(value: 'taxi', child: Text('Taxi')),
              DropdownMenuItem(value: 'courier_company', child: Text('Courier company')),
              DropdownMenuItem(value: 'boda', child: Text('Boda')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => type = v ?? type),
          ),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact person')),
          TextField(controller: terminal, decoration: const InputDecoration(labelText: 'Terminal / office')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active'),
            value: active, onChanged: (v) => setState(() => active = v)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: name.text.trim().isEmpty ? null : () => Navigator.pop(ctx, true),
            child: const Text('Save')),
        ],
      )),
    );
    if (ok != true) return;
    try {
      final payload = {'name': name.text.trim(), 'type': type,
        'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
        'contact_person': contact.text.trim().isEmpty ? null : contact.text.trim(),
        'terminal': terminal.text.trim().isEmpty ? null : terminal.text.trim(),
        'is_active': active};
      if (row == null) await SupabaseService.client.from(table).insert(payload);
      else await SupabaseService.client.from(table).update(payload).eq('id', row['id']);
      await load();
    } catch (e) { snack(e); }
    finally { name.dispose(); phone.dispose(); contact.dispose(); terminal.dispose(); }
  }
}

class _CouriersTab extends _SimpleTableTab {
  const _CouriersTab();
  @override State<_SimpleTableTab> createState() => _CouriersState();
}

class _CouriersState extends _SimpleTableState {
  @override String get title => 'Couriers';
  @override String get table => 'couriers';
  @override List<String> get columns => const ['full_name', 'phone', 'vehicle_type', 'operating_area', 'is_active'];

  @override Future<void> create() => _courierEdit();
  @override Future<void> editRow(Map<String, dynamic> row) => _courierEdit(row);

  Future<void> _courierEdit([Map<String, dynamic>? row]) async {
    final name = TextEditingController(text: row?['full_name']?.toString() ?? '');
    final phone = TextEditingController(text: row?['phone']?.toString() ?? '');
    final vehicle = TextEditingController(text: row?['vehicle_type']?.toString() ?? '');
    final area = TextEditingController(text: row?['operating_area']?.toString() ?? '');
    final commission = TextEditingController(text: row?['commission_rate']?.toString() ?? '');
    var active = row?['is_active'] != false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
        title: Text(row == null ? 'Add courier' : 'Edit courier'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          TextField(controller: vehicle, decoration: const InputDecoration(labelText: 'Vehicle type')),
          TextField(controller: area, decoration: const InputDecoration(labelText: 'Operating area')),
          TextField(controller: commission, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Commission %')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active'),
            value: active, onChanged: (v) => setState(() => active = v)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: name.text.trim().isEmpty || phone.text.trim().isEmpty ? null : () => Navigator.pop(ctx, true),
            child: const Text('Save')),
        ],
      )),
    );
    if (ok != true) return;
    try {
      final payload = {'full_name': name.text.trim(), 'phone': phone.text.trim(),
        'vehicle_type': vehicle.text.trim().isEmpty ? null : vehicle.text.trim(),
        'operating_area': area.text.trim().isEmpty ? null : area.text.trim(),
        'commission_rate': commission.text.trim().isEmpty ? null : double.tryParse(commission.text.trim()),
        'is_active': active};
      if (row == null) {
        await SupabaseService.client.rpc('admin_create_courier', params: {
          'p_full_name': payload['full_name'], 'p_phone': payload['phone'],
          'p_vehicle_type': payload['vehicle_type'], 'p_operating_area': payload['operating_area'],
          'p_commission_rate': payload['commission_rate'],
        });
      } else {
        await SupabaseService.client.from(table).update(payload).eq('id', row['id']);
      }
      await load();
    } catch (e) { snack(e); }
    finally { name.dispose(); phone.dispose(); vehicle.dispose(); area.dispose(); commission.dispose(); }
  }
}

abstract class _SimpleTableTab extends StatefulWidget {
  const _SimpleTableTab();
}

abstract class _SimpleTableState<T extends _SimpleTableTab> extends State<T> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = [];

  String get title;
  String get table;
  List<String> get columns;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    if (!Env.isConfigured) {
      setState(() { loading = false; error = 'Supabase is not configured.'; }); return;
    }
    setState(() { loading = true; error = null; });
    try {
      final result = await SupabaseService.client.from(table).select().order('created_at', ascending: false);
      if (!mounted) return;
      setState(() { rows = List<Map<String, dynamic>>.from(result); loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString(); });
    }
  }

  Future<void> create();
  Future<void> editRow(Map<String, dynamic> row);

  Future<void> remove(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Delete ' + title.toLowerCase() + '?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: NileColors.error),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok != true) return;
    try { await SupabaseService.client.from(table).delete().eq('id', row['id']); await load(); }
    catch (e) { snack(e); }
  }

  void snack(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Action failed: ' + e.toString()), backgroundColor: NileColors.error));
  }

  String display(Map<String, dynamic> row, String key) {
    final value = row[key];
    return value == null || value.toString().isEmpty ? '—' : value.toString();
  }

  @override
  Widget build(BuildContext context) => _ManagementList(
    title: title, loading: loading, error: error, onRefresh: load, onAdd: create,
    empty: 'No ' + title.toLowerCase() + ' configured.',
    children: rows.map((row) {
      final primary = display(row, columns.first);
      final details = columns.skip(1).take(3).map((key) => display(row, key)).join(' • ');
      return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
        title: Text(primary),
        subtitle: Text(details),
        trailing: Wrap(children: [
          if (row.containsKey('is_active')) Chip(label: Text(row['is_active'] == true ? 'Active' : 'Inactive')),
          IconButton(onPressed: () => remove(row), icon: const Icon(Icons.delete_outline)),
        ]),
        onTap: () => editRow(row),
      );
    }).toList(),
  );
}

class _ManagementList extends StatelessWidget {
  const _ManagementList({
    required this.title, required this.loading, required this.error,
    required this.onRefresh, required this.onAdd, required this.empty, required this.children,
  });

  final String title;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(children: [
        Expanded(child: Text(title, style: NileTypography.titleLarge)),
        FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add')),
        const SizedBox(width: 8),
        IconButton(onPressed: loading ? null : onRefresh, icon: const Icon(Icons.refresh)),
      ]),
    ),
    Expanded(
      child: loading ? const NileLoadingState() :
        error != null ? NileErrorState(message: error!, onRetry: onRefresh) :
        children.isEmpty ? NileEmptyState(title: title, message: empty) :
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: children.length,
          separatorBuilder: (_, index) => const SizedBox(height: 8),
          itemBuilder: (_, index) => Card(child: children[index]),
        ),
    ),
  ]);
}

Future<Map<String, dynamic>?> _zoneForm(BuildContext context, [Map<String, dynamic>? row]) async {
  final name = TextEditingController(text: row?['name']?.toString() ?? '');
  final fee = TextEditingController(text: row?['delivery_fee']?.toString() ?? '');
  final days = TextEditingController(text: row?['estimated_days']?.toString() ?? '');
  final notes = TextEditingController(text: row?['notes']?.toString() ?? '');
  var active = row?['is_active'] != false;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
      title: Text(row == null ? 'Add delivery zone' : 'Edit delivery zone'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Zone name')),
        TextField(controller: fee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Delivery fee (UGX)')),
        TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estimated days')),
        TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active'), value: active, onChanged: (v) => setState(() => active = v)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: name.text.trim().isEmpty || double.tryParse(fee.text.trim()) == null
              ? null : () => Navigator.pop(ctx, true),
          child: const Text('Save')),
      ],
    )),
  );
  if (ok != true) {
    name.dispose(); fee.dispose(); days.dispose(); notes.dispose(); return null;
  }
  final result = {
    'name': name.text.trim(),
    'delivery_fee': double.parse(fee.text.trim()),
    'estimated_days': int.tryParse(days.text.trim()),
    'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
    'is_active': active,
  };
  name.dispose(); fee.dispose(); days.dispose(); notes.dispose();
  return result;
}
