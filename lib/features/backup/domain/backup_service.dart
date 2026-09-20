import 'dart:convert';
import 'dart:typed_data';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/features/backup/domain/backup_crypto_engine.dart';
import 'package:habit_tracker/features/reminders/reminder_service.dart';

class BackupManifest {
  final int formatVersion;
  final int schemaVersion;
  final String exportedAt;
  final int eventCount;
  final int taskCount;
  final int sessionCount;
  final int projectCount;
  final int tagCount;

  const BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.exportedAt,
    required this.eventCount,
    required this.taskCount,
    required this.sessionCount,
    required this.projectCount,
    required this.tagCount,
  });

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      formatVersion: json['format_version'] as int? ?? 1,
      schemaVersion: json['schema_version'] as int? ?? 4,
      exportedAt: json['exported_at'] as String? ?? '',
      eventCount: (json['events'] as List?)?.length ?? 0,
      taskCount: (json['tasks'] as List?)?.length ?? 0,
      sessionCount: (json['focus_sessions'] as List?)?.length ?? 0,
      projectCount: (json['projects'] as List?)?.length ?? 0,
      tagCount: (json['tags'] as List?)?.length ?? 0,
    );
  }
}

class BackupRestoreSummary {
  final int eventsRestored;
  final int tasksRestored;
  final int focusSessionsRestored;
  final int projectsRestored;
  final int tagsRestored;

  /// Optional with a default so existing call sites keep compiling.
  final int habitsRestored;
  final String exportedAt;

  const BackupRestoreSummary({
    required this.eventsRestored,
    required this.tasksRestored,
    required this.focusSessionsRestored,
    required this.projectsRestored,
    required this.tagsRestored,
    this.habitsRestored = 0,
    required this.exportedAt,
  });
}

class BackupService {
  final AppDatabase db;
  final ReminderService? reminderService;
  final BackupCryptoEngine _cryptoEngine;

  BackupService({
    required this.db,
    this.reminderService,
    BackupCryptoEngine? cryptoEngine,
  })  : _cryptoEngine = cryptoEngine ?? BackupCryptoEngine();

  /// Serializes the database and encrypts it with [password].
  Future<Uint8List> createEncryptedBackup({required String password}) async {
    final events = (await db.select(db.events).get())
        .map((e) => e.toJson())
        .toList();
    final focusSessions = (await db.select(db.focusSessions).get())
        .map((e) => e.toJson())
        .toList();
    final tasks = (await db.select(db.tasks).get())
        .map((e) => e.toJson())
        .toList();
    final projects = (await db.select(db.projects).get())
        .map((e) => e.toJson())
        .toList();
    final tags = (await db.select(db.tags).get())
        .map((e) => e.toJson())
        .toList();
    final taskTags = (await db.select(db.taskTags).get())
        .map((e) => e.toJson())
        .toList();
    final settings = (await db.select(db.settings).get())
        .map((e) => e.toJson())
        .toList();
    // Habits (SPEC.md §10). Every table in the schema must appear here, or a
    // backup silently drops a whole module while still reporting the schema
    // version that contains it.
    final habits = (await db.select(db.habits).get())
        .map((e) => e.toJson())
        .toList();
    final habitEntries = (await db.select(db.habitEntries).get())
        .map((e) => e.toJson())
        .toList();
    // Reminder config (SPEC.md §10.4/§11): a task's countdown offsets and a
    // habit's times-of-day. Same rule applies — leaving these out means a
    // restored task or habit silently loses every reminder it had.
    final taskReminderOffsets = (await db.select(db.taskReminderOffsets).get())
        .map((e) => e.toJson())
        .toList();
    final habitReminderTimes = (await db.select(db.habitReminderTimes).get())
        .map((e) => e.toJson())
        .toList();

    final payload = {
      'format_version': 1,
      'schema_version': db.schemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'events': events,
      'focus_sessions': focusSessions,
      'tasks': tasks,
      'projects': projects,
      'tags': tags,
      'task_tags': taskTags,
      'settings': settings,
      'habits': habits,
      'habit_entries': habitEntries,
      'task_reminder_offsets': taskReminderOffsets,
      'habit_reminder_times': habitReminderTimes,
    };

    final jsonString = jsonEncode(payload);
    return _cryptoEngine.encrypt(jsonString, password);
  }

  /// Decrypts [backupBytes] with [password] and returns metadata preview without modifying the database.
  Future<BackupManifest> inspectBackup({
    required Uint8List backupBytes,
    required String password,
  }) async {
    final clearText = await _cryptoEngine.decrypt(backupBytes, password);
    final json = jsonDecode(clearText) as Map<String, dynamic>;
    return BackupManifest.fromJson(json);
  }

