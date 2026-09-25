/// Channel identity, action ids and [NotificationDetails] for every reminder
/// notification.
///
/// Lives apart from `ReminderService` because the background action handler
/// needs the same constants and runs in an isolate that must not import the
/// service (it owns a Riverpod provider and a live plugin). Both sides import
/// this instead.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The channel reminders and digests post to.
const String reminderChannelId = 'task_reminders';
const String reminderChannelName = 'Task reminders';
const String reminderChannelDescription =
    'Reminders for upcoming tasks and habits';

/// Action id for the "Mark done" button on task and habit reminders.
const String actionMarkDone = 'mark_done';

/// Action id for the "Snooze 15 min" button.
const String actionSnooze = 'snooze_15';

/// How far [actionSnooze] pushes a reminder out.
const Duration snoozeDuration = Duration(minutes: 15);

/// Importance/priority are [Importance.high]/[Priority.high] so reminders
/// arrive as a heads-up banner rather than sliding silently into the shade.
/// Delivering on time is only half of "on time" if nobody sees it.
const Importance reminderImportance = Importance.high;
const Priority reminderPriority = Priority.high;

/// The channel itself. Note that Android freezes a channel's importance at
/// creation: on an install that already has the old default-importance
/// channel, this raised value only takes effect after the app's notification
/// settings are reset or the app is reinstalled. New installs get it directly.
const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
  reminderChannelId,
  reminderChannelName,
  description: reminderChannelDescription,
  importance: reminderImportance,
);

const List<AndroidNotificationAction> _reminderActions = [
  AndroidNotificationAction(
    actionMarkDone,
    'Mark done',
    // Handled entirely in the background isolate; there is nothing to show.
    showsUserInterface: false,
    cancelNotification: true,
  ),
  AndroidNotificationAction(
    actionSnooze,
    'Snooze 15 min',
    showsUserInterface: false,
    cancelNotification: true,
  ),
];

/// Details for an actionable task or habit reminder.
const NotificationDetails actionableReminderDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    reminderChannelId,
    reminderChannelName,
    channelDescription: reminderChannelDescription,
    importance: reminderImportance,
    priority: reminderPriority,
    actions: _reminderActions,
  ),
  iOS: DarwinNotificationDetails(categoryIdentifier: reminderCategoryId),
);

/// Details for the digests, which carry no actions — a digest summarises
/// several items, so "Mark done" would have nothing unambiguous to act on.
/// Tapping one opens the relevant screen, as before.
const NotificationDetails digestDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    reminderChannelId,
    reminderChannelName,
    channelDescription: reminderChannelDescription,
    importance: reminderImportance,
    priority: reminderPriority,
  ),
  iOS: DarwinNotificationDetails(),
);

/// iOS category carrying the same two buttons, registered at initialization.
const String reminderCategoryId = 'cairn_reminder';

final DarwinNotificationCategory reminderDarwinCategory =
    DarwinNotificationCategory(
  reminderCategoryId,
  actions: <DarwinNotificationAction>[
    DarwinNotificationAction.plain(actionMarkDone, 'Mark done'),
    DarwinNotificationAction.plain(actionSnooze, 'Snooze 15 min'),
  ],
);
