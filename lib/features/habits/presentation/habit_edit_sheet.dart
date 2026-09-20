import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_permission_helper.dart';
import '../../../core/recurrence/recurrence.dart';
import '../../../core/time/time_service.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/database_provider.dart';
import '../../../data/providers/habit_providers.dart';
import '../../../data/providers/reminder_config_providers.dart';
import '../../../data/repositories/reminder_config_repository.dart';
import '../../../theme/app_theme.dart';
import '../../reminders/reminder_service.dart';
import '../domain/habit_presentation.dart';

enum _ScheduleKind { everyDay, certainDays, everyFewDays, monthly }

/// Create or edit a habit.
///
/// Saving calls `createHabit` / `updateHabit` and nothing else writes: the
/// repository puts the event and the projection down together (SPEC §0).
/// The only other call is to the reminder service, which reads the saved
/// habit back and schedules — or cancels — its notification.
///
/// The user never sees RRULE syntax. The schedule controls build the rule;
/// [HabitScheduleText] reads it back.
class HabitEditSheet extends ConsumerStatefulWidget {
  const HabitEditSheet({super.key, this.habit});

  /// Null to create.
  final Habit? habit;

  /// Returns the saved habit's id, or null if dismissed.
  static Future<String?> show(BuildContext context, {Habit? habit}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => HabitEditSheet(habit: habit),
    );
  }

  @override
  ConsumerState<HabitEditSheet> createState() => _HabitEditSheetState();
}

