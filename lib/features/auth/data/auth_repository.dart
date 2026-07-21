import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/models/user_model.dart';

class AuthRepository {
  final _client = SupabaseService.client;

  // Sign up with email + password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone,
      },
    );

    if (response.user != null) {
      // Insert into public.users
      await _client.from('users').insert({
        'id': response.user!.id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'roles': ['customer'],
        'active_role': 'customer',
      });
    }

    return response;
  }

  // Sign in
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // Get current user profile
  Future<UserModel?> getCurrentUser() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    final data = await _client
        .from('users')
        .select('*, farmer_profiles(*), expert_profiles(*), driver_profiles(*), business_profiles(*)')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return UserModel.fromJson(data);
  }

  // Update user roles
  Future<void> addRole({
    required String userId,
    required String role,
  }) async {
    // Use Supabase array append
    await _client.rpc('add_user_role', params: {
      'p_user_id': userId,
      'p_role': role,
    });
  }

  // Update active role
  Future<void> setActiveRole({
    required String userId,
    required String role,
  }) async {
    await _client.from('users').update({'active_role': role}).eq('id', userId);
  }

  // Update last seen
  Future<void> updateLastSeen(String userId) async {
    await _client
        .from('users')
        .update({'last_seen_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  // Update FCM token
  Future<void> updateFcmToken(String userId, String token) async {
    await _client
        .from('users')
        .update({'fcm_token': token})
        .eq('id', userId);
  }

  // Get auth state stream
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
