import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notification_permission_helper.dart';
import '../../../../core/time/time_service.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/providers/database_provider.dart';
import '../../../../data/providers/reminder_config_providers.dart';
import '../../../../data/repositories/reminder_config_repository.dart';
import '../../../../data/repositories/tasks_repository.dart';
import '../../../../theme/app_theme.dart';
import '../../../reminders/reminder_service.dart';
import '../../../timer/presentation/timer_controller.dart';
import 'recurrence_picker_sheet.dart';
import 'task_deletion_handler.dart';

/// Task detail modal sheet for inspecting, editing, managing subtasks,
/// recurrence rules, and launching focus sessions.
///
/// When [taskDetails] is null, this operates in create mode:
/// - Primary button reads "Create task" and calls repo.createTask().
/// - Title is required to enable the button; everything else is optional.
/// - Subtasks and archive actions are hidden.
/// - Due date defaults to active tab's date (today on Today tab, none on Inbox).
class TaskDetailSheet extends ConsumerStatefulWidget {
  const TaskDetailSheet({
    super.key,
    this.taskDetails,
    this.initialDate,
    this.initialTitle,
    this.initialPriority,
    this.initialProjectId,
    this.initialEstimatePomodoros,
    this.initialDueAt,
    this.initialDueIsAllDay,
    this.initialTags,
  });

  final TaskWithDetails? taskDetails;
  final String? initialDate;
  final String? initialTitle;
  final int? initialPriority;
  final String? initialProjectId;
  final int? initialEstimatePomodoros;
  final int? initialDueAt;
  final bool? initialDueIsAllDay;
  final List<String>? initialTags;

  static Future<void> show(
    BuildContext context, {
    TaskWithDetails? taskDetails,
    String? initialDate,
    String? initialTitle,
    int? initialPriority,
    String? initialProjectId,
    int? initialEstimatePomodoros,
    int? initialDueAt,
    bool? initialDueIsAllDay,
    List<String>? initialTags,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskDetailSheet(
        taskDetails: taskDetails,
        initialDate: initialDate,
        initialTitle: initialTitle,
        initialPriority: initialPriority,
        initialProjectId: initialProjectId,
        initialEstimatePomodoros: initialEstimatePomodoros,
        initialDueAt: initialDueAt,
        initialDueIsAllDay: initialDueIsAllDay,
        initialTags: initialTags,
      ),
    );
  }

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _newSubtaskController;

  late int _priority;
  late String? _selectedProjectId;
  late int? _estimatePomodoros;
  late int? _dueAt;
  late bool _dueIsAllDay;
  late String? _recurrenceRule;
  late String? _recurrenceMode;
  late List<String> _tags;

  /// Configured countdown offsets, minutes before the due time. Only
  /// meaningful for a task with a specific due time — an all-day task has
  /// nothing to count down to and is covered by the daily digest instead.
  /// Loaded asynchronously for an existing timed task (`_loadReminderOffsets`)
  /// since it now lives in its own table rather than a scalar on the task.
  List<int> _reminderOffsetsMin = [];

  bool get isCreateMode => widget.taskDetails == null;

