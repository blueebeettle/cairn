import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';
import 'package:habit_tracker/features/backup/data/backup_storage.dart';
import 'package:habit_tracker/features/backup/domain/backup_service.dart';
import 'package:habit_tracker/features/backup/domain/google_drive_service.dart';
import 'package:habit_tracker/features/backup/domain/supabase_backup_service.dart';
import 'package:habit_tracker/features/reminders/reminder_service.dart';

class BackupState {
  final bool isExporting;
  final bool isImporting;
  final bool isRestoring;
  final bool isCloudSyncing;
  final String? lastBackupDate;
  final String? lastErrorMessage;
  final String? lastSuccessMessage;
  final PickedBackupFile? pendingFile;
  final BackupManifest? manifestPreview;
  final bool isGoogleDriveConnected;
  final String? googleUserEmail;
  final bool isSupabaseConfigured;
  final String? supabaseUrl;
  final bool isCloudAccountLoggedIn;
  final String? cloudAccountEmail;

  const BackupState({
    this.isExporting = false,
    this.isImporting = false,
    this.isRestoring = false,
    this.isCloudSyncing = false,
    this.lastBackupDate,
    this.lastErrorMessage,
    this.lastSuccessMessage,
    this.pendingFile,
    this.manifestPreview,
    this.isGoogleDriveConnected = false,
    this.googleUserEmail,
    this.isSupabaseConfigured = false,
    this.supabaseUrl,
    this.isCloudAccountLoggedIn = false,
    this.cloudAccountEmail,
  });

  BackupState copyWith({
    bool? isExporting,
    bool? isImporting,
    bool? isRestoring,
    bool? isCloudSyncing,
    String? lastBackupDate,
    String? lastErrorMessage,
    String? lastSuccessMessage,
    PickedBackupFile? pendingFile,
    bool clearPendingFile = false,
    BackupManifest? manifestPreview,
    bool clearManifestPreview = false,
    bool? isGoogleDriveConnected,
    String? googleUserEmail,
    bool? isSupabaseConfigured,
    String? supabaseUrl,
    bool? isCloudAccountLoggedIn,
    String? cloudAccountEmail,
  }) {
    return BackupState(
      isExporting: isExporting ?? this.isExporting,
      isImporting: isImporting ?? this.isImporting,
      isRestoring: isRestoring ?? this.isRestoring,
      isCloudSyncing: isCloudSyncing ?? this.isCloudSyncing,
      lastBackupDate: lastBackupDate ?? this.lastBackupDate,
      lastErrorMessage: lastErrorMessage,
      lastSuccessMessage: lastSuccessMessage,
      pendingFile: clearPendingFile ? null : (pendingFile ?? this.pendingFile),
      manifestPreview:
          clearManifestPreview ? null : (manifestPreview ?? this.manifestPreview),
      isGoogleDriveConnected:
          isGoogleDriveConnected ?? this.isGoogleDriveConnected,
      googleUserEmail: googleUserEmail ?? this.googleUserEmail,
      isSupabaseConfigured:
          isSupabaseConfigured ?? this.isSupabaseConfigured,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      isCloudAccountLoggedIn:
          isCloudAccountLoggedIn ?? this.isCloudAccountLoggedIn,
      cloudAccountEmail: cloudAccountEmail ?? this.cloudAccountEmail,
    );
  }
}

final backupStorageProvider = Provider<BackupStorage>((ref) {
  return BackupStorage();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(databaseProvider);
  final reminderService = ref.watch(reminderServiceProvider);
  return BackupService(db: db, reminderService: reminderService);
});

final supabaseBackupServiceProvider = Provider<SupabaseBackupService>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return SupabaseBackupService(settingsRepository: settingsRepo);
});

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  return GoogleDriveService();
});

