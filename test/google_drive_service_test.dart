import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/backup/domain/google_drive_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeGoogleSignInAccount {
  final String email;
  FakeGoogleSignInAccount(this.email);

  Future<Map<String, String>> get authHeaders async => {
        'Authorization': 'Bearer test-google-token',
      };
}

void main() {
  group('GoogleDriveService Unit Tests', () {
    test('fetchBackupMetadata returns null when no files found in appDataFolder', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('spaces=appDataFolder'));
        expect(request.headers['Authorization'], equals('Bearer test-token'));
        return http.Response(jsonEncode({'files': []}), 200);
      });

      // Subclass GoogleDriveService for test to override _getHeaders
      final service = TestableGoogleDriveService(httpClient: mockClient);
      final meta = await service.fetchBackupMetadata();
      expect(meta, isNull);
    });

    test('fetchBackupMetadata parses metadata correctly when file exists', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'files': [
              {
                'id': 'drive-file-123',
                'name': 'cairn_vault_backup.cairn',
                'modifiedTime': '2026-09-14T10:00:00.000Z',
                'size': '2048',
              }
            ]
          }),
          200,
        );
      });

      final service = TestableGoogleDriveService(httpClient: mockClient);
      final meta = await service.fetchBackupMetadata();
      expect(meta, isNotNull);
      expect(meta!.id, equals('drive-file-123'));
      expect(meta.name, equals('cairn_vault_backup.cairn'));
      expect(meta.sizeBytes, equals(2048));
      expect(meta.modifiedTime?.toIso8601String(), equals('2026-09-14T10:00:00.000Z'));
    });

    test('uploadEncryptedBackup sends multipart POST when file does not exist', () async {
      bool getCalled = false;
      bool postCalled = false;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          getCalled = true;
          return http.Response(jsonEncode({'files': []}), 200);
        } else if (request.method == 'POST') {
          postCalled = true;
          expect(request.url.toString(), contains('uploadType=multipart'));
          expect(request.headers['Content-Type'], contains('multipart/related'));
          return http.Response(
            jsonEncode({'id': 'new-file-id', 'name': 'cairn_vault_backup.cairn'}),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = TestableGoogleDriveService(httpClient: mockClient);
      await service.uploadEncryptedBackup(Uint8List.fromList([1, 2, 3, 4]));

      expect(getCalled, isTrue);
      expect(postCalled, isTrue);
    });

    test('uploadEncryptedBackup sends PATCH when file already exists', () async {
      bool patchCalled = false;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'files': [
                {
                  'id': 'existing-file-999',
                  'name': 'cairn_vault_backup.cairn',
                  'size': '100',
                }
              ]
            }),
            200,
          );
        } else if (request.method == 'PATCH') {
          patchCalled = true;
          expect(request.url.toString(), contains('existing-file-999'));
          expect(request.url.toString(), contains('uploadType=media'));
          expect(request.bodyBytes, equals([1, 2, 3, 4]));
          return http.Response(
            jsonEncode({'id': 'existing-file-999'}),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = TestableGoogleDriveService(httpClient: mockClient);
      await service.uploadEncryptedBackup(Uint8List.fromList([1, 2, 3, 4]));

      expect(patchCalled, isTrue);
    });

    test('downloadEncryptedBackup retrieves binary bytes correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && !request.url.toString().contains('alt=media')) {
          return http.Response(
            jsonEncode({
              'files': [
                {
                  'id': 'dl-file-123',
                  'name': 'cairn_vault_backup.cairn',
                  'size': '4',
                }
              ]
            }),
            200,
          );
        } else if (request.method == 'GET' && request.url.toString().contains('alt=media')) {
          return http.Response.bytes([9, 8, 7, 6], 200);
        }
        return http.Response('Error', 500);
      });

      final service = TestableGoogleDriveService(httpClient: mockClient);
      final downloaded = await service.downloadEncryptedBackup();
      expect(downloaded, equals([9, 8, 7, 6]));
    });

    test('downloadEncryptedBackup throws when no backup exists', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'files': []}), 200);
      });

      final service = TestableGoogleDriveService(httpClient: mockClient);
      expect(
        () => service.downloadEncryptedBackup(),
        throwsA(isA<GoogleDriveServiceException>()),
      );
    });
  });
}

class TestableGoogleDriveService extends GoogleDriveService {
  TestableGoogleDriveService({required super.httpClient});

  @override
  Future<Map<String, String>> getHeaders() async {
    return {'Authorization': 'Bearer test-token'};
  }
}
