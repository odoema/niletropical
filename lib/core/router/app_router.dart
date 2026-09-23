/// Nile Tropical - App Router (§42 nav map)
/// Copyright © Hon. Dr. Betty Udongo Pacutho

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/shell/customer_shell.dart';
import '../../features/shell/admin_shell.dart';
import '../../features/shell/courier_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/shop/shop_screen.dart';
import '../../features/shop/category_screen.dart';
import '../../features/content/faq_screen.dart';
import '../../features/content/cms_page_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/checkout/order_confirmation_screen.dart';
import '../../features/product/product_detail_screen.dart';
import '../../features/tracking/tracking_screen.dart';
import '../../features/account/account_screen.dart';
import '../../features/account/orders_screen.dart';
import '../../features/account/addresses_screen.dart';
import '../../features/payments/payment_page.dart';
import '../../features/courier/courier_dashboard_screen.dart';
import '../../features/courier/shipment_detail_screen.dart';
import '../../features/design_system/design_system_showcase.dart';
import '../../admin/admin_home_screen.dart';
import '../../admin/inventory/inventory_dashboard_screen.dart';
import '../../admin/inventory/stock_adjustment_screen.dart';
import '../../admin/products/product_list_screen.dart';
import '../../admin/products/product_form_screen.dart';
import '../../admin/products/product_image_manager_screen.dart';
import '../../admin/delivery/delivery_dashboard_screen.dart';
import '../../admin/orders/order_list_screen.dart';
import '../../admin/orders/order_detail_screen.dart';
import '../../admin/orders/proof_of_delivery_screen.dart';
import '../../admin/reports/reports_screen.dart';
import '../../admin/cms/cms_dashboard_screen.dart';
import '../../admin/cms/cms_collection_screen.dart';
import '../../admin/auth/admin_login_screen.dart';
import '../../admin/auth/admin_reset_password_screen.dart';
import '../../admin/cms/cms_banners_screen.dart';
import '../../admin/cms/cms_media_library_screen.dart';
import '../../admin/cms/cms_website_slots_screen.dart';
import '../../admin/customers/customers_screen.dart';
import '../../admin/customers/customer_detail_screen.dart';
import '../../admin/finance/cod_reconciliation_screen.dart';
import '../../admin/pricing/pricing_recommendations_screen.dart';
import '../../admin/notifications/notifications_admin_screen.dart';
import '../../admin/audit/audit_log_screen.dart';
import '../../admin/settings/admin_settings_screen.dart';
import '../../shared/services/auth_service.dart';
import '../../core/config/env.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    // Dismiss any lingering SnackBar on every navigation (tab switch, back
    // button, deep link, etc.) since it's tied to the app's single global
    // ScaffoldMessenger and won't auto-clear just because the page changed.
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    }
    final loc = state.uri.path;
    final isAdmin = loc.startsWith('/admin') &&
        loc != '/admin/login' &&
        loc != '/admin/reset-password';
    final isCourier = loc.startsWith('/courier');
    if (!isAdmin && !isCourier) return null;
    if (!Env.isConfigured) return '/admin/login';
    if (!AuthService.isLoggedIn) return '/admin/login';
    final roles = await AuthService.rolesForCurrentUser();
    if (isCourier && !AuthService.canAccessCourier(roles)) return '/admin/login';
    if (isAdmin && !AuthService.canAccessAdmin(roles)) {
      if (AuthService.canAccessCourier(roles)) return '/courier';
      return '/admin/login';
    }
    return null;
  },
  routes: [
    // ── Customer shell ──────────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => CustomerShell(
        location: state.uri.toString(),
        child: child,
      ),
      routes: [
        GoRoute(path: '/', name: 'home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/shop', name: 'shop', builder: (_, __) => const ShopScreen()),
        GoRoute(
          path: '/category/:slug',
          name: 'category',
          builder: (context, state) =>
              CategoryScreen(slug: state.pathParameters['slug']!),
        ),
        GoRoute(path: '/faq', name: 'faq', builder: (_, __) => const FaqScreen()),
        GoRoute(
          path: '/pages/:slug',
          name: 'cms-page',
          builder: (context, state) =>
              CmsPageScreen(slug: state.pathParameters['slug']!),
        ),
        GoRoute(
          path: '/product/:slug',
          name: 'product',
          builder: (context, state) =>
              ProductDetailScreen(slug: state.pathParameters['slug']!),
        ),
        GoRoute(path: '/cart', name: 'cart', builder: (_, __) => const CartScreen()),
        GoRoute(path: '/checkout', name: 'checkout', builder: (_, __) => const CheckoutScreen()),
        GoRoute(
          path: '/confirmation',
          name: 'confirmation',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return OrderConfirmationScreen(
              orderNumber: extra['orderNumber'] as String? ?? 'NTI-XXXX-000000',
              total: (extra['total'] as num?)?.toDouble() ?? 0,
              paymentMethod: extra['paymentMethod'] as String? ?? 'mtn_momo',
            );
          },
        ),
        GoRoute(path: '/track', name: 'track', builder: (_, __) => const TrackingScreen()),
        GoRoute(
          path: '/track/:orderNumber',
          name: 'track-order',
          builder: (context, state) => TrackingScreen(
            orderNumber: state.pathParameters['orderNumber'],
          ),
        ),
        GoRoute(path: '/account', name: 'account', builder: (_, __) => const AccountScreen()),
        GoRoute(path: '/account/orders', name: 'account-orders', builder: (_, __) => const AccountOrdersScreen()),
        GoRoute(path: '/account/addresses', name: 'account-addresses', builder: (_, __) => const AccountAddressesScreen()),
        GoRoute(
          path: '/pay/:orderId',
          name: 'payment',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return PaymentPage(
              orderId: state.pathParameters['orderId']!,
              orderNumber: extra['orderNumber'] as String?,
              method: extra['paymentMethod'] as String?,
              phone: extra['phone'] as String?,
              total: (extra['total'] as num?)?.toDouble(),
            );
          },
        ),
      ],
    ),

    // ── Admin shell ─────────────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => AdminShell(
        location: state.uri.toString(),
        child: child,
      ),
      routes: [
        GoRoute(path: '/admin', name: 'admin', builder: (_, __) => const AdminHomeScreen()),
        GoRoute(path: '/admin/orders', name: 'admin-orders', builder: (_, __) => const AdminOrderListScreen()),
        GoRoute(
          path: '/admin/orders/:id',
          name: 'admin-order-detail',
          builder: (context, state) =>
              AdminOrderDetailScreen(orderId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/admin/orders/:id/pod',
          name: 'admin-pod',
          builder: (context, state) =>
              ProofOfDeliveryScreen(orderId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/admin/inventory', name: 'admin-inventory', builder: (_, __) => const InventoryDashboardScreen()),
        GoRoute(path: '/admin/inventory/adjust', name: 'admin-stock-adjust', builder: (_, __) => const StockAdjustmentScreen()),
        GoRoute(path: '/admin/products', name: 'admin-products', builder: (_, __) => const AdminProductListScreen()),
        GoRoute(path: '/admin/products/images', name: 'admin-product-images', builder: (_, __) => const ProductImageManagerScreen()),
        GoRoute(path: '/admin/products/new', name: 'admin-product-new', builder: (_, __) => const ProductFormScreen()),
        GoRoute(
          path: '/admin/products/:id',
          name: 'admin-product-edit',
          builder: (context, state) =>
              ProductFormScreen(productId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/admin/delivery', name: 'admin-delivery', builder: (_, __) => const DeliveryDashboardScreen()),
        // Gap #2 — Customers
        GoRoute(
          path: '/admin/customers',
          name: 'admin-customers',
          builder: (_, __) => const CustomersScreen(),
          routes: [
            GoRoute(
              path: ':id',
              name: 'admin-customer-detail',
              builder: (context, state) => CustomerDetailScreen(
                customerId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        // Gap #3 — COD Reconciliation
        GoRoute(
          path: '/admin/finance/cod',
          name: 'admin-cod',
          builder: (_, __) => const CodReconciliationScreen(),
        ),
        GoRoute(path: '/admin/cms', name: 'admin-cms', builder: (_, __) => const CmsDashboardScreen()),
        GoRoute(path: '/admin/cms/banners', builder: (_, __) => const CmsBannersScreen()),
        GoRoute(path: '/admin/cms/media', builder: (_, __) => const CmsMediaLibraryScreen()),
        GoRoute(path: '/admin/cms/website-slots', builder: (_, __) => const CmsWebsiteSlotsScreen()),
        GoRoute(path: '/admin/cms/pages', builder: (_, __) => const CmsCollectionScreen(title: 'Pages', table: 'pages', titleField: 'title', subtitleField: 'slug')),
        GoRoute(path: '/admin/cms/faqs', builder: (_, __) => const CmsCollectionScreen(title: 'FAQs', table: 'faqs', titleField: 'question', subtitleField: 'answer')),
        GoRoute(path: '/admin/cms/testimonials', builder: (_, __) => const CmsCollectionScreen(title: 'Testimonials', table: 'testimonials', titleField: 'customer_name', subtitleField: 'testimonial')),
        GoRoute(path: '/admin/cms/videos', builder: (_, __) => const CmsCollectionScreen(title: 'Videos', table: 'videos', titleField: 'title', subtitleField: 'storage_path')),
        GoRoute(path: '/admin/cms/promotions', builder: (_, __) => const CmsCollectionScreen(title: 'Promotions', table: 'promotions', titleField: 'name', subtitleField: 'description')),
        GoRoute(path: '/admin/reports', name: 'admin-reports', builder: (_, __) => const ReportsScreen()),
        GoRoute(path: '/admin/pricing', name: 'admin-pricing', builder: (_, __) => const PricingRecommendationsScreen()),
        GoRoute(path: '/admin/notifications', name: 'admin-notifications', builder: (_, __) => const NotificationsAdminScreen()),
        GoRoute(path: '/admin/audit', name: 'admin-audit', builder: (_, __) => const AuditLogScreen()),
        GoRoute(path: '/admin/settings', name: 'admin-settings', builder: (_, __) => const AdminSettingsScreen()),
      ],
    ),

    // ── Courier shell ───────────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => CourierShell(
        location: state.uri.toString(),
        child: child,
      ),
      routes: [
        GoRoute(path: '/courier', name: 'courier', builder: (_, __) => const CourierDashboardScreen()),
        GoRoute(path: '/courier/history', name: 'courier-history', builder: (_, __) => const CourierDashboardScreen(history: true)),
        GoRoute(
          path: '/courier/shipment/:id',
          name: 'courier-shipment',
          builder: (context, state) =>
              CourierShipmentDetailScreen(shipmentId: state.pathParameters['id']!),
        ),
      ],
    ),

    // ── Auth / standalone ───────────────────────────────────────────────
    GoRoute(path: '/admin/login', name: 'admin-login', builder: (_, __) => const AdminLoginScreen()),
    GoRoute(
      path: '/admin/reset-password',
      name: 'admin-reset-password',
      builder: (_, __) => const AdminResetPasswordScreen(),
    ),
    GoRoute(
      path: '/design-system',
      name: 'design-system',
      builder: (_, __) => const DesignSystemShowcase(),
    ),
  ],
);
