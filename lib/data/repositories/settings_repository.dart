import 'dart:convert';

import '../../core/ids.dart';
import '../database/app_database.dart';

/// Key-value settings repository per SPEC.md §2.5.
///
/// Stores JSON-encoded values in the Drift `settings` table.
class SettingsRepository {
  SettingsRepository({required this.db});

  final AppDatabase db;
  AppDatabase get _db => db;

  /// Retrieves a JSON-decoded value by [key], or null if not set.
  Future<dynamic> get(String key) async {
    final row = await (_db.select(_db.settings)
          ..where((tbl) => tbl.key.equals(key)))
        .getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.value);
  }

  /// Retrieves a String value by [key].
  Future<String?> getString(String key) async {
    final val = await get(key);
    return val as String?;
  }

  /// Retrieves an int value by [key].
  Future<int?> getInt(String key) async {
    final val = await get(key);
    if (val is int) return val;
    if (val is num) return val.toInt();
    return null;
  }

  /// Retrieves a bool value by [key].
  Future<bool?> getBool(String key) async {
    final val = await get(key);
    return val as bool?;
  }

  /// Sets a JSON-encoded [value] for [key] in `settings` table.
  Future<void> set(String key, dynamic value) async {
    final jsonStr = jsonEncode(value);
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: key,
            value: jsonStr,
          ),
        );
  }

  Future<void> setString(String key, String value) => set(key, value);
  Future<void> setInt(String key, int value) => set(key, value);
  Future<void> setBool(String key, bool value) => set(key, value);

  /// Deletes a key from `settings` table.
  Future<int> delete(String key) {
    return (_db.delete(_db.settings)..where((tbl) => tbl.key.equals(key))).go();
  }

  /// Retrieves or generates and persists the installation device ID (§5).
  ///
  /// Generated once on first launch, stored in settings under 'device_id',
  /// never regenerated.
  Future<String> getOrCreateDeviceId() async {
    final existing = await getString('device_id');
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final generated = newId();
    await setString('device_id', generated);
    return generated;
  }

  /// Watches a setting key for live changes.
  Stream<dynamic> watch(String key) {
    return (_db.select(_db.settings)..where((tbl) => tbl.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : jsonDecode(row.value));
  }

  /// Allocates a monotonic 32-bit notification ID from settings ('next_notification_id'),
  /// starting at 1000, never reused.
  ///
  /// Wrapped in a transaction: reminder reconciliation now schedules tasks
  /// and habits in parallel (see ReminderService.reconcileAll/reconcileHabits),
  /// so this read-then-write can be called concurrently for several rows
  /// that all still need a fresh id. Drift serializes transactions on its
  /// single connection, so this stays a plain atomic increment under that
  /// concurrency instead of two callers racing to read the same "current"
  /// value and handing out the same id to two different reminders.
  Future<int> getNextNotificationId() async {
    return _db.transaction(() async {
      final current = await getInt('next_notification_id') ?? 1000;
      final next = current + 1;
      await setInt('next_notification_id', next);
      return current;
    });
  }
}