  @override
  void initState() {
    super.initState();
    final task = widget.taskDetails?.task;
    _titleController = TextEditingController(
      text: task?.title ?? widget.initialTitle ?? '',
    );
    _titleController.addListener(_onTitleChanged);

    _notesController = TextEditingController(text: task?.notes ?? '');
    _newSubtaskController = TextEditingController();

    _priority = task?.priority ?? widget.initialPriority ?? 4;
    _selectedProjectId = task?.projectId ?? widget.initialProjectId;
    _estimatePomodoros = task?.estimatePomodoros ?? widget.initialEstimatePomodoros;

    if (task != null) {
      _dueAt = task.dueAt;
      _dueIsAllDay = task.dueIsAllDay;
    } else if (widget.initialDueAt != null) {
      _dueAt = widget.initialDueAt;
      _dueIsAllDay = widget.initialDueIsAllDay ?? true;
    } else if (widget.initialDate != null) {
      final parts = widget.initialDate!.split('-');
      _dueAt = DateTime.utc(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
        12,
      ).millisecondsSinceEpoch;
      _dueIsAllDay = true;
    } else {
      _dueAt = null;
      _dueIsAllDay = true;
    }

    _recurrenceRule = task?.recurrenceRule;
    _recurrenceMode = task?.recurrenceMode;

    if (task != null) {
      if (!_dueIsAllDay) _loadReminderOffsets(task.id);
    } else if (!_dueIsAllDay) {
      _loadDefaultReminderOffsets();
    }

    _tags = (widget.initialTags ??
            widget.taskDetails?.tags.map((t) => t.name).toList() ??
            [])
        .toList();
  }

  void _onTitleChanged() {
    setState(() {});
  }

  Future<void> _loadReminderOffsets(String taskId) async {
    final rows =
        await ref.read(reminderConfigRepositoryProvider).taskReminderOffsets(taskId);
    if (!mounted) return;
    setState(() {
      _reminderOffsetsMin = [for (final r in rows) r.offsetMin]..sort();
    });
  }

  Future<void> _loadDefaultReminderOffsets() async {
    final defaults = await ref
        .read(reminderConfigRepositoryProvider)
        .defaultTaskReminderOffsetsMinSetting();
    if (!mounted) return;
    setState(() => _reminderOffsetsMin = defaults);
  }

  /// "At time", "5m before", "1h before", "1 day before".
  static String _formatOffsetLabel(int minutes) {
    if (minutes == 0) return 'At time';
    if (minutes % (24 * 60) == 0) {
      final days = minutes ~/ (24 * 60);
      return days == 1 ? '1 day before' : '$days days before';
    }
    if (minutes % 60 == 0) return '${minutes ~/ 60}h before';
    return '${minutes}m before';
  }

