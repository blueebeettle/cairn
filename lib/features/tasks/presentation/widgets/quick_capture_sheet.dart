import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/time_service.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/providers/database_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/task_parser.dart';
import 'task_detail_sheet.dart';

/// Quick capture modal sheet with live natural-language parsing per SPEC.md §2.4.
///
/// Example input: "submit report fri 5pm !p1 #work ~2p"
/// Shows the parsed tokens as interactive chips live as the user types so they
/// are easily correctable before saving.
class QuickCaptureSheet extends ConsumerStatefulWidget {
  const QuickCaptureSheet({super.key, this.initialDate, this.parentContext});

  final String? initialDate;
  final BuildContext? parentContext;

  static Future<Task?> show(BuildContext context, {String? initialDate}) {
    return showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => QuickCaptureSheet(
        initialDate: initialDate,
        parentContext: context,
      ),
    );
  }

  @override
  ConsumerState<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends ConsumerState<QuickCaptureSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  ParsedTask _parsed = const ParsedTask(title: '');
  int? _overridePriority;
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final timeService = ref.read(timeServiceProvider);
    final parser = TaskParser(timeService: timeService);
    final raw = _controller.text;
    setState(() {
      _parsed = parser.parse(raw);
    });
  }

  void _openMoreOptions() {
    final timeService = ref.read(timeServiceProvider);
    final parser = TaskParser(timeService: timeService);
    final raw = _controller.text;
    final parsed = parser.parse(raw);

    final priority = _overridePriority ?? parsed.priority;
    int? dueAt = parsed.dueAtUtcMs;
    bool dueIsAllDay = parsed.dueIsAllDay;

    // Fall back to initialDate if provided and no dueAt was parsed
    if (dueAt == null && widget.initialDate != null) {
      final parts = widget.initialDate!.split('-');
      dueAt = DateTime.utc(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
        12,
      ).millisecondsSinceEpoch;
      dueIsAllDay = true;
    }

    final targetContext = widget.parentContext ?? context;

    Navigator.of(context).pop();

    if (targetContext.mounted) {
      TaskDetailSheet.show(
        targetContext,
        initialTitle: parsed.title,
        initialPriority: priority,
        initialProjectId: _selectedProjectId,
        initialEstimatePomodoros: parsed.estimatePomodoros,
        initialDueAt: dueAt,
        initialDueIsAllDay: dueIsAllDay,
        initialTags: parsed.tags,
        initialDate: widget.initialDate,
      );
    }
  }

  /// Explains the quick-capture mini-syntax (SPEC.md §2.4) for users who
  /// haven't discovered it from the persistent caption alone.
  void _showSyntaxHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors = dialogContext.colors;
        final tokens = dialogContext.tokens;
        final textTheme = Theme.of(dialogContext).textTheme;
        return AlertDialog(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Quick Capture syntax'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Type naturally and drop these tokens in anywhere — "
                    "they're recognized live and stripped out of the title.",
                    style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                  ),
                  const SizedBox(height: 16),
                  const _SyntaxRow(
                    token: '!p1 .. !p4',
                    description:
                        'Priority, 1 = urgent down to 4 = normal (default if omitted).',
                  ),
                  const _SyntaxRow(
                    token: '#tag',
                    description: 'Adds a tag, e.g. #work. Add as many as you like.',
                  ),
                  const _SyntaxRow(
                    token: '~2p or 2p',
                    description: 'Estimated focus sessions (pomodoros) for the task.',
                  ),
                  const _SyntaxRow(
                    token: 'fri 5pm',
                    description:
                        'Due date & time, read from the end of your text. Also try '
                        '"tomorrow", "today 9am", "sep 18", or "sep 18 5pm". Leave '
                        'out the time for an all-day task.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Everything else becomes the task title. Use “More options” "
                    "below to fine-tune anything before saving.",
                    style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit() async {
    final title = _parsed.title.trim();
    if (title.isEmpty) return;

    final repo = ref.read(tasksRepositoryProvider);
    final priority = _overridePriority ?? _parsed.priority;

    int? dueAt = _parsed.dueAtUtcMs;
    bool dueIsAllDay = _parsed.dueIsAllDay;

    // Fall back to initialDate if provided and no dueAt was parsed
    if (dueAt == null && widget.initialDate != null) {
      final parts = widget.initialDate!.split('-');
      dueAt = DateTime.utc(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
        12,
      ).millisecondsSinceEpoch;
      dueIsAllDay = true;
    }

    try {
      final task = await repo.createTask(
        title: title,
        priority: priority,
        dueAt: dueAt,
        dueIsAllDay: dueIsAllDay,
        estimatePomodoros: _parsed.estimatePomodoros,
        projectId: _selectedProjectId,
        tagNames: _parsed.tags,
      );

      if (mounted) {
        Navigator.of(context).pop(task);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating task: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final timeService = ref.watch(timeServiceProvider);
    final projectsAsync = ref.watch(projectsStreamProvider);

    final priority = _overridePriority ?? _parsed.priority;
    final priorityColor = switch (priority) {
      1 => tokens.danger,
      2 => tokens.warning,
      3 => tokens.series[1],
      _ => tokens.textMuted,
    };

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: colors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Quick Capture',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.help_outline_rounded),
                tooltip: 'Quick capture syntax',
                onPressed: _showSyntaxHelp,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Main input field
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'e.g. submit report fri 5pm !p1 #work ~2p',
              hintStyle: TextStyle(color: tokens.textMuted, fontSize: 15),
              filled: true,
              fillColor: colors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Persistent syntax legend (small, muted) so the mini-syntax is
          // discoverable without needing to open the help dialog.
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '!p1–!p4 priority · #tag · ~2p focus sessions · "fri 5pm" due date/time',
              style: textTheme.labelSmall?.copyWith(color: tokens.textMuted),
            ),
          ),

          // Live parsed result previews (SPEC.md §2.4)
          if (_parsed.title.isNotEmpty || _parsed.dueAtUtcMs != null || _parsed.tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Date/Time preview
                if (_parsed.dueAtUtcMs != null)
                  Chip(
                    avatar: Icon(Icons.event_outlined, size: 16, color: colors.primary),
                    label: Text(
                      _formatDuePreview(_parsed.dueAtUtcMs!, _parsed.dueIsAllDay, timeService),
                      style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    backgroundColor: colors.surfaceContainerHigh,
                  ),

                // Priority preview chip
                PopupMenuButton<int>(
                  initialValue: priority,
                  tooltip: 'Change Priority',
                  onSelected: (p) => setState(() => _overridePriority = p),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 1, child: Text('!p1 Urgent')),
                    const PopupMenuItem(value: 2, child: Text('!p2 High')),
                    const PopupMenuItem(value: 3, child: Text('!p3 Medium')),
                    const PopupMenuItem(value: 4, child: Text('!p4 Normal')),
                  ],
                  child: Chip(
                    avatar: Icon(Icons.flag_rounded, size: 16, color: priorityColor),
                    label: Text(
                      'P$priority',
                      style: textTheme.labelSmall?.copyWith(
                        color: priorityColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    backgroundColor: colors.surfaceContainerHigh,
                  ),
                ),

                // Tag chips
                for (final tag in _parsed.tags)
                  Chip(
                    avatar: const Icon(Icons.tag_rounded, size: 14),
                    label: Text('#$tag', style: textTheme.labelSmall),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),

                // Estimate pomodoros preview
                if (_parsed.estimatePomodoros != null)
                  Chip(
                    avatar: Icon(Icons.timer_outlined, size: 16, color: colors.primary),
                    label: Text(
                      '${_parsed.estimatePomodoros}p',
                      style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),

                // Project Selector
                projectsAsync.when(
                  data: (projects) {
                    if (projects.isEmpty) return const SizedBox.shrink();
                    final currentProj = projects
                        .where((p) => p.id == _selectedProjectId)
                        .firstOrNull;

                    return PopupMenuButton<String?>(
                      tooltip: 'Select Project',
                      onSelected: (id) => setState(() => _selectedProjectId = id),
                      itemBuilder: (_) => [
                        const PopupMenuItem<String?>(
                          value: null,
                          child: Text('No Project'),
                        ),
                        for (final p in projects)
                          PopupMenuItem<String?>(
                            value: p.id,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 6,
                                  backgroundColor: tokens.series[p.colorIndex % tokens.series.length],
                                ),
                                const SizedBox(width: 8),
                                Text(p.name),
                              ],
                            ),
                          ),
                      ],
                      child: Chip(
                        avatar: CircleAvatar(
                          radius: 5,
                          backgroundColor: currentProj != null
                              ? tokens.series[currentProj.colorIndex % tokens.series.length]
                              : tokens.textMuted,
                        ),
                        label: Text(
                          currentProj?.name ?? 'Project',
                          style: textTheme.labelSmall,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Action buttons: More options, Cancel, Add Task
          Row(
            children: [
              TextButton(
                onPressed: _openMoreOptions,
                child: const Text('More options'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add Task'),
                onPressed: _controller.text.trim().isEmpty ? null : _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuePreview(int utcMs, bool isAllDay, TimeService timeService) {
    final local = timeService.toLocal(utcMs);
    final today = timeService.todayLocalDate();
    final taskLocalDate = timeService.computeLocalDate(utcMs);

    String dateStr;
    if (taskLocalDate == today) {
      dateStr = 'Today';
    } else if (taskLocalDate == TimeService.addDays(today, 1)) {
      dateStr = 'Tomorrow';
    } else {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      dateStr = '${weekdays[local.weekday - 1]}, ${months[local.month - 1]} ${local.day}';
    }

    if (isAllDay) return dateStr;

    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$dateStr · $displayHour:$minute $period';
  }
}

/// One row of the quick-capture syntax legend: a monospaced token chip next
/// to a plain-language description.
class _SyntaxRow extends StatelessWidget {
  const _SyntaxRow({required this.token, required this.description});

  final String token;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 88),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              token,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.primary,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(description, style: textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