final backupControllerProvider =
    StateNotifierProvider<BackupController, BackupState>((ref) {
  final backupService = ref.watch(backupServiceProvider);
  final storage = ref.watch(backupStorageProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final supabaseService = ref.watch(supabaseBackupServiceProvider);
  final googleDriveService = ref.watch(googleDriveServiceProvider);
  return BackupController(
    backupService: backupService,
    storage: storage,
    settingsRepository: settingsRepo,
    supabaseService: supabaseService,
    googleDriveService: googleDriveService,
  );
});

class BackupController extends StateNotifier<BackupState> {
  final BackupService backupService;
  final BackupStorage storage;
  final SettingsRepository settingsRepository;
  final SupabaseBackupService supabaseService;
  final GoogleDriveService googleDriveService;

  BackupController({
    required this.backupService,
    required this.storage,
    required this.settingsRepository,
    required this.supabaseService,
    required this.googleDriveService,
  }) : super(const BackupState()) {
    _loadInitialSettings();
  }

  Future<void> _loadInitialSettings() async {
    final lastBackup = await settingsRepository.getString('last_backup_at');
    final googleEmail = await settingsRepository.getString('google_drive_email');
    final cloudEmail = await settingsRepository.getString('cloud_account_email');
    final configured = await supabaseService.isConfigured();
    final url = await supabaseService.getSupabaseUrl();

    String? loggedInEmail = cloudEmail;
    if (configured) {
      final initialized = await supabaseService.ensureInitialized();
      if (initialized && supabaseService.currentUser != null) {
        loggedInEmail = supabaseService.currentUser!.email ?? cloudEmail;
      }
    }

    state = state.copyWith(
      lastBackupDate: lastBackup,
      isGoogleDriveConnected: googleEmail != null && googleEmail.isNotEmpty,
      googleUserEmail: googleEmail,
      isSupabaseConfigured: configured,
      supabaseUrl: url,
      isCloudAccountLoggedIn: loggedInEmail != null && loggedInEmail.isNotEmpty,
      cloudAccountEmail: loggedInEmail,
    );
  }

  void clearMessages() {
    state = state.copyWith(
      lastErrorMessage: null,
      lastSuccessMessage: null,
    );
  }

  /// Exports an encrypted `.cairn` backup file with [password] and opens the share sheet.
  Future<bool> exportLocalBackup({
    required String password,
    Rect? sharePositionOrigin,
  }) async {
    state = state.copyWith(
      isExporting: true,
      lastErrorMessage: null,
      lastSuccessMessage: null,
    );

    try {
      final bytes =
          await backupService.createEncryptedBackup(password: password);
      await storage.shareBackupFile(
        bytes: bytes,
        sharePositionOrigin: sharePositionOrigin,
      );

      final nowIso = DateTime.now().toIso8601String();
      await settingsRepository.setString('last_backup_at', nowIso);

      state = state.copyWith(
        isExporting: false,
        lastBackupDate: nowIso,
        lastSuccessMessage:
            'Encrypted backup created successfully (${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB).',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        lastErrorMessage: 'Backup failed: $e',
      );
      return false;
    }
  }

  /// Picks a `.cairn` file via the native file picker.
  Future<PickedBackupFile?> pickFileForRestore() async {
    state = state.copyWith(
      isImporting: true,
      lastErrorMessage: null,
      lastSuccessMessage: null,
    );

    try {
      final file = await storage.pickBackupFile();
      state = state.copyWith(
        isImporting: false,
        pendingFile: file,
        clearManifestPreview: true,
      );
      return file;
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        lastErrorMessage: 'Failed to open file: $e',
      );
      return null;
    }
  }

  /// Inspects the picked file with [password] to show manifest preview before restoring.
  Future<BackupManifest?> inspectPendingFile(String password) async {
    final file = state.pendingFile;
    if (file == null) return null;

    try {
      final manifest = await backupService.inspectBackup(
        backupBytes: file.bytes,
        password: password,
      );
      state = state.copyWith(manifestPreview: manifest);
      return manifest;
    } catch (e) {
      state = state.copyWith(
        lastErrorMessage: 'Decryption failed: Incorrect password or invalid file.',
      );
      return null;
    }
  }

  /// Restores data from the selected file using [password].
  Future<bool> restorePendingFile(String password) async {
    final file = state.pendingFile;
    if (file == null) {
      state = state.copyWith(lastErrorMessage: 'No backup file selected.');
      return false;
    }

    state = state.copyWith(
      isRestoring: true,
      lastErrorMessage: null,
      lastSuccessMessage: null,
    );

    try {
      final summary = await backupService.restoreFromEncryptedBackup(
        backupBytes: file.bytes,
        password: password,
      );

      state = state.copyWith(
        isRestoring: false,
        clearPendingFile: true,
        clearManifestPreview: true,
        lastSuccessMessage:
            'Restored ${summary.tasksRestored} tasks, ${summary.focusSessionsRestored} sessions, ${summary.habitsRestored} habits, and ${summary.projectsRestored} projects!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isRestoring: false,
        lastErrorMessage:
            'Restore failed: Incorrect password or corrupted backup file.',
      );
      return false;
    }
  }

  void cancelPendingRestore() {
    state = state.copyWith(
      clearPendingFile: true,
      clearManifestPreview: true,
      lastErrorMessage: null,
    );
  }

  // --- Tier 2: Google Drive Personal Cloud Connect / Disconnect ---

  Future<bool> connectGoogleDrive([String? fallbackEmail]) async {
    state = state.copyWith(lastErrorMessage: null, lastSuccessMessage: null);
    try {
      final account = await googleDriveService.signIn();
      final email = account?.email ?? fallbackEmail;
      if (email != null && email.isNotEmpty) {
        await settingsRepository.setString('google_drive_email', email);
        state = state.copyWith(
          isGoogleDriveConnected: true,
          googleUserEmail: email,
          lastSuccessMessage: 'Connected to Google Drive ($email).',
        );
        return true;
      }
      return false;
    } catch (e) {
      if (fallbackEmail != null && fallbackEmail.isNotEmpty) {
        await settingsRepository.setString('google_drive_email', fallbackEmail);
        state = state.copyWith(
          isGoogleDriveConnected: true,
          googleUserEmail: fallbackEmail,
          lastSuccessMessage: 'Connected to Google Drive ($fallbackEmail).',
        );
        return true;
      }
      state = state.copyWith(lastErrorMessage: 'Google Drive connection failed: $e');
      return false;
    }
  }

  Future<void> disconnectGoogleDrive() async {
    try {
      await googleDriveService.signOut();
    } catch (_) {}
    await settingsRepository.delete('google_drive_email');
    state = state.copyWith(
      isGoogleDriveConnected: false,
      googleUserEmail: null,
      lastSuccessMessage: 'Disconnected from Google Drive.',
    );
  }

  Future<bool> backupToGoogleDrive({required String password}) async {
    state = state.copyWith(
      isCloudSyncing: true,
      lastErrorMessage: null,
      lastSuccessMessage: null,
    );

    try {
      final bytes = await backupService.createEncryptedBackup(password: password);
      await googleDriveService.uploadEncryptedBackup(bytes);
      final nowIso = DateTime.now().toIso8601String();
      await settingsRepository.setString('last_backup_at', nowIso);

      state = state.copyWith(
        isCloudSyncing: false,
        lastBackupDate: nowIso,
        lastSuccessMessage: 'Backup encrypted & uploaded to Google Drive AppData.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isCloudSyncing: false,
        lastErrorMessage: 'Google Drive backup failed: $e',
      );
      return false;
    }
  }

  Future<bool> restoreFromGoogleDrive({required String password}) async {
    state = state.copyWith(
      isRestoring: true,
      lastErrorMessage: null,
      lastSuccessMessage: null,
    );

    try {
      final bytes = await googleDriveService.downloadEncryptedBackup();
      final summary = await backupService.restoreFromEncryptedBackup(
        backupBytes: bytes,
        password: password,
      );

      state = state.copyWith(
        isRestoring: false,
        lastSuccessMessage:
            'Restored ${summary.tasksRestored} tasks, ${summary.focusSessionsRestored} sessions & ${summary.habitsRestored} habits from Google Drive.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isRestoring: false,
        lastErrorMessage: 'Google Drive restore failed: $e',
      );
      return false;
    }
  }

  // --- Tier 3: Supabase Cloud Account Authentication & Sync ---

  Future<void> configureSupabase({
    required String url,
    required String anonKey,
  }) async {
    await supabaseService.saveCredentials(url: url, anonKey: anonKey);
    state = state.copyWith(
      isSupabaseConfigured: true,
      supabaseUrl: url,
      lastSuccessMessage: 'Supabase credentials saved successfully.',
    );
  }

  Future<bool> signUpSupabase({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isCloudSyncing: true, lastErrorMessage: null);
    try {
      final response = await supabaseService.signUp(email: email, password: password);
      final userEmail = response.user?.email ?? email;
      await settingsRepository.setString('cloud_account_email', userEmail);
      state = state.copyWith(
        isCloudSyncing: false,
        isCloudAccountLoggedIn: true,
        cloudAccountEmail: userEmail,
        lastSuccessMessage: 'Signed up successfully as $userEmail!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isCloudSyncing: false,
        lastErrorMessage: '$e',
      );
      return false;
    }
  }

  Future<bool> signInSupabase({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isCloudSyncing: true, lastErrorMessage: null);
    try {
      final response = await supabaseService.signIn(email: email, password: password);
      final userEmail = response.user?.email ?? email;
      await settingsRepository.setString('cloud_account_email', userEmail);
      state = state.copyWith(
        isCloudSyncing: false,
        isCloudAccountLoggedIn: true,
        cloudAccountEmail: userEmail,
        lastSuccessMessage: 'Welcome back, $userEmail!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isCloudSyncing: false,
        lastErrorMessage: '$e',
      );
      return false;
    }
  }

  Future<bool> signInSupabaseWithGoogle() async {
    state = state.copyWith(isCloudSyncing: true, lastErrorMessage: null);
    try {
      final account = googleDriveService.currentUser ?? await googleDriveService.signIn();
      if (account == null) {
        state = state.copyWith(isCloudSyncing: false);
        return false;
      }

      final idToken = await googleDriveService.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleDriveServiceException(
          'Google ID Token is unavailable. Please ensure Google Cloud Web Client ID is configured in Supabase.',
        );
      }
      final accessToken = await googleDriveService.getAccessToken();

      final res = await supabaseService.signInWithGoogle(
        idToken: idToken,
        accessToken: accessToken,
      );

      final userEmail = res.user?.email ?? account.email;
      await settingsRepository.setString('cloud_account_email', userEmail);
      state = state.copyWith(
        isCloudSyncing: false,
        isCloudAccountLoggedIn: true,
        cloudAccountEmail: userEmail,
        lastSuccessMessage: 'Welcome, $userEmail!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isCloudSyncing: false,
        lastErrorMessage: 'Google Sign-In failed: $e',
      );
      return false;
    }
  }

  Future<void> signOutSupabase() async {
    await supabaseService.signOut();
    await settingsRepository.delete('cloud_account_email');
    state = state.copyWith(
      isCloudAccountLoggedIn: false,
      cloudAccountEmail: null,
      lastSuccessMessage: 'Signed out of cloud account.',
    );
  }

  /// Encrypts database with [password] and uploads encrypted payload to Supabase.
  Future<bool> backupToCloud({required String password}) async {
    state = state.copyWith(isCloudSyncing: true, lastErrorMessage: null);
    try {
      final bytes = await backupService.createEncryptedBackup(password: password);
      await supabaseService.uploadEncryptedBackup(bytes);
      state = state.copyWith(
        isCloudSyncing: false,
        lastSuccessMessage: 'Encrypted cloud backup completed successfully!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isCloudSyncing: false,
        lastErrorMessage: 'Cloud backup failed: $e',
      );
      return false;
    }
  }

  /// Downloads encrypted backup from Supabase, decrypts with [password], and restores database.
  Future<bool> restoreFromCloud({required String password}) async {
    state = state.copyWith(isCloudSyncing: true, lastErrorMessage: null);
    try {
      final bytes = await supabaseService.downloadEncryptedBackup();
      final summary = await backupService.restoreFromEncryptedBackup(
        backupBytes: bytes,
        password: password,
      );
      state = state.copyWith(
        isCloudSyncing: false,
        lastSuccessMessage:
            'Cloud restore complete: ${summary.tasksRestored} tasks, ${summary.focusSessionsRestored} sessions and ${summary.habitsRestored} habits restored!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isCloudSyncing: false,
        lastErrorMessage: 'Cloud restore failed: $e',
      );
      return false;
    }
  }

  /// Returns current counts of sessions, tasks and habits for restore confirmation.
  Future<({int sessionCount, int taskCount, int habitCount})>
      getCurrentDataCounts() {
    return backupService.getCurrentDataCounts();
  }
}
