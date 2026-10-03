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
import 'data/providers/onboarding_providers.dart';
import 'data/repositories/settings_repository.dart';
import 'features/backup/domain/supabase_backup_service.dart';
import 'features/reminders/reminder_service.dart';
import 'features/startup/presentation/startup_error_screen.dart';
import 'features/widgets/home_screen_widget_service.dart';

/// Startup is deliberately split in two. Everything in [attemptStartup] runs
/// before the first frame, so it must stay fast: opening the database,
/// resolving the device id and timezone, and wiring up the notification
/// plugin/channel (cheap: no database scan, no network). Everything slow and
/// deferrable (reconciling every task's and habit's reminders, and Supabase's
/// network-touching initialize()) moves into [_finishStartup], kicked off
/// *after* runApp() so the UI paints immediately. Previously every step ran in
/// one sequential chain before anything rendered, which made the app take 2-3s
/// to open.
///
/// Result of independent bootstrap steps run concurrently at startup.
class StartupBootstrapResult {
  const StartupBootstrapResult({
    required this.tzId,
    required this.deviceId,
    required this.dayStartOffset,
  });

  final String tzId;
  final String deviceId;
  final int dayStartOffset;
}

/// Runs independent startup steps concurrently via [Future.wait]:
/// - HomeWidget platform callback registration
/// - Timezone resolution via platform channel
/// - Both settings DB queries (deviceId and day_start_offset)
Future<StartupBootstrapResult> runStartupBootstrap({
  required SettingsRepository settingsRepo,
  required Future<void> Function() registerHomeWidgetCallback,
  required Future<String> Function() resolveTimezone,
}) async {
  final startupResults = await Future.wait([
    registerHomeWidgetCallback(),
    resolveTimezone(),
    settingsRepo.getOrCreateDeviceId(),
    settingsRepo.getInt('day_start_offset'),
  ]);

  final tzId = startupResults[1] as String;
  final deviceId = startupResults[2] as String;
  final dayStartOffset = (startupResults[3] as int?) ?? 240;

  return StartupBootstrapResult(
    tzId: tzId,
    deviceId: deviceId,
    dayStartOffset: dayStartOffset,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isAndroid) {
    FlutterForegroundTask.initCommunicationPort();
  }

  await launchApp(
    attempt: () => attemptStartup(
      openDatabase: AppDatabase.new,
      registerHomeWidgetCallback: _registerHomeWidgetCallback,
      resolveTimezone: _resolveTimezone,
      initializeReminders: (reminderService, tzId) =>
          reminderService.initialize(tzId: tzId),
    ),
  );
}

Future<void> _registerHomeWidgetCallback() async {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
  }
}

Future<String> _resolveTimezone() async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (_) {
    return '';
  }
}

/// What a successful [attemptStartup] hands to [launchApp].
class StartedApp {
  const StartedApp({required this.app, required this.finishStartup});

  final Widget app;

  /// The deferred half of startup; see [_finishStartup].
  final Future<void> Function() finishStartup;
}

/// Runs [attempt] and shows the app, or a [StartupErrorScreen] if it throws.
///
/// "Try again" calls back in here, so a retry that succeeds replaces the error
/// screen with the app exactly as a first-time success would, and one that
/// fails shows the error screen again.
///
/// [show] is [runApp] outside tests: the test binding's `runApp` runs a frame
/// synchronously and so defers everything after it.
Future<void> launchApp({
  required Future<StartedApp> Function() attempt,
  void Function(Widget) show = runApp,
  int attemptNumber = 1,
}) async {
  final StartedApp started;
  try {
    started = await attempt();
  } catch (error, stackTrace) {
    debugPrint('Startup failed (attempt $attemptNumber): $error\n$stackTrace');
    show(
      StartupErrorScreen(
        error: error,
        stackTrace: stackTrace,
        attempt: attemptNumber,
        onRetry: () => launchApp(
          attempt: attempt,
          show: show,
          attemptNumber: attemptNumber + 1,
        ),
      ),
    );
    return;
  }

  show(started.app);

  // Fire-and-forget: the UI is already on screen by the time this runs.
  unawaited(started.finishStartup());
}

/// One pass through the pre-first-frame startup sequence, with its
/// dependencies passed in so a test can make any step fail.
///
/// If anything throws, the database this attempt opened is closed before the
/// error propagates, so a retry never meets a connection left over from the
/// failed one.
Future<StartedApp> attemptStartup({
  required AppDatabase Function() openDatabase,
  required Future<void> Function() registerHomeWidgetCallback,
  required Future<String> Function() resolveTimezone,
  required Future<void> Function(ReminderService reminderService, String tzId)
      initializeReminders,
}) async {
  final db = openDatabase();
  try {
    return await _buildApp(
      db,
      registerHomeWidgetCallback: registerHomeWidgetCallback,
      resolveTimezone: resolveTimezone,
      initializeReminders: initializeReminders,
    );
  } catch (_) {
    try {
      await db.close();
    } catch (e) {
      debugPrint('Closing the database after a failed startup: $e');
    }
    rethrow;
  }
}

Future<StartedApp> _buildApp(
  AppDatabase db, {
  required Future<void> Function() registerHomeWidgetCallback,
  required Future<String> Function() resolveTimezone,
  required Future<void> Function(ReminderService reminderService, String tzId)
      initializeReminders,
}) async {
  final settingsRepo = SettingsRepository(db: db);

  final bootstrap = await runStartupBootstrap(
    settingsRepo: settingsRepo,
    registerHomeWidgetCallback: registerHomeWidgetCallback,
    resolveTimezone: resolveTimezone,
  );

  final tzId = bootstrap.tzId;
  final deviceId = bootstrap.deviceId;
  final dayStartOffset = bootstrap.dayStartOffset;

  // The first-run tutorial's flag: its own read *after* runStartupBootstrap
  // rather than a fifth entry in its Future.wait, so the bootstrap's steps and
  // timing stay as the startup parallelisation made them. One indexed lookup on
  // a database the bootstrap already opened.
  final onboardingCompleted = await loadOnboardingCompleted(settingsRepo);

  final timeService = TimeService(
    dayStartOffsetMinutes: dayStartOffset,
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
      initialOnboardingCompletedProvider.overrideWithValue(onboardingCompleted),
    ],
  );

  // Channel/plugin setup only — no database scan yet, so this stays on the
  // synchronous path. scheduleFor()/scheduleForHabit() call straight into
  // the notification plugin with no "is it initialized" guard, so this must
  // complete before any screen can be interacted with.
  await initializeReminders(reminderService, tzId);

  return StartedApp(
    app: UncontrolledProviderScope(
      container: container,
      child: const FocusStackApp(),
    ),
    finishStartup: () => _finishStartup(
      reminderService: reminderService,
      settingsRepo: settingsRepo,
    ),
  );
}

/// The slow, deferrable half of startup; see the [main] doc comment.
///
/// Reconciling reminders touches every open task and habit;
/// Supabase.initialize() makes a network call. Neither gates the first frame.
/// [SupabaseBackupService.ensureInitialized] already re-initializes Supabase
/// defensively (treating "already initialized" as success) before any
/// backup/auth action, so a user reaching the Backup screen before this
/// finishes is already handled.
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
