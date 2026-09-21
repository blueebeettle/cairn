import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../widgets/home_screen_widget_service.dart';

/// The port name flutter_foreground_task registers in [IsolateNameServer]
/// from `FlutterForegroundTask.initCommunicationPort()`.
///
/// The package exposes `sendDataToMain()` but no way to ask whether anything
/// is actually listening, and that distinction is exactly what decides
/// between handing a button press to the live UI and applying it to the
/// database directly. Mirrored here deliberately. If the package ever renames
/// it this lookup just returns null and every press takes the database path —
/// still correct, only without the instant on-screen update.
const String _kForegroundTaskPortName =
    'flutter_foreground_task/isolateComPort';

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
    // Fast path: the app is alive, so hand the press to TimerController and
    // let it update the visible UI immediately.
    final SendPort? mainIsolate =
        IsolateNameServer.lookupPortByName(_kForegroundTaskPortName);
    if (mainIsolate != null) {
      mainIsolate.send({'action': id});
      return;
    }

    // No main isolate — the app process is gone while this service kept
    // running. FlutterForegroundTask.sendDataToMain() would look up the same
    // (absent) port and silently drop the press, which is why these buttons
    // appeared dead after the app was killed. Write straight to the database
    // instead, exactly as the home-screen widget's buttons do; the app
    // re-derives from it on next resume.
    //
    // 'skip' mid-session means the same thing the widget's Stop does: bail
    // out early and abandon. A running *break* is deliberately left alone
    // here (the widget guards it the same way) — the in-app path handles
    // break skipping when there is a UI to handle it.
    unawaited(applyTimerActionFromBackground(id == 'skip' ? 'stop' : id));
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

    if (IsolateNameServer.lookupPortByName(_kForegroundTaskPortName) == null) {
      FlutterForegroundTask.initCommunicationPort();
    }

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
