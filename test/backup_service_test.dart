import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/features/backup/domain/backup_crypto_engine.dart';
import 'package:habit_tracker/features/backup/domain/backup_service.dart';

void main() {
  group('BackupService End-to-End Tests', () {
    late AppDatabase db;
    late BackupService backupService;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      backupService = BackupService(db: db);

      // Seed initial data
      await db.into(db.settings).insert(
            SettingsCompanion.insert(key: 'theme_mode', value: 'dark'),
          );
      await db.into(db.projects).insert(
            ProjectsCompanion.insert(
              id: 'p1',
              name: 'Work Project',
              colorIndex: const Value(1),
              updatedAt: 1000,
              deviceId: 'device-1',
            ),
          );
      await db.into(db.tasks).insert(
            TasksCompanion.insert(
              id: 't1',
              title: 'First Task',
              projectId: const Value('p1'),
              priority: const Value(1),
              status: const Value('open'),
              createdAt: 1000,
              createdLocalDate: '2026-09-14',
              updatedAt: 1000,
              deviceId: 'device-1',
            ),
          );
      await db.into(db.focusSessions).insert(
            FocusSessionsCompanion.insert(
              id: 's1',
              taskId: const Value('t1'),
              projectId: const Value('p1'),
              mode: 'pomodoro',
              plannedDurationS: const Value(1500),
              actualDurationS: const Value(1500),
              startedAt: 1000,
              endedAt: 2500,
              localDate: '2026-09-14',
              tzOffsetMin: 330,
              tzId: const Value('Asia/Kolkata'),
              outcome: 'completed',
              interruptionsInternal: const Value(1),
              interruptionsExternal: const Value(0),
              focusRating: const Value(5),
              updatedAt: 2500,
              deviceId: 'device-1',
            ),
          );
      await db.into(db.events).insert(
            EventsCompanion.insert(
              id: 'e1',
              type: 'task_created',
              occurredAt: 1000,
              recordedAt: 1000,
              localDate: '2026-09-14',
              tzId: 'Asia/Kolkata',
              tzOffsetMin: 330,
              payload: '{"title":"First Task"}',
              deviceId: 'device-1',
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('Full export, inspect, wipe, and atomic restore lifecycle', () async {
      const password = 'TestVaultPassword99!';

      // 1. Export
      final encryptedBytes =
          await backupService.createEncryptedBackup(password: password);
      expect(encryptedBytes.length, greaterThan(50));

      // 2. Inspect
      final manifest = await backupService.inspectBackup(
        backupBytes: encryptedBytes,
        password: password,
      );
      expect(manifest.taskCount, equals(1));
      expect(manifest.sessionCount, equals(1));
      expect(manifest.projectCount, equals(1));
      expect(manifest.eventCount, equals(1));

      // 3. Inspect with wrong password fails
      expect(
        () => backupService.inspectBackup(
          backupBytes: encryptedBytes,
          password: 'WrongPassword!',
        ),
        throwsA(isA<BackupCryptoException>()),
      );

      // 4. Wipe current database
      await db.delete(db.focusSessions).go();
      await db.delete(db.tasks).go();
      await db.delete(db.projects).go();
      await db.delete(db.events).go();
      await db.delete(db.settings).go();

      expect(await db.select(db.tasks).get(), isEmpty);
      expect(await db.select(db.focusSessions).get(), isEmpty);

      // 5. Restore
      final summary = await backupService.restoreFromEncryptedBackup(
        backupBytes: encryptedBytes,
        password: password,
      );

      expect(summary.tasksRestored, equals(1));
      expect(summary.focusSessionsRestored, equals(1));
      expect(summary.projectsRestored, equals(1));
      expect(summary.eventsRestored, equals(1));

      // 6. Verify restored database contents
      final restoredTasks = await db.select(db.tasks).get();
      expect(restoredTasks.length, equals(1));
      expect(restoredTasks.first.title, equals('First Task'));

      final restoredSessions = await db.select(db.focusSessions).get();
      expect(restoredSessions.length, equals(1));
      expect(restoredSessions.first.outcome, equals('completed'));
      expect(restoredSessions.first.focusRating, equals(5));

      final restoredSettings = await db.select(db.settings).get();
      expect(
        restoredSettings.any((s) => s.key == 'theme_mode' && s.value == 'dark'),
        isTrue,
      );
    });

    test('Tampered ciphertext throws and preserves database state', () async {
      const password = 'Password123';
      final encryptedBytes =
          await backupService.createEncryptedBackup(password: password);

      // Tamper with ciphertext byte
      final tampered = List<int>.from(encryptedBytes);
      tampered[tampered.length - 5] ^= 0xFF;

      expect(
        () => backupService.restoreFromEncryptedBackup(
          backupBytes: Uint8List.fromList(tampered),
          password: password,
        ),
        throwsA(isA<BackupCryptoException>()),
      );

      // Verify database still has original records
      final tasks = await db.select(db.tasks).get();
      expect(tasks.length, equals(1));
    });
  });
}
