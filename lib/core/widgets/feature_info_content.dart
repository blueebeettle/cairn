import 'feature_info.dart';

/// The help text for each screen, kept in one place so the wording stays
/// consistent and the numbers stay honest.
///
/// These describe what the app actually does, not what it ideally would.
/// If a rule changes — what counts as a finished session, when a day rolls
/// over, how a streak survives — change it here in the same edit.
abstract final class FeatureInfoContent {
  static const today = FeatureInfo(
    id: 'today',
    title: 'Today',
    summary:
        'Everything due today in one place: your focus total, the tasks you '
        'planned, and the habits you meant to keep.',
    sections: [
      FeatureInfoSection(
        heading: 'What you are looking at',
        body:
            'The ring shows how much focused time you have logged today '
            'against your daily goal. Under it sit today\'s tasks and habits, '
            'so the whole day is one screen rather than three.',
      ),
      FeatureInfoSection(
        heading: 'Getting things done',
        body:
            'Tap a task to open it, or its circle to tick it off. Same for '
            'habits. Use the arrows beside the date to look back at an '
            'earlier day — past days are read-only history, not a to-do list.',
      ),
      FeatureInfoSection(
        heading: 'When the day rolls over',
        body:
            'A day runs 4am to 4am, not midnight to midnight. Work you finish '
            'at 1am still counts for the day you started, so a late night does '
            'not quietly split itself across two days.',
      ),
    ],
  );

  static const tasks = FeatureInfo(
    id: 'tasks',
    title: 'Tasks',
    summary:
        'Everything you have to do, grouped by when it matters: Today, '
        'Upcoming, and an Inbox for anything undated.',
    sections: [
      FeatureInfoSection(
        heading: 'Capturing quickly',
        body:
            'Tap + to jot a task down in one line. You can type the details '
            'inline — a date like "tomorrow", !p1 to !p4 for priority with 1 '
            'the highest, a #tag, or ~2p to estimate how many focus sessions '
            'it will take — and they are picked out for you. Long-press + '
            'when you want the full form instead.',
      ),
      FeatureInfoSection(
        heading: 'Priority and order',
        body:
            'Priority runs 1 to 4, where 1 is highest. Today\'s list sorts by '
            'priority first, so the thing that matters most is always at the '
            'top without you reordering anything.',
      ),
      FeatureInfoSection(
        heading: 'Reminders',
        body:
            'A task with a specific due time can remind you beforehand — the '
            'default is 10 minutes, and you can add your own offsets in the '
            'task. All-day tasks have no time to count down to, so they get '
            'no countdown reminder.',
      ),
      FeatureInfoSection(
        heading: 'Archive and delete',
        body:
            'Archiving keeps a task and its history but takes it out of your '
            'lists. Deleting removes it for good, and if it has completion '
            'history the app tells you before it goes.',
      ),
    ],
  );

  static const habits = FeatureInfo(
    id: 'habits',
    title: 'Habits',
    summary:
        'Things you want to keep doing. Cairn tracks the streak so you can '
        'see the chain rather than just today.',
    sections: [
      FeatureInfoSection(
        heading: 'Scheduling',
        body:
            'A habit can be every day or only certain days. It is only ever '
            'counted, or shown as missed, on the days you actually scheduled '
            'it — a Monday/Wednesday habit is not a failure on Sunday.',
      ),
      FeatureInfoSection(
        heading: 'Counts and units',
        body:
            'A habit can be a simple tick, or a target with a unit — eight '
            'glasses, thirty pages. It counts as done for the day once you '
            'reach the target.',
      ),
      FeatureInfoSection(
        heading: 'Rest days',
        body:
            'You can allow yourself a number of skips each month. A skipped '
            'day is a deliberate rest, not a miss, so it does not break your '
            'streak.',
      ),
      FeatureInfoSection(
        heading: 'Reminders',
        body:
            'Add one or more times of day and Cairn will remind you, but only '
            'on days the habit is actually scheduled, and only if it is not '
            'already done.',
      ),
    ],
  );

