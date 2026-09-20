import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Helper for requesting notification permission with a pre-dialog per PROMPT-reminders.md §Part C.
class NotificationPermissionHelper {
  static bool _hasPromptedThisSession = false;

  /// Mock permission granted state for unit and widget testing.
  @visibleForTesting
  static bool? mockPermissionGranted;

  /// Resets the session flag and test mock (primarily for tests).
  @visibleForTesting
  static void resetSessionPrompt() {
    _hasPromptedThisSession = false;
    mockPermissionGranted = null;
  }

  /// Ensures notification permission is granted.
  ///
  /// Shows a pre-dialog before triggering the system permission request on Android 13+.
  /// If dismissed or denied, does not prompt again within the same app session.
  static Future<bool> ensureNotificationPermission(BuildContext context) async {
    if (kIsWeb) return true;

    // 1. Check if already granted
    if (mockPermissionGranted != null) {
      if (mockPermissionGranted!) return true;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final status = await FlutterForegroundTask.checkNotificationPermission();
        if (status == NotificationPermission.granted) {
          return true;
        }
      } catch (_) {}
    }

    // 2. Avoid nagging if already prompted during this session
    if (_hasPromptedThisSession) {
      return false;
    }
    _hasPromptedThisSession = true;

    if (!context.mounted) return false;

    // 3. Show pre-dialog
    final shouldContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Let Cairn notify you?'),
        content: const Text(
          'Cairn uses notifications to tell you when a focus session ends and to remind '
          'you about tasks before they are due. Without them the timer still runs, but '
          'you will only see it when the app is open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (shouldContinue != true) {
      return false;
    }

    // 4. Request system permission
    if (mockPermissionGranted != null) {
      return mockPermissionGranted!;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final granted =
            await FlutterForegroundTask.requestNotificationPermission();
        return granted == NotificationPermission.granted;
      } catch (_) {
        return false;
      }
    }

    return true;
  }
}
