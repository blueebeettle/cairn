import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/features/backup/presentation/backup_restore_screen.dart';
import 'package:habit_tracker/features/settings/presentation/settings_screen.dart';
import 'package:habit_tracker/features/stats/presentation/stats_screen.dart';
import 'package:habit_tracker/features/tasks/presentation/archived_tasks_screen.dart';
import 'package:habit_tracker/features/tasks/presentation/tasks_screen.dart';
import 'package:habit_tracker/features/tasks/presentation/widgets/task_detail_sheet.dart';
import 'package:habit_tracker/features/timer/presentation/timer_screen.dart';
import 'package:habit_tracker/features/today/presentation/today_screen.dart';
import 'package:habit_tracker/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('200% Font Scale Audit (POLISH §6)', () {
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Widget createScaledApp(Widget child, WidgetTester tester) {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
              size: Size(360, 800),
            ),
            child: child,
          ),
        ),
      );
    }

    testWidgets('TodayScreen renders at 200% font scale with zero overflow exceptions', (tester) async {
      await tester.pumpWidget(createScaledApp(const TodayScreen(), tester));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('TimerScreen renders at 200% font scale with zero overflow exceptions', (tester) async {
      await tester.pumpWidget(createScaledApp(const TimerScreen(), tester));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('TasksScreen renders at 200% font scale with zero overflow exceptions', (tester) async {
      await tester.pumpWidget(createScaledApp(const TasksScreen(), tester));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('StatsScreen renders at 200% font scale with zero overflow exceptions', (tester) async {
      await tester.pumpWidget(createScaledApp(const StatsScreen(), tester));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('SettingsScreen renders at 200% font scale with zero overflow exceptions', (tester) async {
      await tester.pumpWidget(createScaledApp(const SettingsScreen(), tester));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('BackupRestoreScreen renders at 200% font scale with zero overflow exceptions', (tester) async {
      await tester.pumpWidget(createScaledApp(const BackupRestoreScreen(), tester));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ArchivedTasksScreen renders at 200% font scale with zero overflow exceptions', (tester) async {
      await tester.pumpWidget(createScaledApp(const ArchivedTasksScreen(), tester));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('TaskDetailSheet renders at 200% font scale with zero overflow exceptions', (tester) async {
      await tester.pumpWidget(createScaledApp(
        const Scaffold(body: TaskDetailSheet()),
        tester,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