  static const timer = FeatureInfo(
    id: 'timer',
    title: 'Focus Timer',
    summary:
        'A countdown for focused work. Pomodoro for a fixed length, '
        'Open-ended when you do not want a finish line.',
    sections: [
      FeatureInfoSection(
        heading: 'Pomodoro vs Open-ended',
        body:
            'Pomodoro counts down from a length you choose and then offers a '
            'break. Open-ended just counts up until you stop it. Pick 15, 25, '
            '45 or 60 minutes, or tap Custom for any length from 5 minutes to '
            '3 hours.',
      ),
      FeatureInfoSection(
        heading: 'Finishing vs stopping',
        body:
            'This is the one that catches people out. Only sessions you let '
            'finish count towards your totals and streak. If you stop early '
            'the time is not added — the session is recorded as abandoned and '
            'contributes zero minutes.',
      ),
      FeatureInfoSection(
        heading: 'It keeps running',
        body:
            'The timer survives leaving the app, and even the app being '
            'closed. The notification shows the remaining time and its Pause, '
            'Resume and Skip buttons work from the notification itself. You '
            'can also drive it from the home-screen widget.',
      ),
      FeatureInfoSection(
        heading: 'Interruptions',
        body:
            'While a session runs you can tap to log an interruption — your '
            'own thought, or someone else. They do not stop the session; they '
            'just show you later where the focus actually went.',
      ),
    ],
  );

  /// The Stats explainer, in plain language.
  ///
  /// Deliberately explicit about the rules that make a number look "wrong":
  /// stopped sessions counting as zero, the 4am day boundary, and today never
  /// breaking a streak.
  static const stats = FeatureInfo(
    id: 'stats',
    title: 'How these numbers work',
    summary:
        'Everything here is counted from sessions you finished and days you '
        'actually did the thing. Here is exactly how.',
    sections: [
      FeatureInfoSection(
        heading: 'Focused time',
        body:
            'This is the total length of focus sessions you let finish. '
            'Sessions you stopped early count as zero minutes — not a partial '
            'amount. So if you stop a 25 minute session at 24 minutes, it '
            'adds nothing. That is why your focused time can be lower than '
            'the time you feel you spent.',
      ),
      FeatureInfoSection(
        heading: 'Finished percentage',
        body:
            'Out of every session you started, the share you let run to the '
            'end. Starting a lot of sessions and stopping them pulls this '
            'down, which is the point — it shows how often focus actually '
            'held.',
      ),
      FeatureInfoSection(
        heading: 'What counts as a day',
        body:
            'A day runs from 4am to 4am. Work you finish at 1am counts for '
            'the day before, not the new one. Every number on this screen '
            'uses that same boundary, so late nights stay in one piece.',
      ),
      FeatureInfoSection(
        heading: 'Your focus streak',
        body:
            'The number of days in a row you hit your daily focus goal. '
            'Today is never counted against you: if you have not hit the goal '
            'yet today, the streak is measured up to yesterday. It only '
            'breaks once a day has fully passed without the goal being met.',
      ),
      FeatureInfoSection(
        heading: 'Habit streaks',
        body:
            'Counted only on days the habit was scheduled. Days it was not '
            'scheduled are skipped over rather than breaking the chain, and a '
            'rest day you allowed yourself does not break it either.',
      ),
      FeatureInfoSection(
        heading: 'Why some panels say "provisional"',
        body:
            'A few views need a bit of history before they mean anything. The '
            'activity scale settles once you have 14 days with some activity, '
            'and "when you focus best" needs 10 finished sessions. Until '
            'then they are shown, but they are still finding their feet.',
      ),
      FeatureInfoSection(
        heading: 'Zero is a real number',
        body:
            'A day with no focused work shows 0 minutes and a 0-day streak, '
            'rather than a dash. It is a true answer, and hiding it would '
            'only make a quiet week look like missing data.',
      ),
    ],
  );
}
