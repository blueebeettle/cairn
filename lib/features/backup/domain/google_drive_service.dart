import 'dart:convert';
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class DriveBackupInfo {
  final String id;
  final String name;
  final DateTime? modifiedTime;
  final int sizeBytes;

  const DriveBackupInfo({
    required this.id,
    required this.name,
    this.modifiedTime,
    required this.sizeBytes,
  });
}

/// Service managing Google Sign-In and hidden Google Drive AppData Zero-Knowledge Backups.
class GoogleDriveService {
  static const String backupFileName = 'cairn_vault_backup.cairn';
  static const List<String> defaultScopes = [
    'email',
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  static const String defaultAndroidClientId =
      '429281814833-ohmvi7jfspu3hnefa1u9gq68330j3k5a.apps.googleusercontent.com';
  static const String defaultServerClientId =
      '429281814833-qa88m3nhudel0vh2gdqje421sbkprtnd.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn;
  final http.Client _httpClient;

  GoogleDriveService({
    GoogleSignIn? googleSignIn,
    http.Client? httpClient,
    String? serverClientId,
  })  : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: defaultScopes,
              clientId: defaultAndroidClientId,
              serverClientId: serverClientId ?? defaultServerClientId,
            ),
        _httpClient = httpClient ?? http.Client();

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<bool> isSignedIn() => _googleSignIn.isSignedIn();

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      throw GoogleDriveServiceException('Google Sign-In failed: $e');
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      throw GoogleDriveServiceException('Google Sign-Out failed: $e');
    }
  }

  /// Returns ID token from the authenticated Google account (used for Supabase signInWithIdToken).
  Future<String?> getIdToken() async {
    final user = _googleSignIn.currentUser;
    if (user == null) return null;
    final auth = await user.authentication;
    return auth.idToken;
  }

  /// Returns Access token from the authenticated Google account.
  Future<String?> getAccessToken() async {
    final user = _googleSignIn.currentUser;
    if (user == null) return null;
    final auth = await user.authentication;
    return auth.accessToken;
  }

  /// Retrieves auth headers with Bearer token.
  Future<Map<String, String>> getHeaders() async {
    final user = _googleSignIn.currentUser;
    if (user == null) {
      throw const GoogleDriveServiceException('User is not signed into Google.');
    }
    return await user.authHeaders;
  }

  /// Searches for the existing backup file inside the user's hidden appDataFolder.
  Future<DriveBackupInfo?> fetchBackupMetadata() async {
    final headers = await getHeaders();
    final url = Uri.parse(
      'https://www.googleapis.com/drive/v3/files'
      '?spaces=appDataFolder'
      "&q=name='$backupFileName' and trashed=false"
      '&fields=files(id,name,modifiedTime,size)',
    );

    final res = await _httpClient.get(url, headers: headers);
    if (res.statusCode != 200) {
      throw GoogleDriveServiceException(
        'Failed to query Google Drive (${res.statusCode}): ${res.body}',
      );
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final files = data['files'] as List<dynamic>?;
    if (files == null || files.isEmpty) {
      return null;
    }

    final file = files.first as Map<String, dynamic>;
    return DriveBackupInfo(
      id: file['id'] as String,
      name: file['name'] as String,
      modifiedTime: file['modifiedTime'] != null
          ? DateTime.tryParse(file['modifiedTime'] as String)
          : null,
      sizeBytes: int.tryParse(file['size']?.toString() ?? '0') ?? 0,
    );
  }

  /// Uploads AES-256-GCM encrypted [.cairn] bytes to the user's Google Drive AppData folder.
  Future<void> uploadEncryptedBackup(Uint8List encryptedBytes) async {
    final headers = await getHeaders();
    final existing = await fetchBackupMetadata();

    if (existing != null) {
      // Update existing file
      final updateUrl = Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files/${existing.id}?uploadType=media',
      );
      final res = await _httpClient.patch(
        updateUrl,
        headers: {
          ...headers,
          'Content-Type': 'application/octet-stream',
        },
        body: encryptedBytes,
      );

      if (res.statusCode != 200) {
        throw GoogleDriveServiceException(
          'Failed to update Google Drive backup (${res.statusCode}): ${res.body}',
        );
      }
    } else {
      // Create new file using multipart upload
      final boundary = '----CairnBackupBoundary${DateTime.now().millisecondsSinceEpoch}';
      final createUrl = Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
      );

      final metadata = jsonEncode({
        'name': backupFileName,
        'parents': ['appDataFolder'],
      });

      final bodyBytes = BytesBuilder();
      bodyBytes.add(utf8.encode('--$boundary\r\n'));
      bodyBytes.add(utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'));
      bodyBytes.add(utf8.encode('$metadata\r\n'));

      bodyBytes.add(utf8.encode('--$boundary\r\n'));
      bodyBytes.add(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'));
      bodyBytes.add(encryptedBytes);
      bodyBytes.add(utf8.encode('\r\n--$boundary--\r\n'));

      final res = await _httpClient.post(
        createUrl,
        headers: {
          ...headers,
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: bodyBytes.toBytes(),
      );

      if (res.statusCode != 200) {
        throw GoogleDriveServiceException(
          'Failed to create Google Drive backup (${res.statusCode}): ${res.body}',
        );
      }
    }
  }

  /// Downloads the encrypted [.cairn] payload from Google Drive AppData folder.
  Future<Uint8List> downloadEncryptedBackup() async {
    final headers = await getHeaders();
    final metadata = await fetchBackupMetadata();
    if (metadata == null) {
      throw const GoogleDriveServiceException(
        'No backup found in your Google Drive AppData folder.',
      );
    }

    final downloadUrl = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/${metadata.id}?alt=media',
    );

    final res = await _httpClient.get(downloadUrl, headers: headers);
    if (res.statusCode != 200) {
      throw GoogleDriveServiceException(
        'Failed to download Google Drive backup (${res.statusCode}): ${res.body}',
      );
    }

    return res.bodyBytes;
  }
}

class GoogleDriveServiceException implements Exception {
  final String message;
  const GoogleDriveServiceException(this.message);
  @override
  String toString() => message;
}
