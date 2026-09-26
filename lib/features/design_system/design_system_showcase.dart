/// Dev-only design system showcase — gated behind allowMockData / debug.
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';

class DesignSystemShowcase extends StatelessWidget {
  const DesignSystemShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NileAppBar(title: 'Nile Design System'),
      body: ListView(
        padding: const EdgeInsets.all(NileSpacing.md),
        children: [
          Text('Colors', style: NileTypography.headlineMedium),
          const SizedBox(height: NileSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _swatch('Primary', NileColors.primary),
              _swatch('Primary Light', NileColors.primaryLight),
              _swatch('Secondary', NileColors.secondary),
              _swatch('Accent', NileColors.accent),
              _swatch('Success', NileColors.success),
              _swatch('Warning', NileColors.warning),
              _swatch('Error', NileColors.error),
              _swatch('Info', NileColors.info),
            ],
          ),
          const SizedBox(height: NileSpacing.lg),
          Text('Typography', style: NileTypography.headlineMedium),
          const SizedBox(height: NileSpacing.sm),
          Text('Display Large', style: NileTypography.displayLarge),
          Text('Headline Medium', style: NileTypography.headlineMedium),
          Text('Title Large', style: NileTypography.titleLarge),
          Text('Body Large', style: NileTypography.bodyLarge),
          Text('Body Medium', style: NileTypography.bodyMedium),
          Text('Caption', style: NileTypography.caption),
          Text('Button', style: NileTypography.button),
          const SizedBox(height: NileSpacing.lg),
          Text('Buttons', style: NileTypography.headlineMedium),
          const SizedBox(height: NileSpacing.sm),
          NileButton(label: 'Primary Button', onPressed: () {}),
          const SizedBox(height: NileSpacing.sm),
          NileButton(label: 'Loading', loading: true, onPressed: () {}),
          const SizedBox(height: NileSpacing.sm),
          NileOutlinedButton(label: 'Outlined Button', onPressed: () {}),
          const SizedBox(height: NileSpacing.sm),
          NileButton(
            label: 'With Icon',
            icon: Icons.shopping_cart,
            onPressed: () {},
            fullWidth: false,
          ),
          const SizedBox(height: NileSpacing.lg),
          Text('Inputs', style: NileTypography.headlineMedium),
          const SizedBox(height: NileSpacing.sm),
          const NileTextField(label: 'Full name', hint: 'Enter your name'),
          const SizedBox(height: NileSpacing.sm),
          NileSearchField(hint: 'Search products…'),
          const SizedBox(height: NileSpacing.sm),
          NileDropdown<String>(
            label: 'District',
            hint: 'Select district',
            items: const [
              DropdownMenuItem(value: 'nebbi', child: Text('Nebbi')),
              DropdownMenuItem(value: 'kampala', child: Text('Kampala')),
            ],
            onChanged: (_) {},
          ),
          const SizedBox(height: NileSpacing.lg),
          Text('Cards & Price', style: NileTypography.headlineMedium),
          const SizedBox(height: NileSpacing.sm),
          NileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shea Butter 250g', style: NileTypography.titleMedium),
                const SizedBox(height: 4),
                const NilePrice(amount: 25000),
                const SizedBox(height: 4),
                const NilePrice(amount: 30000, strikeThrough: true),
              ],
            ),
          ),
          const SizedBox(height: NileSpacing.lg),
          Text('Badges & Status', style: NileTypography.headlineMedium),
          const SizedBox(height: NileSpacing.sm),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              NileBadge(label: 'New'),
              NileBadge(label: 'In stock', variant: NileBadgeVariant.success),
              NileBadge(label: 'Low stock', variant: NileBadgeVariant.warning),
              NileBadge(label: 'Out of stock', variant: NileBadgeVariant.error),
              NileStatusChip(status: 'pending'),
              NileStatusChip(status: 'delivered'),
              NileStatusChip(status: 'cancelled'),
            ],
          ),
          const SizedBox(height: NileSpacing.lg),
          Text('Section header', style: NileTypography.headlineMedium),
          NileSectionHeader(
            title: 'Featured products',
            actionLabel: 'See all',
            onAction: () {},
          ),
          const SizedBox(height: NileSpacing.lg),
          Text('States', style: NileTypography.headlineMedium),
          const SizedBox(
            height: 160,
            child: NileEmptyState(
              title: 'Your cart is empty',
              message: 'Browse the shop to add products.',
              actionLabel: 'Go to shop',
            ),
          ),
          const SizedBox(
            height: 160,
            child: NileErrorState(
              message: 'Could not load orders.',
            ),
          ),
          const SizedBox(
            height: 100,
            child: NileLoadingState(message: 'Loading…'),
          ),
          const SizedBox(height: NileSpacing.lg),
          Text('Experience & use-case states', style: NileTypography.headlineMedium),
          const SizedBox(height: NileSpacing.sm),
          Text(
            'Every production screen should reuse these patterns for loading, empty, success, warning, error, payment, order, tracking and access states.',
            style: NileTypography.bodySmall,
          ),
          const SizedBox(height: NileSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              NileBadge(label: 'Loading'),
              NileBadge(label: 'Success', variant: NileBadgeVariant.success),
              NileBadge(label: 'Warning', variant: NileBadgeVariant.warning),
              NileBadge(label: 'Error', variant: NileBadgeVariant.error),
              NileBadge(label: 'Offline'),
              NileBadge(label: 'Unauthorized'),
              NileStatusChip(status: 'payment_pending'),
              NileStatusChip(status: 'new_order'),
              NileStatusChip(status: 'dispatched'),
              NileStatusChip(status: 'out_for_delivery'),
              NileStatusChip(status: 'delivered'),
              NileStatusChip(status: 'cancelled'),
            ],
          ),
          const SizedBox(height: NileSpacing.sm),
          NileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Production scenarios', style: NileTypography.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Authentication: login, signup, OTP, reset, expired session',
                  style: NileTypography.bodySmall,
                ),
                Text(
                  'Commerce: browse, search, product, cart, checkout, payment success/failure',
                  style: NileTypography.bodySmall,
                ),
                Text(
                  'Orders: received, confirmed, processing, dispatched, out for delivery, delivered, cancelled',
                  style: NileTypography.bodySmall,
                ),
                Text(
                  'Tracking: loading, found, not found, invalid details, shipment updates',
                  style: NileTypography.bodySmall,
                ),
                Text(
                  'Operations: inventory, delivery, customers, finance, analytics, notifications',
                  style: NileTypography.bodySmall,
                ),
                Text(
                  'Resilience: slow network, offline, retry, empty data, server error, permission denied',
                  style: NileTypography.bodySmall,
                ),
                Text(
                  'Responsive: mobile, tablet and desktop layouts with accessible touch targets and readable text',
                  style: NileTypography.bodySmall,
                ),
                Text(
                  'Communication: branded email, push and future WhatsApp notification states',
                  style: NileTypography.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: NileSpacing.lg),
          Text('Data table', style: NileTypography.headlineMedium),
          NileDataTable(
            columns: const [
              NileDataColumn(label: 'Order', flex: 2),
              NileDataColumn(label: 'Status'),
              NileDataColumn(label: 'Total'),
            ],
            rows: [
              NileDataRow(
                cells: [
                  Text('NTI-1001', style: NileTypography.bodyMedium),
                  const NileStatusChip(status: 'delivered'),
                  const NilePrice(amount: 45000),
                ],
              ),
              NileDataRow(
                cells: [
                  Text('NTI-1002', style: NileTypography.bodyMedium),
                  const NileStatusChip(status: 'pending'),
                  const NilePrice(amount: 12000),
                ],
              ),
            ],
          ),
          const SizedBox(height: NileSpacing.xxl),
        ],
      ),
    );
  }

  Widget _swatch(String name, Color color) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: NileRadius.borderSm,
            border: Border.all(color: NileColors.border),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, style: NileTypography.caption),
      ],
    );
  }
}