  Future<void> _addReminderOffset() async {
    if (_reminderOffsetsMin.length >= ReminderConfigRepository.maxRemindersPerItem) {
      return;
    }
    if (_reminderOffsetsMin.isEmpty) {
      await NotificationPermissionHelper.ensureNotificationPermission(context);
      if (!mounted) return;
    }
    const choices = [0, 5, 10, 15, 30, 60, 120, 1440];
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Remind before due'),
        children: [
          for (final minutes in choices)
            if (!_reminderOffsetsMin.contains(minutes))
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(minutes),
                child: Text(_formatOffsetLabel(minutes)),
              ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _reminderOffsetsMin = [..._reminderOffsetsMin, selected]..sort();
    });
  }

  void _removeReminderOffset(int minutes) {
    setState(() {
      _reminderOffsetsMin = _reminderOffsetsMin.where((m) => m != minutes).toList();
    });
  }

  String _formatTimeOnly(int utcMs, TimeService timeService) {
    final local = timeService.toLocal(utcMs);
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _notesController.dispose();
    _newSubtaskController.dispose();
    super.dispose();
  }

  Future<void> _createTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final repo = ref.read(tasksRepositoryProvider);
    final created = await repo.createTask(
      title: title,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      projectId: _selectedProjectId,
      priority: _priority,
      estimatePomodoros: _estimatePomodoros,
      dueAt: _dueAt,
      dueIsAllDay: _dueIsAllDay,
      recurrenceRule: _recurrenceRule,
      recurrenceMode: _recurrenceMode,
      tagNames: _tags,
    );

    // Countdown reminders only make sense once the task has a specific due
    // time — an all-day task has nothing to count down to.
    if (!_dueIsAllDay && _reminderOffsetsMin.isNotEmpty) {
      await ref
          .read(reminderConfigRepositoryProvider)
          .setTaskReminderOffsets(created.id, _reminderOffsetsMin);
      try {
        await ref.read(reminderServiceProvider).scheduleFor(created);
      } catch (_) {
        // No notification plugin (desktop, tests). The task is saved.
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveChanges() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final repo = ref.read(tasksRepositoryProvider);
    final taskId = widget.taskDetails!.id;

    await repo.updateTask(
      taskId,
      title: title,
      notes: _notesController.text.trim(),
      projectId: _selectedProjectId,
      clearProject: _selectedProjectId == null,
      priority: _priority,
      estimatePomodoros: _estimatePomodoros,
      clearEstimate: _estimatePomodoros == null,
      recurrenceRule: _recurrenceRule,
      recurrenceMode: _recurrenceMode,
      clearRecurrence: _recurrenceRule == null,
    );

    // If dueAt changed
    if (_dueAt != widget.taskDetails!.dueAt || _dueIsAllDay != widget.taskDetails!.dueIsAllDay) {
      await repo.rescheduleTask(
        taskId,
        newDueAt: _dueAt,
        dueIsAllDay: _dueIsAllDay,
      );
    }

    // Always write the current set, even empty — an all-day task or one with
    // its reminders cleared should end up with none.
    final offsets = _dueIsAllDay ? const <int>[] : _reminderOffsetsMin;
    await ref
        .read(reminderConfigRepositoryProvider)
        .setTaskReminderOffsets(taskId, offsets);
    try {
      final updated = await repo.getTask(taskId);
      if (updated != null) {
        await ref.read(reminderServiceProvider).scheduleFor(updated);
      }
    } catch (_) {
      // No notification plugin (desktop, tests). The task is saved.
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _addSubtask() async {
    if (isCreateMode) return;
    final title = _newSubtaskController.text.trim();
    if (title.isEmpty) return;

    final repo = ref.read(tasksRepositoryProvider);
    await repo.createTask(
      title: title,
      parentId: widget.taskDetails!.id,
    );
    _newSubtaskController.clear();
    setState(() {});
  }

  void _startFocusSession() {
    if (isCreateMode) return;
    // 1. Attach task to timer controller
    ref.read(timerControllerProvider.notifier).attachTask(
      widget.taskDetails!.id,
      projectId: _selectedProjectId,
    );
    // 2. Set active task provider
    ref.read(activeTaskIdProvider.notifier).state = widget.taskDetails!.id;

    // 3. Close sheet
    Navigator.of(context).pop();

    // 4. Navigate to Timer screen (index 1)
    ref.read(navigationIndexProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final timeService = ref.watch(timeServiceProvider);
    final projectsAsync = ref.watch(projectsStreamProvider);
    final repo = ref.watch(tasksRepositoryProvider);

    final priorityColor = switch (_priority) {
      1 => tokens.danger,
      2 => tokens.warning,
      3 => tokens.series[1],
      _ => tokens.textMuted,
    };

    final isSubtask = widget.taskDetails?.isSubtask ?? false;
    final canSubmit = _titleController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header bar
            Row(
              children: [
                CircleAvatar(
                  radius: 8,
                  backgroundColor: priorityColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isCreateMode
                        ? 'New Task'
                        : (isSubtask ? 'Subtask' : 'Task Details'),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isCreateMode) ...[
                  IconButton(
                    tooltip: 'Archive Task',
                    icon: Icon(Icons.archive_outlined, color: tokens.textMuted),
                    onPressed: () async {
                      await repo.archiveTask(widget.taskDetails!.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete Task',
                    icon: Icon(Icons.delete_outline_rounded, color: tokens.danger),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await handleTaskDeletion(
                        context: context,
                        ref: ref,
                        task: widget.taskDetails!.task,
                      );
                    },
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title input
            TextField(
              controller: _titleController,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'What needs to be done?',
                filled: true,
                fillColor: colors.surfaceContainerLow,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Notes input
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                filled: true,
                fillColor: colors.surfaceContainerLow,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Carried-over or existing tags
            if (_tags.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final tag in _tags)
                    Chip(
                      avatar: const Icon(Icons.tag_rounded, size: 14),
                      label: Text('#$tag', style: textTheme.labelSmall),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // ── Priority ─────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRIORITY',
                        style: textTheme.labelSmall?.copyWith(
                          color: tokens.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('P1')),
                          ButtonSegment(value: 2, label: Text('P2')),
                          ButtonSegment(value: 3, label: Text('P3')),
                          ButtonSegment(value: 4, label: Text('P4')),
                        ],
                        selected: {_priority},
                        onSelectionChanged: (s) => setState(() => _priority = s.first),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Project & Estimate ───────────────────────────────────────────
            Builder(
              builder: (context) {
                final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.25;

                final projectField = projectsAsync.when(
                  data: (projects) => DropdownButtonFormField<String?>(
                    initialValue: _selectedProjectId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Project',
                      filled: true,
                      fillColor: colors.surfaceContainerLow,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No Project')),
                      for (final p in projects)
                        DropdownMenuItem(
                          value: p.id,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 5,
                                backgroundColor: tokens.series[p.colorIndex % tokens.series.length],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(p.name, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (val) => setState(() => _selectedProjectId = val),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                );

                final estimateField = DropdownButtonFormField<int?>(
                  initialValue: _estimatePomodoros,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'How many sessions?',
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (var i = 1; i <= 8; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text('$i session${i > 1 ? 's' : ''}', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (val) => setState(() => _estimatePomodoros = val),
                );

                if (isLargeText) {
                  return Column(
                    children: [
                      projectField,
                      const SizedBox(height: 12),
                      estimateField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: projectField),
                    const SizedBox(width: 12),
                    Expanded(child: estimateField),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Due Date & Recurrence ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(
                      _dueAt != null
                          ? _formatDueDisplay(_dueAt!, _dueIsAllDay, timeService)
                          : 'Set Due Date',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueAt != null
                            ? DateTime.fromMillisecondsSinceEpoch(_dueAt!)
                            : now,
                        firstDate: now.subtract(const Duration(days: 365)),
                        lastDate: now.add(const Duration(days: 365 * 3)),
                      );
                      if (picked != null) {
                        setState(() {
                          _dueAt = DateTime.utc(picked.year, picked.month, picked.day, 12)
                              .millisecondsSinceEpoch;
                          _dueIsAllDay = true;
                        });
                      }
                    },
                  ),
                ),
                if (!isSubtask) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.repeat_rounded, size: 18),
                      label: Text(
                        _recurrenceRule != null ? 'Repeating' : 'Repeat',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () async {
                        final res = await RecurrencePickerSheet.show(
                          context,
                          currentRule: _recurrenceRule,
                          currentMode: _recurrenceMode,
                        );
                        if (res != null) {
                          setState(() {
                            _recurrenceRule = res.rule;
                            _recurrenceMode = res.mode;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),

            if (_dueAt != null) ...[
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('Clear due date'),
                    onPressed: () => setState(() {
                      _dueAt = null;
                      _dueIsAllDay = true;
                      _reminderOffsetsMin = [];
                    }),
                  ),
                  TextButton.icon(
                    icon: Icon(
                      _dueIsAllDay
                          ? Icons.schedule_outlined
                          : Icons.schedule_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _dueIsAllDay
                          ? 'Add a time'
                          : _formatTimeOnly(_dueAt!, timeService),
                    ),
                    onPressed: () async {
                      final currentLocal = timeService.toLocal(_dueAt!);
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _dueIsAllDay
                            ? const TimeOfDay(hour: 9, minute: 0)
                            : TimeOfDay(
                                hour: currentLocal.hour,
                                minute: currentLocal.minute),
                      );
                      if (picked == null) return;
                      final wasAllDay = _dueIsAllDay;
                      final combined = DateTime(
                        currentLocal.year,
                        currentLocal.month,
                        currentLocal.day,
                        picked.hour,
                        picked.minute,
                      );
                      setState(() {
                        _dueAt = timeService.toUtcMs(combined);
                        _dueIsAllDay = false;
                      });
                      // Going from all-day to timed for the first time: start
                      // this task off with the usual reminders.
                      if (wasAllDay && _reminderOffsetsMin.isEmpty) {
                        await _loadDefaultReminderOffsets();
                      }
                    },
                  ),
                  if (!_dueIsAllDay)
                    TextButton.icon(
                      icon: const Icon(Icons.schedule_outlined, size: 16),
                      label: const Text('Remove time'),
                      onPressed: () => setState(() {
                        _dueIsAllDay = true;
                        _reminderOffsetsMin = [];
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (!_dueIsAllDay) ...[
                Text(
                  'Remind me',
                  style: textTheme.bodyLarge?.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final minutes in _reminderOffsetsMin)
                      InputChip(
                        label: Text(_formatOffsetLabel(minutes)),
                        onDeleted: () => _removeReminderOffset(minutes),
                      ),
                    if (_reminderOffsetsMin.length <
                        ReminderConfigRepository.maxRemindersPerItem)
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add reminder'),
                        onPressed: _addReminderOffset,
                      ),
                  ],
                ),
              ] else
                Text(
                  'All-day tasks are covered by your daily digest '
                  '(Settings → Reminders).',
                  style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                ),
            ],

            const SizedBox(height: 16),

            // ── Subtasks (One level only per §2.4, hidden in create mode) ───
            if (!isCreateMode && !isSubtask) ...[
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'SUBTASKS',
                style: textTheme.labelSmall?.copyWith(
                  color: tokens.textMuted,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),

              StreamBuilder<List<Task>>(
                stream: repo.watchSubtasks(widget.taskDetails!.id),
                builder: (context, snapshot) {
                  final subtasks = snapshot.data ?? const [];
                  return Column(
                    children: [
                      for (final st in subtasks)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Checkbox(
                            value: st.status == 'done',
                            onChanged: (_) async {
                              unawaited(HapticFeedback.lightImpact().catchError((_) {}));
                              if (st.status == 'done') {
                                await repo.uncompleteTask(st.id);
                              } else {
                                await repo.completeTask(st.id);
                              }
                            },
                          ),
                          title: Text(
                            st.title,
                            style: TextStyle(
                              decoration: st.status == 'done'
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: st.status == 'done' ? tokens.textMuted : null,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => repo.archiveTask(st.id),
                          ),
                        ),
                    ],
                  );
                },
              ),

              // Add subtask input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newSubtaskController,
                      decoration: InputDecoration(
                        hintText: 'Add subtask...',
                        isDense: true,
                        filled: true,
                        fillColor: colors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _addSubtask(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: colors.primary,
                    onPressed: _addSubtask,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // ── Primary Actions ──────────────────────────────────────────────
            if (isCreateMode)
              FilledButton(
                onPressed: canSubmit ? _createTask : null,
                child: const Text('Create task'),
              )
            else
              Row(
                children: [
                  // "Start Focus" button to link to timer (§3, §4.9)
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Focus Task'),
                      onPressed: _startFocusSession,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // "Save" button
                  Expanded(
                    child: FilledButton(
                      onPressed: canSubmit ? _saveChanges : null,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDueDisplay(int utcMs, bool isAllDay, TimeService timeService) {
    final local = timeService.toLocal(utcMs);
    final today = timeService.todayLocalDate();
    final taskLocalDate = timeService.computeLocalDate(utcMs);

    String dateStr;
    if (taskLocalDate == today) {
      dateStr = 'Today';
    } else if (taskLocalDate == TimeService.addDays(today, 1)) {
      dateStr = 'Tomorrow';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      dateStr = '${months[local.month - 1]} ${local.day}';
    }

    if (isAllDay) return dateStr;

    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$dateStr $displayHour:$minute $period';
  }
}
