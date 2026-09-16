import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/auth_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.signIn(
        email: _email.text,
        password: _password.text,
      );
      final roles = await AuthService.rolesForCurrentUser();
      if (!mounted) return;
      if (AuthService.canAccessCourier(roles) && !AuthService.canAccessAdmin(roles)) {
        context.go('/courier');
        return;
      }
      if (!AuthService.canAccessAdmin(roles)) {
        await AuthService.signOut();
        setState(() {
          _loading = false;
          _error = 'This account has no operations role.';
        });
        return;
      }
      context.go('/admin');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(NileSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Image(image: AssetImage('assets/images/logo.png'), width: 72, height: 72)),
                const SizedBox(height: NileSpacing.md),
                Text(
                  'Nile Admin',
                  style: NileTypography.headlineLarge.copyWith(color: NileColors.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NileSpacing.xl),
                NileTextField(
                  controller: _email,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: NileSpacing.md),
                NileTextField(
                  controller: _password,
                  label: 'Password',
                  obscureText: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: NileSpacing.sm),
                  Text(_error!, style: NileTypography.bodySmall.copyWith(color: NileColors.error)),
                ],
                const SizedBox(height: NileSpacing.lg),
                NileButton(label: 'Sign in', loading: _loading, onPressed: _login),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
