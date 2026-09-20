import 'package:flutter/material.dart';

import '../../../../core/recurrence/recurrence.dart';
import '../../../../theme/app_theme.dart';

/// Recurrence configuration dialog/sheet per SPEC.md §2.6 and §4.
///
/// Features plain-language mode selection:
/// - "Repeats on schedule" vs "Repeats after I finish it"
/// - One-line clear example under each
/// - Frequency options: Daily, Weekly on specific weekdays, Monthly
class RecurrencePickerSheet extends StatefulWidget {
  const RecurrencePickerSheet({
    super.key,
    this.initialRule,
    this.initialMode,
  });

  final String? initialRule;
  final String? initialMode;

  static Future<({String? rule, String? mode})?> show(
    BuildContext context, {
    String? currentRule,
    String? currentMode,
  }) {
    return showModalBottomSheet<({String? rule, String? mode})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RecurrencePickerSheet(
        initialRule: currentRule,
        initialMode: currentMode,
      ),
    );
  }

  @override
  State<RecurrencePickerSheet> createState() => _RecurrencePickerSheetState();
}

class _RecurrencePickerSheetState extends State<RecurrencePickerSheet> {
  late bool _enabled;
  late RecurrenceFreq _freq;
  late int _interval;
  late Set<int> _byWeekday;
  late int _byMonthDay;
  late RecurrenceMode _mode;

  @override
  void initState() {
    super.initState();
    final parsed = RecurrenceRule.parse(widget.initialRule);
    _enabled = parsed != null;
    _freq = parsed?.freq ?? RecurrenceFreq.daily;
    _interval = parsed?.interval ?? 1;
    _byWeekday = Set.from(parsed?.byWeekday ?? {DateTime.monday, DateTime.wednesday, DateTime.friday});
    _byMonthDay = parsed?.byMonthDay ?? 1;
    _mode = widget.initialMode == 'after_completion'
        ? RecurrenceMode.afterCompletion
        : RecurrenceMode.onSchedule;
  }

