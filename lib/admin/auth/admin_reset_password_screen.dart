import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/nile_widgets.dart';
import '../../shared/services/auth_service.dart';

class AdminResetPasswordScreen extends StatefulWidget {
  const AdminResetPasswordScreen({super.key});

  @override
  State<AdminResetPasswordScreen> createState() => _AdminResetPasswordScreenState();
}

class _AdminResetPasswordScreenState extends State<AdminResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _message;

  Future<void> _updatePassword() async {
    final password = _password.text;
    final confirm = _confirm.text;
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      await AuthService.updatePassword(password);
      await AuthService.signOut();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Password updated successfully. You can now sign in.';
      });
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
    _password.dispose();
    _confirm.dispose();
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
                const Center(
                  child: Image(
                    image: AssetImage('assets/images/logo.png'),
                    width: 72,
                    height: 72,
                  ),
                ),
                const SizedBox(height: NileSpacing.md),
                Text(
                  'Reset Password',
                  style: NileTypography.headlineLarge.copyWith(color: NileColors.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NileSpacing.sm),
                Text(
                  'Create a new password for your Nile Admin account.',
                  style: NileTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: NileSpacing.xl),
                NileTextField(
                  controller: _password,
                  label: 'New password',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: NileSpacing.md),
                NileTextField(
                  controller: _confirm,
                  label: 'Confirm password',
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: NileSpacing.sm),
                  Text(_error!, style: NileTypography.bodySmall.copyWith(color: NileColors.error)),
                ],
                if (_message != null) ...[
                  const SizedBox(height: NileSpacing.sm),
                  Text(_message!, style: NileTypography.bodySmall.copyWith(color: NileColors.primary)),
                ],
                const SizedBox(height: NileSpacing.lg),
                NileButton(
                  label: 'Update password',
                  loading: _loading,
                  onPressed: _updatePassword,
                ),
                const SizedBox(height: NileSpacing.sm),
                TextButton(
                  onPressed: () => context.go('/admin/login'),
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