class _HabitEditSheetState extends ConsumerState<HabitEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _target;
  late final TextEditingController _unit;

  late String _iconName;
  late int _colorIndex;

  late _ScheduleKind _kind;
  late Set<int> _weekdays;
  late int _everyN;
  late int _monthDay;

  /// A rule the controls cannot express (every other week, 2nd Tuesday) is
  /// kept verbatim until the user touches the schedule. Rewriting it on an
  /// unrelated edit — a new title — would reschedule the habit silently.
  String? _unrepresentableRule;
  bool _scheduleTouched = false;

  late bool _counting;

  /// Configured reminder times, minutes past midnight, ascending. Loaded
  /// asynchronously when editing (`_loadReminderTimes`) since it now lives
  /// in its own table rather than a scalar on the habit row.
  List<int> _reminderTimes = [];
  late int _restDays;

  bool _saving = false;

  bool get _isEdit => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _title = TextEditingController(text: h?.title ?? '');
    _iconName = h?.iconName ?? HabitIcons.fallback;
    if (!HabitIcons.byName.containsKey(_iconName)) _iconName = HabitIcons.fallback;
    _colorIndex = (h?.colorIndex ?? 0) % HabitColors.count;

    final today = ref.read(timeServiceProvider).todayLocalDate();
    _kind = _ScheduleKind.everyDay;
    _weekdays = {DateTime.monday, DateTime.wednesday, DateTime.friday};
    _everyN = 2;
    _monthDay = TimeService.parseLocalDate(today).day;
    _loadRule(h?.scheduleRule);

    final target = h?.targetCount ?? 1;
    _counting = target > 1;
    _target = TextEditingController(text: target > 1 ? '$target' : '');
    _unit = TextEditingController(text: h?.unitLabel ?? '');

    _restDays = (h?.skipAllowancePerMonth ?? 2).clamp(0, 5);
    if (h != null) _loadReminderTimes(h.id);
  }

  Future<void> _loadReminderTimes(String habitId) async {
    final rows =
        await ref.read(reminderConfigRepositoryProvider).habitReminderTimes(habitId);
    if (!mounted) return;
    setState(() {
      _reminderTimes = [for (final r in rows) r.minutesPastMidnight]..sort();
    });
  }

  Future<void> _addReminderTime() async {
    if (_reminderTimes.length >= ReminderConfigRepository.maxRemindersPerItem) {
      return;
    }
    final wasEmpty = _reminderTimes.isEmpty;
    if (wasEmpty) {
      await NotificationPermissionHelper.ensureNotificationPermission(context);
      if (!mounted) return;
    }
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked == null || !mounted) return;
    final minutes = picked.hour * 60 + picked.minute;
    if (_reminderTimes.contains(minutes)) return;
    setState(() {
      _reminderTimes = [..._reminderTimes, minutes]..sort();
    });
  }

  void _removeReminderTime(int minutes) {
    setState(() {
      _reminderTimes = _reminderTimes.where((m) => m != minutes).toList();
    });
  }

  void _loadRule(String? raw) {
    final rule = RecurrenceRule.parse(raw);
    if (rule == null) return;
    switch (rule.freq) {
      case RecurrenceFreq.daily:
        if (rule.interval == 1) {
          _kind = _ScheduleKind.everyDay;
        } else {
          _kind = _ScheduleKind.everyFewDays;
          _everyN = rule.interval;
        }
      case RecurrenceFreq.weekly:
        _kind = _ScheduleKind.certainDays;
        _weekdays = {...rule.byWeekday};
        if (rule.interval != 1) _unrepresentableRule = raw;
      case RecurrenceFreq.monthly:
        _kind = _ScheduleKind.monthly;
        if (rule.byMonthDay != null && rule.interval == 1) {
          _monthDay = rule.byMonthDay!;
        } else {
          _unrepresentableRule = raw;
        }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  String _buildRule() {
    if (!_scheduleTouched && _unrepresentableRule != null) {
      return _unrepresentableRule!;
    }
    return switch (_kind) {
      _ScheduleKind.everyDay =>
        const RecurrenceRule(freq: RecurrenceFreq.daily).serialize(),
      _ScheduleKind.certainDays =>
        RecurrenceRule(freq: RecurrenceFreq.weekly, byWeekday: _weekdays)
            .serialize(),
      _ScheduleKind.everyFewDays =>
        RecurrenceRule(freq: RecurrenceFreq.daily, interval: _everyN)
            .serialize(),
      _ScheduleKind.monthly =>
        RecurrenceRule(freq: RecurrenceFreq.monthly, byMonthDay: _monthDay)
            .serialize(),
    };
  }

  int get _targetValue {
    if (!_counting) return 1;
    final n = int.tryParse(_target.text.trim());
    return (n == null || n < 1) ? 1 : n;
  }

  String? get _unitValue {
    if (!_counting) return null;
    final u = _unit.text.trim();
    return u.isEmpty ? null : u;
  }

  bool get _canSave =>
      !_saving &&
      _title.text.trim().isNotEmpty &&
      !(_kind == _ScheduleKind.certainDays && _weekdays.isEmpty) &&
      !(_counting && (int.tryParse(_target.text.trim()) ?? 0) < 1);

  void _touchSchedule(VoidCallback change) {
    setState(() {
      _scheduleTouched = true;
      change();
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final repo = ref.read(habitsRepositoryProvider);
    final title = _title.text.trim();
    final rule = _buildRule();

    try {
      String id;
      final h = widget.habit;
      if (h == null) {
        id = await repo.createHabit(
          title: title,
          scheduleRule: rule,
          colorIndex: _colorIndex,
          iconName: _iconName,
          targetCount: _targetValue,
          unitLabel: _unitValue,
          skipAllowancePerMonth: _restDays,
        );
      } else {
        id = h.id;
        final unit = _unitValue;
        await repo.updateHabit(
          id,
          title: title == h.title ? null : title,
          colorIndex: _colorIndex == h.colorIndex ? null : _colorIndex,
          iconName: _iconName == h.iconName ? null : _iconName,
          scheduleRule: rule == h.scheduleRule ? null : rule,
          targetCount: _targetValue == h.targetCount ? null : _targetValue,
          unitLabel: unit != null && unit != h.unitLabel ? unit : null,
          clearUnitLabel: unit == null && h.unitLabel != null,
          skipAllowancePerMonth:
              _restDays == h.skipAllowancePerMonth ? null : _restDays,
        );
      }

      await ref
          .read(reminderConfigRepositoryProvider)
          .setHabitReminderTimes(id, _reminderTimes);

      // Schedule from what was saved, not from the form: the saved row is
      // what the reminder has to agree with.
      try {
        final saved = await repo.habitById(id);
        final reminders = ref.read(reminderServiceProvider);
        if (saved != null) await reminders.scheduleForHabit(saved);
      } catch (_) {
        // No notification plugin (desktop, tests). The habit is saved.
      }

      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Could not save the habit: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final colors = context.colors;
    final accent = HabitColors.of(context, _colorIndex);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit ? 'Edit habit' : 'New habit',
                    style: textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                // ── Title ─────────────────────────────────────────────────
                TextField(
                  controller: _title,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'What do you want to do?',
                    hintText: 'Read 20 pages',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),

                // ── Icon and colour ───────────────────────────────────────
                _SectionLabel('Icon and colour'),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final entry in HabitIcons.byName.entries)
                        _ChoiceCircle(
                          selected: entry.key == _iconName,
                          color: accent,
                          semanticLabel: 'Icon ${HabitIcons.label(entry.key)}',
                          onTap: () => setState(() => _iconName = entry.key),
                          child: Icon(
                            entry.value,
                            size: 22,
                            color: entry.key == _iconName
                                ? accent
                                : tokens.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  children: [
                    for (var i = 0; i < HabitColors.count; i++)
                      _ChoiceCircle(
                        selected: i == _colorIndex,
                        color: HabitColors.of(context, i),
                        semanticLabel: 'Colour ${HabitColors.label(i)}',
                        onTap: () => setState(() => _colorIndex = i),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: HabitColors.of(context, i),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Schedule ──────────────────────────────────────────────
                _SectionLabel('Schedule'),
                // Chips rather than a SegmentedButton: four segments with
                // labels this long do not fit a 360dp phone at 100% text, and
                // at 200% a segmented button clips. Chips wrap.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final (kind, label) in const [
                      (_ScheduleKind.everyDay, 'Every day'),
                      (_ScheduleKind.certainDays, 'Certain days'),
                      (_ScheduleKind.everyFewDays, 'Every few days'),
                      (_ScheduleKind.monthly, 'Monthly'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _kind == kind,
                        onSelected: (_) => _touchSchedule(() => _kind = kind),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_kind == _ScheduleKind.certainDays)
                  Wrap(
                    children: [
                      for (var d = 1; d <= 7; d++)
                        _ChoiceCircle(
                          selected: _weekdays.contains(d),
                          color: accent,
                          filled: true,
                          semanticLabel: HabitDates.weekdayNames[d - 1],
                          onTap: () => _touchSchedule(() {
                            _weekdays.contains(d)
                                ? _weekdays.remove(d)
                                : _weekdays.add(d);
                          }),
                          child: Text(
                            HabitDates.weekdayShort[d - 1].substring(0, 2),
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _weekdays.contains(d)
                                  ? (ThemeData.estimateBrightnessForColor(
                                              accent) ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black)
                                  : tokens.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                if (_kind == _ScheduleKind.everyFewDays)
                  _Stepper(
                    label: 'Every $_everyN days',
                    value: _everyN,
                    min: 2,
                    max: 30,
                    onChanged: (v) => _touchSchedule(() => _everyN = v),
                  ),
                if (_kind == _ScheduleKind.monthly)
                  _Stepper(
                    label: 'On the ${HabitDates.ordinal(_monthDay)}',
                    value: _monthDay,
                    min: 1,
                    max: 31,
                    onChanged: (v) => _touchSchedule(() => _monthDay = v),
                  ),
                if (_kind == _ScheduleKind.certainDays && _weekdays.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Pick at least one day.',
                      style: textTheme.bodySmall?.copyWith(color: tokens.danger),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    HabitScheduleText.describe(_buildRule()),
                    style: textTheme.bodySmall
                        ?.copyWith(color: tokens.textSecondary),
                  ),
                ),
                if (_isEdit && _scheduleTouched)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Past days keep the schedule they had. Your streak is '
                      'not recounted.',
                      style:
                          textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                    ),
                  ),
                const SizedBox(height: 20),

                // ── Goal ──────────────────────────────────────────────────
                _SectionLabel('Goal'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Count something'),
                  subtitle: Text(_counting
                      ? 'Done when you reach the number'
                      : 'Just tick it off'),
                  value: _counting,
                  onChanged: (v) => setState(() {
                    _counting = v;
                    if (v && _target.text.trim().isEmpty) _target.text = '8';
                  }),
                ),
                if (_counting)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 170,
                        child: TextField(
                          controller: _target,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'How many per day?',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: 170,
                        child: TextField(
                          controller: _unit,
                          textCapitalization: TextCapitalization.none,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            hintText: 'glasses, pages',
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                // ── Reminder ──────────────────────────────────────────────
                _SectionLabel('Reminder'),
                Text(
                  _reminderTimes.isEmpty
                      ? 'No reminders — only on days this habit is due'
                      : 'On days this habit is due, at:',
                  style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final minutes in _reminderTimes)
                      InputChip(
                        avatar: const Icon(Icons.schedule_rounded, size: 18),
                        label: Text(HabitDates.timeOfDay(minutes)),
                        onDeleted: () => _removeReminderTime(minutes),
                      ),
                    if (_reminderTimes.length <
                        ReminderConfigRepository.maxRemindersPerItem)
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add reminder'),
                        onPressed: _addReminderTime,
                      ),
                  ],
                ),
                if (_reminderTimes.length >=
                    ReminderConfigRepository.maxRemindersPerItem)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Up to ${ReminderConfigRepository.maxRemindersPerItem} '
                      'reminders per habit.',
                      style:
                          textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                    ),
                  ),
                const SizedBox(height: 20),

                // ── Rest days ─────────────────────────────────────────────
                _SectionLabel('Rest days'),
                _Stepper(
                  label: 'Allow $_restDays rest '
                      '${_restDays == 1 ? 'day' : 'days'} a month without '
                      'breaking your streak',
                  value: _restDays,
                  min: 0,
                  max: 5,
                  onChanged: (v) => setState(() => _restDays = v),
                ),
                Text(
                  'A rest day you mark yourself keeps your streak. Past this '
                  'many in a month, it resets.',
                  style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                ),
                if (_saving)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(color: colors.primary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.tokens.textMuted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

/// A 48×48dp selectable circle, used for icons, colours and weekdays.
class _ChoiceCircle extends StatelessWidget {
  const _ChoiceCircle({
    required this.selected,
    required this.color,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
    this.filled = false,
  });

  final bool selected;
  final bool filled;
  final Color color;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 48,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected && filled ? color : null,
                border: Border.all(
                  color: selected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// − value + with 48dp buttons. The label wraps rather than clipping at 200%.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        IconButton(
          tooltip: 'Fewer',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        Semantics(
          liveRegion: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        IconButton(
          tooltip: 'More',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}
