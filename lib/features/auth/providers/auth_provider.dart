import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';
import '../../../shared/models/user_model.dart';
import '../../../core/services/supabase_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Stream of Supabase auth state
final authStateProvider = StreamProvider<User?>((ref) {
  return SupabaseService.auth.onAuthStateChange
      .map((event) => event.session?.user);
});

// Current user profile
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return null;
  return ref.read(authRepositoryProvider).getCurrentUser();
});

// Auth notifier for actions
class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadUser();
  }

  Future<void> _loadUser() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    try {
      state = const AsyncValue.loading();
      await _repository.signIn(email: email, password: password);
      await _loadUser();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    try {
      state = const AsyncValue.loading();
      await _repository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      await _loadUser();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    // Clear state immediately
    state = const AsyncValue.data(null);
  }

  Future<void> refreshUser() async => _loadUser();
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});
