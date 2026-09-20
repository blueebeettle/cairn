import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Cryptographic engine for Cairn zero-knowledge backups.
///
/// Format specification:
/// - 6 bytes: Magic header ('CAIRN1' = 0x43, 0x41, 0x49, 0x52, 0x4E, 0x31)
/// - 16 bytes: PBKDF2 cryptographically secure salt
/// - 12 bytes: AES-GCM nonce (IV)
/// - 16 bytes: AES-GCM authentication MAC tag
/// - Remaining bytes: AES-256-GCM ciphertext of gzip-compressed UTF-8 JSON payload
class BackupCryptoEngine {
  static const List<int> magicBytes = [0x43, 0x41, 0x49, 0x52, 0x4E, 0x31]; // 'CAIRN1'
  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int macLength = 16;
  static const int minHeaderLength = 6 + saltLength + nonceLength + macLength; // 50 bytes

  final AesGcm _aesGcm = AesGcm.with256bits();
  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );

  /// Encrypts cleartext string (e.g. JSON) with [password] into `.cairn` binary payload.
  Future<Uint8List> encrypt(String clearText, String password) async {
    if (password.isEmpty) {
      throw const BackupCryptoException('Password cannot be empty.');
    }

    final uncompressedBytes = utf8.encode(clearText);
    final compressedBytes = gzip.encode(uncompressedBytes);

    final salt = _randomBytes(saltLength);
    final nonce = _randomBytes(nonceLength);

    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    final secretBox = await _aesGcm.encrypt(
      compressedBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final builder = BytesBuilder();
    builder.add(magicBytes);
    builder.add(salt);
    builder.add(nonce);
    builder.add(secretBox.mac.bytes);
    builder.add(secretBox.cipherText);

    return builder.toBytes();
  }

  /// Decrypts `.cairn` binary payload with [password] and returns cleartext string.
  /// Throws [BackupCryptoException] if file is invalid or password is wrong.
  Future<String> decrypt(Uint8List encryptedData, String password) async {
    if (password.isEmpty) {
      throw const BackupCryptoException('Password cannot be empty.');
    }

    if (encryptedData.length < minHeaderLength) {
      throw const BackupCryptoException('File is too small to be a valid Cairn backup.');
    }

    // Check magic bytes
    for (var i = 0; i < magicBytes.length; i++) {
      if (encryptedData[i] != magicBytes[i]) {
        throw const BackupCryptoException('Invalid file format: Not a recognized Cairn backup.');
      }
    }

    var offset = magicBytes.length;
    final salt = encryptedData.sublist(offset, offset + saltLength);
    offset += saltLength;

    final nonce = encryptedData.sublist(offset, offset + nonceLength);
    offset += nonceLength;

    final macBytes = encryptedData.sublist(offset, offset + macLength);
    offset += macLength;

    final cipherText = encryptedData.sublist(offset);

    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    try {
      final decryptedCompressed = await _aesGcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: secretKey,
      );

      final decompressed = gzip.decode(decryptedCompressed);
      return utf8.decode(decompressed);
    } on SecretBoxAuthenticationError {
      throw const BackupCryptoException('Incorrect password or corrupted backup file.');
    } catch (e) {
      throw BackupCryptoException('Decryption failed: $e');
    }
  }

  Uint8List _randomBytes(int length) {
    final random = SecretKeyData.random(length: length);
    return Uint8List.fromList(random.bytes);
  }
}

class BackupCryptoException implements Exception {
  final String message;
  const BackupCryptoException(this.message);
  @override
  String toString() => message;
}
