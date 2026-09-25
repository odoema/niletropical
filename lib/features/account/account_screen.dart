import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/supabase_service.dart';
import '../../shared/services/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _googleBusy = false;

  User? get _user => AuthService.user;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        AuthService.isConfigured
            ? SupabaseServiceListener.listen((_) {
                if (mounted) setState(() {});
              })
            : null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() => _googleBusy = true);
    try {
      await AuthService.signInWithGoogle();
      // OAuth redirects away from the page on web. This also runs after
      // returning from the provider on platforms that resume in-app.
      await AuthService.linkExistingCustomer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
      setState(() => _googleBusy = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final email = user?.email ?? '';
    final name =
        user?.userMetadata?['full_name']?.toString() ??
        user?.userMetadata?['name']?.toString() ??
        (email.isNotEmpty ? email.split('@').first : 'Customer');

    return Scaffold(
      appBar: const NileAppBar(title: 'Account'),
      body: ListView(
        padding: const EdgeInsets.all(NileSpacing.md),
        children: [
          NileCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: NileColors.primaryContainer,
                  child: Icon(
                    user == null ? Icons.person_outline : Icons.person,
                    color: NileColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: NileSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user == null ? 'Guest' : name,
                        style: NileTypography.titleLarge,
                      ),
                      Text(
                        user == null
                            ? 'Sign in to sync orders & addresses'
                            : email,
                        style: NileTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NileSpacing.md),

          if (user == null) ...[
            NileButton(
              label: _googleBusy ? 'Connecting to Google…' : 'Continue with Google',
              loading: _googleBusy,
              onPressed: _googleBusy ? null : _googleSignIn,
              icon: Icons.login,
            ),
            const SizedBox(height: NileSpacing.sm),
            Text(
              'Use your Google account to identify your account and receive free order updates on this device.',
              style: NileTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NileSpacing.md),
          ] else ...[
            NileCard(
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Signed in with Google. Your email identifies this customer account.',
                      style: NileTypography.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NileSpacing.sm),
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: NileSpacing.md),
          ],

          _tile(context, Icons.receipt_long_outlined, 'My orders', '/account/orders'),
          _tile(context, Icons.location_on_outlined, 'Addresses', '/account/addresses'),
          _tile(context, Icons.local_shipping_outlined, 'Track order', '/track'),
          _tile(context, Icons.help_outline, 'FAQs', '/faq'),
          _tile(context, Icons.article_outlined, 'About', '/pages/about'),
          const Divider(height: 32),
          _tile(context, Icons.admin_panel_settings_outlined, 'Admin console', '/admin'),
          _tile(context, Icons.delivery_dining_outlined, 'Courier app', '/courier'),
          _tile(context, Icons.palette_outlined, 'Design system', '/design-system'),
          const SizedBox(height: NileSpacing.xl),
          Text(
            AppConstants.copyright,
            style: NileTypography.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon, color: NileColors.primary),
      title: Text(label, style: NileTypography.titleSmall),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
      shape: RoundedRectangleBorder(borderRadius: NileRadius.borderSm),
    );
  }
}

/// Small adapter so the Account screen doesn't keep a direct Supabase client
/// dependency in its auth state handling.
class SupabaseServiceListener {
  static StreamSubscription<AuthState> listen(void Function(AuthState) onData) {
    return SupabaseService.client.auth.onAuthStateChange.listen(onData);
  }
}
