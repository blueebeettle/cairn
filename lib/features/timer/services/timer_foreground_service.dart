import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Top-level callback required by flutter_foreground_task.
@pragma('vm:entry-point')
void startForegroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(TimerTaskHandler());
}

/// TaskHandler running in the background isolate to handle notification button events.
class TimerTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isDone) async {}

  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain({'action': id});
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}

/// Service managing the Android foreground service per SPEC.md §3.4.
///
/// Features:
/// - Live remaining time display in persistent notification.
/// - 'Pause'/'Resume' and 'Skip' notification actions.
/// - Platform guard: Graceful no-op on desktop / non-Android platforms and unit tests.
/// - Safe degraded mode when POST_NOTIFICATIONS permission is denied.
class TimerForegroundService {
  TimerForegroundService();

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool _initialized = false;
  bool _permissionDenied = false;

  bool get isPermissionDenied => _permissionDenied;

  /// Initializes the foreground service configuration.
  Future<void> init() async {
    if (!isSupported || _initialized) return;

    FlutterForegroundTask.initCommunicationPort();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'focus_timer_channel',
        channelName: 'Focus Timer',
        channelDescription:
            'Shows active focus session status and timer controls.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    _initialized = true;
  }

  /// Requests POST_NOTIFICATIONS permission (Android 13+).
  ///
  /// Returns true if granted or not required; false if denied.
  Future<bool> requestNotificationPermission() async {
    if (!isSupported) return true;

    final current = await FlutterForegroundTask.checkNotificationPermission();
    if (current == NotificationPermission.granted) {
      _permissionDenied = false;
      return true;
    }

    final requested =
        await FlutterForegroundTask.requestNotificationPermission();
    final granted = requested == NotificationPermission.granted;
    _permissionDenied = !granted;
    return granted;
  }

  /// Starts the foreground service with Pause/Resume and Skip actions.
  Future<void> startService({
    required String title,
    required String text,
    required bool isPaused,
  }) async {
    if (!isSupported) return;
    await init();

    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      await updateService(title: title, text: text, isPaused: isPaused);
      return;
    }

    final buttons = [
      NotificationButton(
        id: isPaused ? 'resume' : 'pause',
        text: isPaused ? 'Resume' : 'Pause',
      ),
      const NotificationButton(
        id: 'skip',
        text: 'Skip',
      ),
    ];

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: title,
      notificationText: text,
      notificationButtons: buttons,
      callback: startForegroundTaskCallback,
    );
  }

  /// Updates the notification content and action buttons.
  Future<void> updateService({
    required String title,
    required String text,
    required bool isPaused,
  }) async {
    if (!isSupported) return;

    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) return;

    final buttons = [
      NotificationButton(
        id: isPaused ? 'resume' : 'pause',
        text: isPaused ? 'Resume' : 'Pause',
      ),
      const NotificationButton(
        id: 'skip',
        text: 'Skip',
      ),
    ];

    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
      notificationButtons: buttons,
    );
  }

  /// Stops the foreground service.
  Future<void> stopService() async {
    if (!isSupported) return;
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      await FlutterForegroundTask.stopService();
    }
  }
}
