import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/time/time_service.dart';
import 'data/database/app_database.dart';
import 'data/providers/database_provider.dart';
import 'data/repositories/settings_repository.dart';
import 'features/backup/domain/supabase_backup_service.dart';
import 'features/reminders/reminder_service.dart';
import 'features/widgets/home_screen_widget_service.dart';

/// Startup is deliberately split in two.
///
/// Everything in [main] below runs before the first frame, so it must stay
/// fast: opening the database, resolving the device id and timezone, and
/// wiring up the notification plugin/channel (cheap — no database scan, no
/// network). Everything slow and deferrable — reconciling every task's and
/// habit's reminders, and Supabase's network-touching initialize() — moves
/// into [_finishStartup], kicked off *after* runApp() so the UI paints
/// immediately instead of sitting on a blank screen for however long that
/// work takes. This is the fix for the app taking 2-3s to open: previously
/// every step below ran in one sequential chain before anything rendered.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
  }

  // Must run here, before runApp() and before any TimerController is built.
  // This registers the SendPort the foreground-service isolate looks up when
  // a notification button is pressed; without it every press is silently
  // dropped. It used to be called lazily from TimerForegroundService.init(),
  // which only runs when a session is *started* from inside the app — so
  // after the process restarted with a session already running, the port was
  // never registered and Pause/Resume/Skip did nothing.
  if (!kIsWeb && Platform.isAndroid) {
    FlutterForegroundTask.initCommunicationPort();
  }
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

  // Channel/plugin setup only — no database scan yet, so this stays on the
  // synchronous path. scheduleFor()/scheduleForHabit() call straight into
  // the notification plugin with no "is it initialized" guard, so this must
  // complete before any screen can be interacted with.
  await reminderService.initialize(tzId: tzId);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FocusStackApp(),
    ),
  );

  // Fire-and-forget: the UI is already on screen by the time this runs.
  unawaited(_finishStartup(
    reminderService: reminderService,
    settingsRepo: settingsRepo,
  ));
}

/// The slow, deferrable half of startup — see the [main] doc comment.
///
/// Reconciling reminders touches every open task and habit in the database;
/// Supabase.initialize() makes a network call. Neither gates the first
/// frame. [SupabaseBackupService.ensureInitialized] already re-initializes
/// Supabase defensively (and treats "already initialized" as success) before
/// any backup/auth action, so a user reaching the Backup screen before this
/// finishes is already handled — this isn't a new risk this split
/// introduces.
Future<void> _finishStartup({
  required ReminderService reminderService,
  required SettingsRepository settingsRepo,
}) async {
  try {
    await reminderService.reconcileAll();
    await reminderService.dispatchLaunchNotification();
  } catch (e) {
    debugPrint('Deferred reminder startup failed: $e');
  }

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
}
