import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env.dart';
import 'supabase_service.dart';

class AuthService {
  static bool get isConfigured => Env.isConfigured;

  static Session? get session =>
      Env.isConfigured ? SupabaseService.client.auth.currentSession : null;

  static User? get user =>
      Env.isConfigured ? SupabaseService.client.auth.currentUser : null;

  static bool get isLoggedIn => user != null;

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    if (!Env.isConfigured) {
      throw StateError('Supabase is not configured. Cannot authenticate.');
    }
    return SupabaseService.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> sendPasswordReset(String email) async {
    if (!Env.isConfigured) {
      throw StateError('Supabase is not configured. Cannot reset password.');
    }
    final redirectTo = '${Uri.base.origin}/app/#/admin/reset-password';
    await SupabaseService.client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: redirectTo,
    );
  }

  static Future<void> updatePassword(String password) async {
    if (!Env.isConfigured) {
      throw StateError('Supabase is not configured. Cannot update password.');
    }
    await SupabaseService.client.auth.updateUser(
      UserAttributes(password: password),
    );
  }

  static Future<void> signOut() async {
    if (!Env.isConfigured) return;
    await SupabaseService.client.auth.signOut();
  }

  /// Roles from user_roles; falls back to profiles.role if that column exists.
  static Future<List<String>> rolesForCurrentUser() async {
    if (!Env.isConfigured || user == null) return const [];
    final uid = user!.id;
    try {
      final rows = await SupabaseService.client
          .from('user_roles')
          .select('role')
          .eq('user_id', uid);
      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isNotEmpty) {
        return list.map((r) => r['role'].toString()).toList();
      }
    } catch (_) {}
    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('role, is_active')
          .eq('id', uid)
          .maybeSingle();
      if (profile != null && profile['is_active'] != false) {
        final role = profile['role']?.toString();
        if (role != null && role.isNotEmpty) return [role];
      }
    } catch (_) {}
    return const [];
  }

  static bool isStaffRole(String role) {
    const staff = {
      'super_admin',
      'admin',
      'manager',
      'inventory_officer',
      'inventory',
      'sales',
      'sales_staff',
      'finance',
      'content',
      'content_manager',
      'courier',
    };
    return staff.contains(role);
  }

  static bool canAccessAdmin(List<String> roles) {
    return roles.any((r) => isStaffRole(r) && r != 'courier' && r != 'customer');
  }

  static bool canAccessCourier(List<String> roles) {
    return roles.contains('courier') ||
        roles.contains('super_admin') ||
        roles.contains('admin') ||
        roles.contains('manager');
  }

  static Future<String?> courierIdForCurrentUser() async {
    if (!Env.isConfigured || user == null) return null;
    final row = await SupabaseService.client
        .from('couriers')
        .select('id')
        .eq('auth_user_id', user!.id)
        .maybeSingle();
    return row?['id']?.toString();
  }
}

