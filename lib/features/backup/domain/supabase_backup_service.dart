import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';

/// Service managing Supabase Cloud Authentication and Zero-Knowledge Encrypted Cloud Backups.
class SupabaseBackupService {
  static const String defaultUrl = 'https://iegxiqmwujossvzxlrnh.supabase.co';
  static const String defaultAnonKey = 'sb_publishable_BE2xup_rEouOVbjCTSpoFw_fWzoYawX';

  final SettingsRepository settingsRepository;

  SupabaseBackupService({required this.settingsRepository});

  bool _isInitialized = false;

  /// Returns true if Supabase URL and Anon Key have been configured.
  Future<bool> isConfigured() async {
    final url = await getSupabaseUrl();
    final key = await getSupabaseAnonKey();
    return url != null && url.isNotEmpty && key != null && key.isNotEmpty;
  }

  Future<String?> getSupabaseUrl() =>
      settingsRepository.getString('supabase_url');

  Future<String?> getSupabaseAnonKey() =>
      settingsRepository.getString('supabase_anon_key');

  Future<void> saveCredentials({
    required String url,
    required String anonKey,
  }) async {
    await settingsRepository.setString('supabase_url', url.trim());
    await settingsRepository.setString('supabase_anon_key', anonKey.trim());
    _isInitialized = false;
    await ensureInitialized();
  }

  /// Initializes Supabase client if configured and not yet initialized.
  Future<bool> ensureInitialized() async {
    if (_isInitialized) return true;

    final url = await getSupabaseUrl();
    final anonKey = await getSupabaseAnonKey();

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      return false;
    }

    try {
      await Supabase.initialize(
        url: url,
        publishableKey: anonKey,
        authOptions: FlutterAuthClientOptions(
          autoRefreshToken: !Platform.environment.containsKey('FLUTTER_TEST'),
        ),
      );
      _isInitialized = true;
      return true;
    } catch (_) {
      // Supabase may already be initialized in this process
      _isInitialized = true;
      return true;
    }
  }

  SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => client?.auth.currentUser;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final initialized = await ensureInitialized();
    if (!initialized || client == null) {
      throw const SupabaseServiceException(
        'Supabase is not configured. Please enter your Supabase Project URL and Anon Key first.',
      );
    }

    return client!.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final initialized = await ensureInitialized();
    if (!initialized || client == null) {
      throw const SupabaseServiceException(
        'Supabase is not configured. Please enter your Supabase Project URL and Anon Key first.',
      );
    }

    return client!.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signInWithGoogle({
    required String idToken,
    String? accessToken,
  }) async {
    final initialized = await ensureInitialized();
    if (!initialized || client == null) {
      throw const SupabaseServiceException(
        'Supabase is not configured. Please enter your Supabase Project URL and Anon Key first.',
      );
    }

    return client!.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() async {
    if (client != null) {
      await client!.auth.signOut();
    }
  }

  /// Uploads client-side AES-256-GCM encrypted [.cairn] payload to Supabase.
  Future<void> uploadEncryptedBackup(Uint8List encryptedBytes) async {
    final user = currentUser;
    if (user == null || client == null) {
      throw const SupabaseServiceException('User must be signed in to upload to cloud vault.');
    }

    try {
      await client!.storage.from('backups').uploadBinary(
            '${user.id}/latest.cairn',
            encryptedBytes,
            fileOptions: const FileOptions(upsert: true),
          );
    } catch (e) {
      throw SupabaseServiceException('Cloud upload failed: $e');
    }
  }

  /// Downloads user's latest encrypted [.cairn] payload from Supabase.
  Future<Uint8List> downloadEncryptedBackup() async {
    final user = currentUser;
    if (user == null || client == null) {
      throw const SupabaseServiceException('User must be signed in to restore from cloud vault.');
    }

    try {
      return await client!.storage.from('backups').download('${user.id}/latest.cairn');
    } catch (e) {
      throw SupabaseServiceException('Cloud download failed: $e');
    }
  }
}

class SupabaseServiceException implements Exception {
  final String message;
  const SupabaseServiceException(this.message);
  @override
  String toString() => message;
}
