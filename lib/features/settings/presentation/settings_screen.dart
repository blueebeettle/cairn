import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/widgets/cairn_card.dart';
import '../../../data/providers/database_provider.dart';
import '../../../theme/app_theme.dart';
import '../../backup/presentation/backup_restore_screen.dart';
import '../../reminders/reminder_service.dart';
import '../../tasks/presentation/archived_tasks_screen.dart';

/// The Settings screen per POLISH §4 and §2.
///
/// Organized in 7 grouped sections:
/// 1. Focus (Daily goal, Session length, Break length, Long break, Sessions before long break, explanations)
/// 2. Reminders (Task reminders, Daily digest, Habit check-in)
/// 3. Day & week (Day start offset + explanation, Week start)
/// 4. Appearance (System / Light / Dark theme)
/// 5. Notifications (Permission status & system settings link)
/// 6. Data (Backup, Sync & Accounts, Archived tasks)
/// 7. About (Version, from beetlebyte, Open-source licenses)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  PackageInfo? _packageInfo;
  bool _notificationGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPackageInfo();
    _checkNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationPermission();
    }
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _packageInfo = info);
      }
    } catch (_) {}
  }

  Future<void> _checkNotificationPermission() async {
    if (kIsWeb || (!kIsWeb && defaultTargetPlatform != TargetPlatform.android)) {
      if (mounted) setState(() => _notificationGranted = true);
      return;
    }

    try {
      final status = await FlutterForegroundTask.checkNotificationPermission();
      if (mounted) {
        setState(() => _notificationGranted = status == NotificationPermission.granted);
      }
    } catch (_) {
      if (mounted) setState(() => _notificationGranted = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final dailyGoalMinutes = ref.watch(dailyGoalMinutesProvider);
    final sessionLengthS = ref.watch(sessionLengthSecondsProvider);
    final breakLengthS = ref.watch(breakLengthSecondsProvider);
    final longBreakLengthS = ref.watch(longBreakLengthSecondsProvider);
    final sessionsBeforeLongBreak = ref.watch(sessionsBeforeLongBreakProvider);
    final dayStartOffset = ref.watch(dayStartOffsetProvider);
    final weekStart = ref.watch(weekStartProvider);
    final themeMode = ref.watch(themeModeProvider);
    final remindersEnabled = ref.watch(remindersEnabledProvider);
    final defaultOffsets = ref.watch(defaultTaskReminderOffsetsMinProvider);
    final digestEnabled = ref.watch(digestEnabledProvider);
    final digestTimes = ref.watch(digestTimesMinProvider);
    final habitDigestEnabled = ref.watch(habitDigestEnabledProvider);
    final habitDigestTime = ref.watch(habitDigestTimeMinProvider);

    final dayStartTimeStr = _formatOffsetTime(context, dayStartOffset);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // ── 1. Focus ─────────────────────────────────────────────────────
            _buildSectionHeader(context, 'Focus'),
            CairnCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: const Text('Daily goal'),
                      subtitle: Text('$dailyGoalMinutes min'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showSliderDialog(
                        context: context,
                        title: 'Daily goal',
                        currentValue: dailyGoalMinutes.toDouble(),
                        min: 5,
                        max: 480,
                        step: 5,
                        unit: 'min',
                        onChanged: (val) {
                          ref.read(dailyGoalMinutesProvider.notifier).setGoal(val.round());
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Session length'),
                      subtitle: Text('${sessionLengthS ~/ 60} min'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showSliderDialog(
                        context: context,
                        title: 'Session length',
                        currentValue: (sessionLengthS ~/ 60).toDouble(),
                        min: 5,
                        max: 120,
                        step: 5,
                        unit: 'min',
                        onChanged: (val) {
                          ref.read(sessionLengthSecondsProvider.notifier).setDuration(val.round() * 60);
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Break length'),
                      subtitle: Text('${breakLengthS ~/ 60} min'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showSliderDialog(
                        context: context,
                        title: 'Break length',
                        currentValue: (breakLengthS ~/ 60).toDouble(),
                        min: 1,
                        max: 30,
                        step: 1,
                        unit: 'min',
                        onChanged: (val) {
                          ref.read(breakLengthSecondsProvider.notifier).setDuration(val.round() * 60);
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Long break length'),
                      subtitle: Text('${longBreakLengthS ~/ 60} min'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showSliderDialog(
                        context: context,
                        title: 'Long break length',
                        currentValue: (longBreakLengthS ~/ 60).toDouble(),
                        min: 1,
                        max: 60,
                        step: 1,
                        unit: 'min',
                        onChanged: (val) {
                          ref.read(longBreakLengthSecondsProvider.notifier).setDuration(val.round() * 60);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sessions before a long break',
                            style: textTheme.bodyLarge?.copyWith(color: colors.onSurface),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 2, label: Text('2')),
                                ButtonSegment(value: 3, label: Text('3')),
                                ButtonSegment(value: 4, label: Text('4')),
                                ButtonSegment(value: 5, label: Text('5')),
                              ],
                              selected: {
                                [2, 3, 4, 5].contains(sessionsBeforeLongBreak)
                                    ? sessionsBeforeLongBreak
                                    : 4
                              },
                              showSelectedIcon: false,
                              onSelectionChanged: (selected) {
                                ref.read(sessionsBeforeLongBreakProvider.notifier).setCount(selected.first);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildExplanation(
                      context,
                      "Stopped sessions don't count toward your totals. If you stop at 24 minutes, that time isn't added. Only sessions you finish are counted.",
                    ),
                    const SizedBox(height: 12),
                    _buildExplanation(
                      context,
                      "Today can't break your streak. Your streak only looks at days that are already over, so it won't reset just because you haven't started yet today.",
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── 2. Reminders ─────────────────────────────────────────────────
            _buildSectionHeader(context, 'Reminders'),
            CairnCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text('Reminders'),
                      subtitle: const Text('Notify you before tasks are due'),
                      value: remindersEnabled,
                      onChanged: (val) {
                        ref.read(remindersEnabledProvider.notifier).setEnabled(val);
                        ref.read(reminderServiceProvider).reconcileAll();
                      },
                    ),
                    if (remindersEnabled) const ExactAlarmTile(),
                    if (remindersEnabled) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Default reminders for new tasks',
                              style: textTheme.bodyLarge?.copyWith(color: colors.onSurface),
                            ),
                            Text(
                              'How many, and how long before a timed task is due. '
                              'Each task can change its own.',
                              style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final minutes in defaultOffsets)
                                  InputChip(
                                    label: Text(_formatOffsetLabel(minutes)),
                                    onDeleted: defaultOffsets.length <= 1
                                        ? null
                                        : () {
                                            ref
                                                .read(defaultTaskReminderOffsetsMinProvider
                                                    .notifier)
                                                .setOffsets([
                                              for (final m in defaultOffsets)
                                                if (m != minutes) m
                                            ]);
                                            ref.read(reminderServiceProvider).reconcileAll();
                                          },
                                  ),
                                if (defaultOffsets.length <
                                    DefaultTaskReminderOffsetsMinNotifier.maxOffsets)
                                  ActionChip(
                                    avatar: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('Add'),
                                    onPressed: () async {
                                      final selected = await _pickOffsetMinutes(context);
                                      if (selected == null) return;
                                      ref
                                          .read(defaultTaskReminderOffsetsMinProvider
                                              .notifier)
                                          .setOffsets([...defaultOffsets, selected]);
                                      ref.read(reminderServiceProvider).reconcileAll();
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Daily digest'),
                        subtitle: const Text(
                          "What's due today and overdue, for all-day tasks with no "
                          'specific time',
                        ),
                        value: digestEnabled,
                        onChanged: (val) {
                          ref.read(digestEnabledProvider.notifier).setEnabled(val);
                          ref.read(reminderServiceProvider).reconcileAll();
                        },
                      ),
                      if (digestEnabled)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final minutes in digestTimes)
                                InputChip(
                                  avatar: const Icon(Icons.schedule_rounded, size: 18),
                                  label: Text(_formatOffsetTime(context, minutes)),
                                  onDeleted: digestTimes.length <= 1
                                      ? null
                                      : () {
                                          ref.read(digestTimesMinProvider.notifier).setTimes([
                                            for (final m in digestTimes)
                                              if (m != minutes) m
                                          ]);
                                          ref.read(reminderServiceProvider).reconcileAll();
                                        },
                                ),
                              if (digestTimes.length < DigestTimesMinNotifier.maxTimes)
                                ActionChip(
                                  avatar: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Add time'),
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (picked == null) return;
                                    final minutes = picked.hour * 60 + picked.minute;
                                    if (digestTimes.contains(minutes)) return;
                                    ref
                                        .read(digestTimesMinProvider.notifier)
                                        .setTimes([...digestTimes, minutes]);
                                    ref.read(reminderServiceProvider).reconcileAll();
                                  },
                                ),
                            ],
                          ),
                        ),
                      SwitchListTile(
                        title: const Text('Habit check-in'),
                        subtitle: const Text(
                          'One nudge a day about your habits — your streak, a new '
                          'week, or a rest day that saved it',
                        ),
                        value: habitDigestEnabled,
                        onChanged: (val) {
                          ref.read(habitDigestEnabledProvider.notifier).setEnabled(val);
                          ref.read(reminderServiceProvider).reconcileAll();
                        },
                      ),
                      if (habitDigestEnabled)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: InputChip(
                              avatar: const Icon(Icons.schedule_rounded, size: 18),
                              label: Text(_formatOffsetTime(context, habitDigestTime)),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: habitDigestTime ~/ 60,
                                    minute: habitDigestTime % 60,
                                  ),
                                );
                                if (picked == null) return;
                                ref
                                    .read(habitDigestTimeMinProvider.notifier)
                                    .setTime(picked.hour * 60 + picked.minute);
                                ref.read(reminderServiceProvider).reconcileAll();
                              },
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            // ── 3. Day & Week ────────────────────────────────────────────────
            _buildSectionHeader(context, 'Day & week'),
            CairnCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: const Text('Day starts at'),
                      subtitle: Text(dayStartTimeStr),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final currentHour = dayStartOffset ~/ 60;
                        final currentMinute = dayStartOffset % 60;
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
                        );
                        if (picked != null) {
                          final newOffset = picked.hour * 60 + picked.minute;
                          ref.read(dayStartOffsetProvider.notifier).setOffset(newOffset);
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildExplanation(
                      context,
                      'Your day starts at $dayStartTimeStr, not midnight. A session you finish at 1am counts toward the previous day, so a late night doesn\'t split your work across two days or break a streak. Changing this affects new sessions only — your history stays as it was recorded.',
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Week starts on',
                            style: textTheme.bodyLarge?.copyWith(color: colors.onSurface),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(
                                  value: DateTime.monday,
                                  label: Text('Mon'),
                                ),
                                ButtonSegment(
                                  value: DateTime.sunday,
                                  label: Text('Sun'),
                                ),
                                ButtonSegment(
                                  value: DateTime.saturday,
                                  label: Text('Sat'),
                                ),
                              ],
                              selected: {
                                [DateTime.monday, DateTime.sunday, DateTime.saturday].contains(weekStart)
                                    ? weekStart
                                    : DateTime.monday
                              },
                              showSelectedIcon: false,
                              onSelectionChanged: (selected) {
                                ref.read(weekStartProvider.notifier).setWeekStart(selected.first);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── 4. Appearance ────────────────────────────────────────────────
            _buildSectionHeader(context, 'Appearance'),
            CairnCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme',
                        style: textTheme.bodyLarge?.copyWith(color: colors.onSurface),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('System'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {themeMode},
                          showSelectedIcon: false,
                          onSelectionChanged: (selected) {
                            ref.read(themeModeProvider.notifier).setThemeMode(selected.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 5. Notifications ─────────────────────────────────────────────
            _buildSectionHeader(context, 'Notifications'),
            CairnCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  title: const Text('Notifications'),
                  subtitle: Text(
                    _notificationGranted
                        ? 'On'
                        : 'Timer notifications are off. Without them you won\'t be told when a session ends while the app is closed.',
                    style: textTheme.bodySmall?.copyWith(
                      color: _notificationGranted ? tokens.textSecondary : tokens.warning,
                    ),
                  ),
                  trailing: _notificationGranted
                      ? const Icon(Icons.check_circle_outline_rounded, color: Colors.green)
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _notificationGranted
                      ? null
                      : () async {
                          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
                            await FlutterForegroundTask.requestNotificationPermission();
                            await _checkNotificationPermission();
                          }
                        },
                ),
              ),
            ),

            // ── 6. Data ──────────────────────────────────────────────────────
            _buildSectionHeader(context, 'Data'),
            CairnCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.shield_outlined),
                      title: const Text('Backup, Sync & Accounts'),
                      subtitle: const Text('Local encrypted vault, CSV export & Cloud account'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BackupRestoreScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.archive_outlined),
                      title: const Text('Archived tasks'),
                      subtitle: const Text('View and manage archived tasks'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ArchivedTasksScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── 7. About ─────────────────────────────────────────────────────
            _buildSectionHeader(context, 'About'),
            CairnCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Version'),
                      subtitle: Text(
                        _packageInfo != null
                            ? '${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                            : '1.0.0 (1)',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'from beetlebyte',
                          style: textTheme.bodyMedium?.copyWith(
                            color: tokens.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text('Open-source licences'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        showLicensePage(
                          context: context,
                          applicationName: 'Cairn',
                          applicationVersion: _packageInfo != null
                              ? '${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                              : '1.0.0 (1)',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
      child: CardChrome.sectionLabel(context, title),
    );
  }

  Widget _buildExplanation(BuildContext context, String text) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: textTheme.bodySmall?.copyWith(
          color: tokens.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }

  static String _formatOffsetTime(BuildContext context, int offsetMinutes) {
    final hour = offsetMinutes ~/ 60;
    final minute = offsetMinutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return minute == 0 ? '$displayHour:00 $period' : '$displayHour:$displayMinute $period';
  }

  /// "At time", "5m", "1h" — a countdown offset, not a clock time.
  static String _formatOffsetLabel(int minutes) {
    if (minutes == 0) return 'At time';
    if (minutes % (24 * 60) == 0) {
      final days = minutes ~/ (24 * 60);
      return days == 1 ? '1 day before' : '$days days before';
    }
    if (minutes % 60 == 0) return '${minutes ~/ 60}h before';
    return '${minutes}m before';
  }

  /// A short menu of common countdown offsets, for "add a default reminder".
  Future<int?> _pickOffsetMinutes(BuildContext context) {
    const choices = [0, 5, 10, 15, 30, 60, 120, 1440];
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Remind before due'),
        children: [
          for (final minutes in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(minutes),
              child: Text(_formatOffsetLabel(minutes)),
            ),
        ],
      ),
    );
  }

  void _showSliderDialog({
    required BuildContext context,
    required String title,
    required double currentValue,
    required double min,
    required double max,
    required double step,
    required String unit,
    required void Function(double) onChanged,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        var tempValue = currentValue;
        final divisions = ((max - min) / step).round();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${tempValue.round()} $unit',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: tempValue.clamp(min, max),
                      min: min,
                      max: max,
                      divisions: divisions,
                      label: '${tempValue.round()} $unit',
                      onChanged: (newVal) {
                        final rounded = (newVal / step).round() * step;
                        setDialogState(() => tempValue = rounded.clamp(min, max));
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    onChanged(tempValue);
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Prompts for the exact-alarm permission when Android is withholding it.
///
/// Android 13+ starts `SCHEDULE_EXACT_ALARM` denied, and without it the OS is
/// free to batch reminders under Doze — which is exactly the "arrives late"
/// complaint. [ReminderService] still schedules inexact in that state, so this
/// tile is an upgrade path rather than a gate, and it only appears when the
/// permission is actually missing.
///
/// Surfaced here rather than requested silently at startup because granting it
/// sends the user out to a system settings page; an unexplained jump there is
/// worse than a late reminder.
class ExactAlarmTile extends ConsumerStatefulWidget {
  const ExactAlarmTile({super.key});

  @override
  ConsumerState<ExactAlarmTile> createState() => _ExactAlarmTileState();
}

class _ExactAlarmTileState extends ConsumerState<ExactAlarmTile> {
  bool _allowed = true;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final allowed =
        await ref.read(reminderServiceProvider).refreshExactAlarmCapability();
    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only Android has this permission; everywhere else the capability check
    // returns the optimistic default and this renders nothing.
    if (!_checked || _allowed || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.schedule_outlined, color: colors.error),
      title: const Text('Allow exact reminder times'),
      subtitle: const Text(
        'Android is batching reminders, so they can arrive late. '
        'Allow exact alarms to have them fire on time.',
      ),
      isThreeLine: true,
      trailing: FilledButton(
        onPressed: () async {
          final granted = await ref
              .read(reminderServiceProvider)
              .requestExactAlarmPermission();
          if (!mounted) return;
          setState(() => _allowed = granted);
        },
        child: const Text('Allow'),
      ),
    );
  }
}