  /// Decrypts [backupBytes] with [password] and restores into the database inside an atomic transaction.
  Future<BackupRestoreSummary> restoreFromEncryptedBackup({
    required Uint8List backupBytes,
    required String password,
  }) async {
    final clearText = await _cryptoEngine.decrypt(backupBytes, password);
    final json = jsonDecode(clearText) as Map<String, dynamic>;

    final formatVersion = json['format_version'] as int? ?? 1;
    if (formatVersion > 1) {
      throw const FormatException('Unsupported backup format version.');
    }

    final rawEvents = (json['events'] as List?) ?? [];
    final rawSessions = (json['focus_sessions'] as List?) ?? [];
    final rawTasks = (json['tasks'] as List?) ?? [];
    final rawProjects = (json['projects'] as List?) ?? [];
    final rawTags = (json['tags'] as List?) ?? [];
    final rawTaskTags = (json['task_tags'] as List?) ?? [];
    final rawSettings = (json['settings'] as List?) ?? [];
    // Absent in backups written before §10 shipped; an empty list restores
    // those correctly rather than failing.
    final rawHabits = (json['habits'] as List?) ?? [];
    final rawHabitEntries = (json['habit_entries'] as List?) ?? [];
    // Absent in backups written before §11's reminder redesign shipped.
    final rawTaskReminderOffsets = (json['task_reminder_offsets'] as List?) ?? [];
    final rawHabitReminderTimes = (json['habit_reminder_times'] as List?) ?? [];
    final exportedAt = json['exported_at'] as String? ?? '';

    await db.transaction(() async {
      await db.customStatement('PRAGMA foreign_keys = OFF;');

      // Delete existing data
      await db.delete(db.habitReminderTimes).go();
      await db.delete(db.taskReminderOffsets).go();
      await db.delete(db.habitEntries).go();
      await db.delete(db.habits).go();
      await db.delete(db.taskTags).go();
      await db.delete(db.tags).go();
      await db.delete(db.tasks).go();
      await db.delete(db.projects).go();
      await db.delete(db.focusSessions).go();
      await db.delete(db.events).go();
      await db.delete(db.settings).go();

      // Insert restored data
      if (rawSettings.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(
            db.settings,
            rawSettings.map((s) => Setting.fromJson(s as Map<String, dynamic>)),
          );
        });
      }

      if (rawProjects.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(
            db.projects,
            rawProjects.map((p) => Project.fromJson(p as Map<String, dynamic>)),
          );
        });
      }

      if (rawTasks.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(
            db.tasks,
            rawTasks.map((t) => Task.fromJson(t as Map<String, dynamic>)),
          );
        });
      }

      if (rawTags.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(
            db.tags,
            rawTags.map((t) => Tag.fromJson(t as Map<String, dynamic>)),
          );
        });
      }

      if (rawTaskTags.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(
            db.taskTags,
            rawTaskTags.map((tt) => TaskTag.fromJson(tt as Map<String, dynamic>)),
          );
        });
      }

      if (rawSessions.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(
            db.focusSessions,
            rawSessions.map((s) => FocusSession.fromJson(s as Map<String, dynamic>)),
          );
        });
      }

      if (rawHabits.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(
            db.habits,
            rawHabits.map((h) => Habit.fromJson(h as Map<String, dynamic>)),
          );
        });
      }

      if (rawHabitEntries.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(
            db.habitEntries,
            rawHabitEntries
                .map((e) => HabitEntry.fromJson(e as Map<String, dynamic>)),
          );
        });
      }

      if (rawTaskReminderOffsets.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(
            db.taskReminderOffsets,
            rawTaskReminderOffsets.map(
                (e) => TaskReminderOffset.fromJson(e as Map<String, dynamic>)),
          );
        });
      }

      if (rawHabitReminderTimes.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(
            db.habitReminderTimes,
            rawHabitReminderTimes.map(
                (e) => HabitReminderTime.fromJson(e as Map<String, dynamic>)),
          );
        });
      }

      if (rawEvents.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(
            db.events,
            rawEvents.map((e) => Event.fromJson(e as Map<String, dynamic>)),
          );
        });
      }

      await db.customStatement('PRAGMA foreign_keys = ON;');
    });

    // Reconcile reminders with the newly restored tasks
    try {
      await reminderService?.reconcileAll();
    } catch (_) {
      // Non-fatal if platform notifications are uninitialized in test environments
    }

    return BackupRestoreSummary(
      eventsRestored: rawEvents.length,
      tasksRestored: rawTasks.length,
      focusSessionsRestored: rawSessions.length,
      projectsRestored: rawProjects.length,
      tagsRestored: rawTags.length,
      habitsRestored: rawHabits.length,
      exportedAt: exportedAt,
    );
  }

  /// Returns current counts of sessions, tasks and habits in the database for
  /// restore confirmation — everything the restore is about to delete.
  Future<({int sessionCount, int taskCount, int habitCount})>
      getCurrentDataCounts() async {
    final sessions = await db.select(db.focusSessions).get();
    final tasks = await db.select(db.tasks).get();
    final habits = await db.select(db.habits).get();
    return (
      sessionCount: sessions.length,
      taskCount: tasks.length,
      habitCount: habits.length,
    );
  }
}
