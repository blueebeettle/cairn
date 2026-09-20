import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/features/backup/domain/data_export_service.dart';

void main() {
  late AppDatabase db;
  late DataExportService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = DataExportService(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('generateHabitsCsv exports headers and habit rows correctly', () async {
    // Insert a habit
    await db.into(db.habits).insert(
          HabitsCompanion.insert(
            id: 'habit-1',
            title: 'Daily Reading',
            scheduleRule: 'FREQ=DAILY',
            anchorDate: '2026-09-01',
            targetCount: const Value(2),
            unitLabel: const Value('chapters'),
            status: const Value('active'),
            createdAt: 1726830000000,
            createdLocalDate: '2026-09-01',
            deviceId: 'device-1',
            updatedAt: 1726830000000,
          ),
        );

    // Insert an entry
    await db.into(db.habitEntries).insert(
          HabitEntriesCompanion.insert(
            id: 'entry-1',
            habitId: 'habit-1',
            localDate: '2026-09-20',
            checkCount: const Value(2),
            skipped: const Value(false),
            note: const Value('Read chapter 1 and 2'),
            createdAt: 1726830000000,
            deviceId: 'device-1',
            tzOffsetMin: 330,
            updatedAt: 1726830000000,
          ),
        );

    final csv = await service.generateHabitsCsv();
    expect(csv, contains('Habit Title,Status,Schedule,Target Count,Unit,Date,Check Count,Completed,Skipped,Note,Last Checked At'));
    expect(csv, contains('Daily Reading,active,FREQ=DAILY,2,chapters,2026-09-20,2,YES,NO,Read chapter 1 and 2'));
  });

  test('generateFocusSessionsCsv exports focus sessions correctly', () async {
    await db.into(db.focusSessions).insert(
          FocusSessionsCompanion.insert(
            id: 'session-1',
            mode: 'pomodoro',
            plannedDurationS: const Value(1500),
            actualDurationS: const Value(1500),
            startedAt: 1726830000000,
            endedAt: 1726831500000,
            localDate: '2026-09-20',
            tzOffsetMin: 330,
            taskId: const Value('task-100'),
            outcome: 'completed',
            deviceId: 'device-1',
            updatedAt: 1726831500000,
          ),
        );

    final csv = await service.generateFocusSessionsCsv();
    expect(csv, contains('Date,Mode,Planned Minutes,Actual Minutes,Started At,Ended At,Task ID,Project ID'));
    expect(csv, contains('2026-09-20,pomodoro,25,25'));
    expect(csv, contains('task-100'));
  });
}
