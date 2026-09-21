import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../data/repositories/settings_repository.dart';

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

  /// Settings key recording that the "you just made your first thing" prompt
  /// has already been shown, so it never reappears on later creations.
  static const firstItemPromptedKey = 'notif_first_item_prompted';

  /// Asks for notification permission the first time the user creates a task
  /// or a habit.
  ///
  /// Reminders are not an opt-in extra the user goes looking for: a new dated
  /// task is given the default reminder offset the moment it is created, and
  /// a habit with a reminder time schedules one straight away. Waiting until
  /// someone opens the reminder editor meant that first reminder could be
  /// scheduled against a permission nobody had asked for, and it would simply
  /// never fire. Asking once, right after there is finally something worth
  /// being reminded about, is both the earliest useful moment and the easiest
  /// one to say yes to.
  ///
  /// Only ever prompts once — the flag is persisted, so declining is
  /// remembered across restarts and this never becomes a nag. Reminder
  /// editors and the timer still call [ensureNotificationPermission]
  /// directly, which is the "and when necessary" half.
  static Future<void> ensureOnFirstItemCreated(
    BuildContext context,
    SettingsRepository settingsRepo,
  ) async {
    if (kIsWeb) return;
    try {
      final alreadyPrompted = await settingsRepo.getInt(firstItemPromptedKey);
      if (alreadyPrompted == 1) return;
      await settingsRepo.setInt(firstItemPromptedKey, 1);
    } catch (_) {
      // A settings read/write failure must never block creating a task.
      return;
    }
    if (!context.mounted) return;
    await ensureNotificationPermission(context);
  }
}
