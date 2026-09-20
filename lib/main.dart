import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/time/time_service.dart';
import 'data/database/app_database.dart';
import 'data/providers/database_provider.dart';
import 'data/repositories/settings_repository.dart';
import 'features/backup/domain/supabase_backup_service.dart';
import 'features/reminders/reminder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final settingsRepo = SettingsRepository(db: db);
  final deviceId = await settingsRepo.getOrCreateDeviceId();

  // SPEC §1.2 — a real IANA id, not a platform abbreviation.
  var tzId = '';
  try {
    tzId = (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (_) {
    // Plugin unavailable or the platform refused. tz_id is diagnostic only —
    // every calculation runs off tz_offset_min, which is read live — so an
    // empty id degrades the logs, not the numbers.
  }

  // The saved day start matters here: habit reminders are placed on logical
  // days (SPEC §1.2), and a default of 04:00 would misplace every reminder
  // for someone whose day starts at 05:00.
  final timeService = TimeService(
    dayStartOffsetMinutes:
        await settingsRepo.getInt('day_start_offset') ?? 240,
    tzIdProvider: tzId.isEmpty ? null : () => tzId,
  );

  // The container exists before the reminder service so a tapped
  // notification can navigate. The callbacks close over it lazily; they can
  // only fire after initialize(), by which point it is assigned.
  late final ProviderContainer container;
  final reminderService = ReminderService(
    db: db,
    settingsRepo: settingsRepo,
    timeService: timeService,
    onNotificationTapped: (taskId) {
      container.read(activeTaskIdProvider.notifier).state = taskId;
      container.read(navigationIndexProvider.notifier).state = NavTabs.tasks;
    },
    onHabitNotificationTapped: (habitId) {
      container.read(navigationIndexProvider.notifier).state = NavTabs.habits;
      container.read(pendingHabitDetailProvider.notifier).state = habitId;
    },
  );
  container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue(deviceId),
      deviceTzIdProvider.overrideWithValue(tzId),
      reminderServiceProvider.overrideWithValue(reminderService),
    ],
  );
  await reminderService.initialize(tzId: tzId);
  await reminderService.reconcileAll();
  await reminderService.dispatchLaunchNotification();

  // Initialize Supabase project
  String? supabaseUrl = await settingsRepo.getString('supabase_url');
  String? supabaseKey = await settingsRepo.getString('supabase_anon_key');
  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    supabaseUrl = SupabaseBackupService.defaultUrl;
    supabaseKey = SupabaseBackupService.defaultAnonKey;
    await settingsRepo.setString('supabase_url', supabaseUrl);
    await settingsRepo.setString('supabase_anon_key', supabaseKey);
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey ?? SupabaseBackupService.defaultAnonKey,
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: !Platform.environment.containsKey('FLUTTER_TEST'),
      ),
    );
  } catch (e) {
    debugPrint('Supabase initialization: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FocusStackApp(),
    ),
  );
}
