import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Handles physical file operations for Cairn backups (sharing & picking).
class BackupStorage {
  /// Writes [bytes] to a temporary `.cairn` file and triggers the system share/save sheet.
  Future<void> shareBackupFile({
    required Uint8List bytes,
    String? filename,
    Rect? sharePositionOrigin,
  }) async {
    final name = filename ??
        'cairn-backup-${DateTime.now().toIso8601String().substring(0, 10)}.cairn';
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$name';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, name: name, mimeType: 'application/octet-stream')],
        subject: 'Cairn Encrypted Backup',
        text: 'Cairn zero-knowledge encrypted backup ($name)',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Opens the native system file picker to select a `.cairn` backup file.
  /// Returns the file bytes and filename, or null if cancelled.
  Future<PickedBackupFile?> pickBackupFile() async {
    final result = await FilePickerPlatform.instance.pickFiles(
      type: FileType.any,
    );

    if (result.isEmpty) {
      return null;
    }

    final file = result.first;
    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      return null;
    }

    return PickedBackupFile(
      name: file.name,
      bytes: bytes,
      path: file.path,
    );
  }
}

class PickedBackupFile {
  final String name;
  final Uint8List bytes;
  final String? path;

  const PickedBackupFile({
    required this.name,
    required this.bytes,
    this.path,
  });
}