  RecurrenceRule _buildRule() {
    switch (_freq) {
      case RecurrenceFreq.daily:
        return RecurrenceRule(freq: RecurrenceFreq.daily, interval: _interval);
      case RecurrenceFreq.weekly:
        return RecurrenceRule(
          freq: RecurrenceFreq.weekly,
          interval: _interval,
          byWeekday: _byWeekday.isEmpty ? {DateTime.monday} : _byWeekday,
        );
      case RecurrenceFreq.monthly:
        return RecurrenceRule(
          freq: RecurrenceFreq.monthly,
          interval: _interval,
          byMonthDay: _byMonthDay,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Repeating Task',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: (val) {
                    setState(() {
                      _enabled = val;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!_enabled)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'This task does not repeat.',
                  style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              // ── 1. Recurrence Frequency ─────────────────────────────────────
              Text(
                'FREQUENCY',
                style: textTheme.labelSmall?.copyWith(
                  color: tokens.textMuted,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<RecurrenceFreq>(
                segments: const [
                  ButtonSegment(value: RecurrenceFreq.daily, label: Text('Daily')),
                  ButtonSegment(value: RecurrenceFreq.weekly, label: Text('Weekly')),
                  ButtonSegment(value: RecurrenceFreq.monthly, label: Text('Monthly')),
                ],
                selected: {_freq},
                onSelectionChanged: (set) {
                  setState(() {
                    _freq = set.first;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Frequency specific controls
              if (_freq == RecurrenceFreq.daily) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Repeat every', style: textTheme.bodyMedium),
                    DropdownButton<int>(
                      value: _interval,
                      underline: const SizedBox.shrink(),
                      items: [1, 2, 3, 5, 7, 14, 30]
                          .map((n) => DropdownMenuItem(
                                value: n,
                                child: Text('$n ${n == 1 ? 'day' : 'days'}'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _interval = val);
                      },
                    ),
                  ],
                ),
              ] else if (_freq == RecurrenceFreq.weekly) ...[
                Text('On days of the week', style: textTheme.bodyMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    _weekdayChip(DateTime.monday, 'Mon'),
                    _weekdayChip(DateTime.tuesday, 'Tue'),
                    _weekdayChip(DateTime.wednesday, 'Wed'),
                    _weekdayChip(DateTime.thursday, 'Thu'),
                    _weekdayChip(DateTime.friday, 'Fri'),
                    _weekdayChip(DateTime.saturday, 'Sat'),
                    _weekdayChip(DateTime.sunday, 'Sun'),
                  ],
                ),
              ] else if (_freq == RecurrenceFreq.monthly) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Day of month', style: textTheme.bodyMedium),
                    DropdownButton<int>(
                      value: _byMonthDay,
                      underline: const SizedBox.shrink(),
                      items: List.generate(31, (i) => i + 1)
                          .map((n) => DropdownMenuItem(
                                value: n,
                                child: Text('Day $n'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _byMonthDay = val);
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // ── 2. Mode Selection (Plain Words per §4) ──────────────────────
              Text(
                'RECURRENCE MODE',
                style: textTheme.labelSmall?.copyWith(
                  color: tokens.textMuted,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              RadioGroup<RecurrenceMode>(
                groupValue: _mode,
                onChanged: (val) {
                  if (val != null) setState(() => _mode = val);
                },
                child: Column(
                  children: [
                    RadioListTile<RecurrenceMode>(
                      value: RecurrenceMode.onSchedule,
                      contentPadding: EdgeInsets.zero,
                      title: Text(_getOnScheduleLabel()),
                      subtitle: Text(
                        'Next due date stays on schedule, even if you finish late.',
                        style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                      ),
                    ),
                    RadioListTile<RecurrenceMode>(
                      value: RecurrenceMode.afterCompletion,
                      contentPadding: EdgeInsets.zero,
                      title: Text(_getAfterCompletionLabel()),
                      subtitle: Text(
                        'Next due date counts from the day you actually finish it.',
                        style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (!_enabled) {
                        Navigator.of(context).pop((rule: null, mode: null));
                      } else {
                        final rule = _buildRule();
                        final modeStr = _mode == RecurrenceMode.afterCompletion
                            ? 'after_completion'
                            : 'on_schedule';
                        Navigator.of(context).pop((rule: rule.serialize(), mode: modeStr));
                      }
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekdayChip(int dayIndex, String label) {
    final isSelected = _byWeekday.contains(dayIndex);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _byWeekday.add(dayIndex);
          } else if (_byWeekday.length > 1) {
            _byWeekday.remove(dayIndex);
          }
        });
      },
    );
  }

  String _getOnScheduleLabel() {
    if (_freq == RecurrenceFreq.weekly) {
      if (_byWeekday.isNotEmpty) {
        const dayNames = {
          1: 'Monday',
          2: 'Tuesday',
          3: 'Wednesday',
          4: 'Thursday',
          5: 'Friday',
          6: 'Saturday',
          7: 'Sunday',
        };
        final sortedDays = _byWeekday.toList()..sort();
        final dayStr = sortedDays.map((d) => dayNames[d] ?? '').join(', ');
        return 'Every $dayStr regardless';
      }
      return _interval == 1 ? 'Every week regardless' : 'Every $_interval weeks regardless';
    } else if (_freq == RecurrenceFreq.daily) {
      return _interval == 1 ? 'Every day regardless' : 'Every $_interval days regardless';
    } else {
      final day = _byMonthDay;
      return 'Every month on day $day regardless';
    }
  }

  String _getAfterCompletionLabel() {
    if (_freq == RecurrenceFreq.daily) {
      return _interval == 1 ? '1 day after I finish it' : '$_interval days after I finish it';
    } else if (_freq == RecurrenceFreq.weekly) {
      return _interval == 1 ? '1 week after I finish it' : '$_interval weeks after I finish it';
    } else {
      return _interval == 1 ? '1 month after I finish it' : '$_interval months after I finish it';
    }
  }
}
