import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SettingsRepository — SPEC.md §2.5', () {
    test('stores and retrieves JSON-encoded strings', () async {
      await repo.setString('theme_mode', 'dark');
      expect(await repo.getString('theme_mode'), equals('dark'));
      expect(await repo.get('theme_mode'), equals('dark'));
    });

    test('stores and retrieves JSON-encoded integers', () async {
      await repo.setInt('day_start_offset', 300);
      expect(await repo.getInt('day_start_offset'), equals(300));
      expect(await repo.get('day_start_offset'), equals(300));
    });

    test('stores and retrieves JSON-encoded booleans', () async {
      await repo.setBool('sound_enabled', true);
      expect(await repo.getBool('sound_enabled'), isTrue);
    });

    test('upsert updates existing key', () async {
      await repo.setString('test_key', 'initial');
      expect(await repo.getString('test_key'), equals('initial'));

      await repo.setString('test_key', 'updated');
      expect(await repo.getString('test_key'), equals('updated'));
    });

    test('returns null for nonexistent keys', () async {
      expect(await repo.get('nonexistent'), isNull);
      expect(await repo.getString('nonexistent'), isNull);
      expect(await repo.getInt('nonexistent'), isNull);
      expect(await repo.getBool('nonexistent'), isNull);
    });

    test('deletes keys correctly', () async {
      await repo.setString('to_delete', 'value');
      expect(await repo.getString('to_delete'), equals('value'));

      await repo.delete('to_delete');
      expect(await repo.getString('to_delete'), isNull);
    });
  });

  group('Persistent Settings Providers (survive app restart)', () {
    test('ThemeModeNotifier persists and survives app restart', () async {
      // First session: default is system
      final notifier1 = ThemeModeNotifier(repo);
      expect(notifier1.state, equals(ThemeMode.system));

      // User switches to dark mode
      notifier1.state = ThemeMode.dark;
      expect(notifier1.state, equals(ThemeMode.dark));

      // Verify row in database
      await Future.delayed(const Duration(milliseconds: 10));
      expect(await repo.getString('theme_mode'), equals('dark'));

      // Simulate app restart: fresh notifier instance over same DB
      final notifier2 = ThemeModeNotifier(repo);
      // Wait for async load from settings table
      await Future.delayed(const Duration(milliseconds: 20));
      expect(notifier2.state, equals(ThemeMode.dark));
    });

    test('DayStartOffsetNotifier persists and survives app restart', () async {
      // First session: default is 240 (04:00 AM)
      final notifier1 = DayStartOffsetNotifier(repo);
      expect(notifier1.state, equals(240));

      // User changes day start to 300 (05:00 AM)
      notifier1.state = 300;
      expect(notifier1.state, equals(300));

      await Future.delayed(const Duration(milliseconds: 10));
      expect(await repo.getInt('day_start_offset'), equals(300));

      // Simulate app restart
      final notifier2 = DayStartOffsetNotifier(repo);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(notifier2.state, equals(300));
    });

    test('DailyGoalMinutesNotifier persists and survives app restart', () async {
      // First session: default is 25 minutes
      final notifier1 = DailyGoalMinutesNotifier(repo);
      expect(notifier1.state, equals(25));

      // User changes daily goal to 45 minutes
      notifier1.state = 45;
      expect(notifier1.state, equals(45));

      await Future.delayed(const Duration(milliseconds: 10));
      expect(await repo.getInt('daily_goal_minutes'), equals(45));

      // Simulate app restart
      final notifier2 = DailyGoalMinutesNotifier(repo);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(notifier2.state, equals(45));
    });
  });
}
