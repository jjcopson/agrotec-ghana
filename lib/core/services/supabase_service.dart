import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../constants/app_constants.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      debug: false,
    );
  }

  // Helper: current user id
  static String? get currentUserId => auth.currentUser?.id;

  // Helper: is logged in
  static bool get isLoggedIn => auth.currentUser != null;

  // Upload file and return public URL
  static Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String? contentType,
  }) async {
    final uint8bytes = Uint8List.fromList(bytes);
    await storage.from(bucket).uploadBinary(
      path,
      uint8bytes,
      fileOptions: FileOptions(contentType: contentType ?? 'application/octet-stream'),
    );
    return storage.from(bucket).getPublicUrl(path);
  }

  // Delete file
  static Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    await storage.from(bucket).remove([path]);
  }

  // Realtime channel
  static RealtimeChannel channel(String name) => client.channel(name);
}
