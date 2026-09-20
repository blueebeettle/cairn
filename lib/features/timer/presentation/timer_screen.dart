import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_permission_helper.dart';
import '../../../core/widgets/focus_ring.dart';
import '../../../data/providers/database_provider.dart';
import '../../../theme/app_theme.dart';
import '../domain/timer_state.dart';
import 'timer_controller.dart';
import 'widgets/task_selector_sheet.dart';

/// Screen presenting the Focus Timer per SPEC.md §3 and M3 component theming.
///
/// Features four states with the ring grouped with its controls in a single Center:
/// - status chip -> ring: 24dp
/// - ring -> action buttons: 32dp
/// - action buttons -> interruptions: 28dp
/// Wrapped in a single Center so it sits as one block. No Spacers between individual elements.
///
/// States:
/// 1. Ready: SegmentedButton (Pomodoro/Flow), equal-width FilterChips, track-only FocusRing, FilledButton "Start focus".
/// 2. Running: Assist chip "Focusing", depleting FocusRing, FilledButton.tonal "Pause" + OutlinedButton "Stop", live interruption pills.
/// 3. Paused: FocusRing in lighter lavender, dimmed figure, "Paused · Xm Ys", "Resume" + "Stop".
/// 4. Complete: Full FocusRing "25m logged", 1-5 circular targets with "Scattered"/"Locked in", TextButton "Skip" + FilledButton "Start break".
///
/// Stopping shows a SnackBar with Undo over the Ready state. Stop is not red.
class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  int? _selectedRating;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(timerControllerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerControllerProvider);
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final topPadding = (timerState.isRunning ||
            timerState.isPaused ||
            timerState.isBreakRunning)
        ? 32.0
        : 24.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Focus Timer',
          style: textTheme.headlineSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: topPadding,
                  bottom: 32,
                ),
                child: _buildGroupedContent(context, timerState),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedContent(BuildContext context, TimerState timerState) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(timerControllerProvider.notifier);
    final clock = ref.read(clockProvider);
    final now = clock();

    // ── State 1: Ready ───────────────────────────────────────────────────────
    if (timerState.isIdle || timerState.isAbandoned) {
      final displayTime = timerState.isFlow
          ? '00:00'
          : _formatTime(timerState.plannedDurationS);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode Selector
          SegmentedButton<TimerMode>(
            segments: const [
              ButtonSegment<TimerMode>(
                value: TimerMode.pomodoro,
                label: Text('Pomodoro'),
                icon: Icon(Icons.timer_outlined),
              ),
              ButtonSegment<TimerMode>(
                value: TimerMode.flow,
                label: Text('Open-ended'),
                icon: Icon(Icons.all_inclusive_rounded),
              ),
            ],
            selected: {timerState.mode},
            onSelectionChanged: (selection) {
              controller.setMode(selection.first);
            },
          ),
          const SizedBox(height: 12),

          // Duration Chips (4 equal width)
          if (timerState.isPomodoro)
            Row(
              children: [15, 25, 45, 60].map((minutes) {
                final seconds = minutes * 60;
                final isSelected = timerState.plannedDurationS == seconds;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FilterChip(
                      showCheckmark: false,
                      label: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('$minutes min'),
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          controller.setPlannedDuration(seconds);
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            )
          else
            const SizedBox(height: 40),

          // Attached Task Section (§2.4)
          const SizedBox(height: 12),
          Center(child: _buildAttachedTaskSection(context, ref, timerState)),

          // status chip -> ring: 20dp
          const SizedBox(height: 16),

          // Ring (track only, planned time inside)
          Center(
            child: FocusRing(
              widthFactor: 0.60,
              progress: 0.0,
              drawProgress: false,
              figure: displayTime,
              label: timerState.isFlow ? 'OPEN-ENDED' : 'PLANNED',
            ),
          ),

          // ring -> action buttons: 32dp
          const SizedBox(height: 32),

          // Action button
          FilledButton(
            onPressed: () async {
              await NotificationPermissionHelper.ensureNotificationPermission(context);
              controller.startSession();
            },
            child: const Text('Start focus'),
          ),
        ],
      );
    }

    // ── State 2: Running ─────────────────────────────────────────────────────
    if (timerState.isRunning) {
      final remainingSeconds = timerState.computeRemainingSeconds(now);
      final elapsedSeconds = timerState.computeElapsedSeconds(now);
      final progress = timerState.plannedDurationS > 0
          ? (remainingSeconds / timerState.plannedDurationS).clamp(0.0, 1.0)
          : 1.0;
      final displayTime = timerState.isFlow
          ? _formatTime(elapsedSeconds)
          : _formatTime(remainingSeconds);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Assist chip: "Focusing"
          Center(
            child: Chip(
              avatar: Icon(
                Icons.play_circle_fill_rounded,
                size: 18,
                color: colors.primary,
              ),
              label: Text(timerState.isFlow ? 'Open-ended' : 'Focusing'),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: _buildAttachedTaskSection(context, ref, timerState)),

          // status chip -> ring: 20dp
          const SizedBox(height: 16),

          // Ring (DEPLETES as time counts down)
          Center(
            child: FocusRing(
              widthFactor: 0.60,
              progress: timerState.isFlow ? 1.0 : progress,
              figure: displayTime,
              label: timerState.isFlow ? 'ELAPSED' : 'REMAINING',
            ),
          ),

          // ring -> action buttons: 32dp
          const SizedBox(height: 32),

          // Action buttons: Pause + Stop side by side
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => controller.pauseSession(),
                  child: const Text('Pause'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleStop(context),
                  child: const Text('Stop'),
                ),
              ),
            ],
          ),

          // action buttons -> interruptions: 28dp
          const SizedBox(height: 28),

          // Interruptions
          _buildInterruptions(context, timerState),
        ],
      );
    }

    // ── State 3: Paused ──────────────────────────────────────────────────────
    if (timerState.isPaused) {
      final remainingSeconds = timerState.computeRemainingSeconds(now);
      final elapsedSeconds = timerState.computeElapsedSeconds(now);
      final progress = timerState.plannedDurationS > 0
          ? (remainingSeconds / timerState.plannedDurationS).clamp(0.0, 1.0)
          : 1.0;
      final displayTime = timerState.isFlow
          ? _formatTime(elapsedSeconds)
          : _formatTime(remainingSeconds);

      final pausedSeconds = timerState.pausedAtUtc != null
          ? (now - timerState.pausedAtUtc!) ~/ 1000
          : 0;
      final pm = pausedSeconds ~/ 60;
      final ps = pausedSeconds % 60;
      final pausedLabel = 'Paused · ${pm}m ${ps}s';

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status chip: "Paused · Xm Ys"
          Center(
            child: Chip(
              avatar: Icon(
                Icons.pause_circle_outline_rounded,
                size: 18,
                color: colors.secondary,
              ),
              label: Text(pausedLabel),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: _buildAttachedTaskSection(context, ref, timerState)),

          // status chip -> ring: 20dp
          const SizedBox(height: 16),

          // Ring (in lighter lavender colorScheme.secondary, figure dimmed)
          Center(
            child: FocusRing(
              widthFactor: 0.60,
              progress: timerState.isFlow ? 1.0 : progress,
              isPaused: true,
              figure: displayTime,
              label: 'PAUSED',
            ),
          ),

          // ring -> action buttons: 32dp
          const SizedBox(height: 32),

          // Action buttons: Resume + Stop side by side
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => controller.resumeSession(),
                  child: const Text('Resume'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleStop(context),
                  child: const Text('Stop'),
                ),
              ),
            ],
          ),

          // action buttons -> interruptions: 28dp
          const SizedBox(height: 28),

          // Interruptions
          _buildInterruptions(context, timerState),
        ],
      );
    }

    // ── State 4: Complete ────────────────────────────────────────────────────
    if (timerState.isCompleted) {
      final loggedMins = (timerState.plannedDurationS > 0
              ? timerState.plannedDurationS
              : timerState.computeElapsedSeconds(now)) ~/
          60;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              'Session Complete',
              style: textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // status chip -> ring: 24dp
          const SizedBox(height: 24),

          // Full ring: "25m logged"
          Center(
            child: FocusRing(
              widthFactor: 0.60,
              progress: 1.0,
              figure: '${loggedMins}m',
              label: 'LOGGED',
            ),
          ),

          // ring -> rating: 32dp
          const SizedBox(height: 32),

          // Rating targets 1-5 with "Scattered" / "Locked in"
          _buildRatingSection(context),

          // rating -> actions: 28dp
          const SizedBox(height: 28),

          // Action buttons: Skip + Start break
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    controller.submitRatingAndStartBreak(rating: null);
                  },
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    controller.submitRatingAndStartBreak(rating: _selectedRating);
                  },
                  child: const Text('Start break'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // ── Break Running ────────────────────────────────────────────────────────
    if (timerState.isBreakRunning) {
      final breakRemaining = timerState.computeBreakRemainingSeconds(now);
      final breakProgress = timerState.breakDurationS > 0
          ? (breakRemaining / timerState.breakDurationS).clamp(0.0, 1.0)
          : 0.0;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Chip(
              avatar: Icon(
                Icons.self_improvement_rounded,
                size: 18,
                color: tokens.success,
              ),
              label: const Text('Break in progress'),
            ),
          ),

          // status chip -> ring: 24dp
          const SizedBox(height: 24),

          Center(
            child: FocusRing(
              widthFactor: 0.60,
              progress: breakProgress,
              figure: _formatTime(breakRemaining),
              label: 'BREAK',
              progressColor: tokens.success,
            ),
          ),

          // ring -> action: 32dp
          const SizedBox(height: 32),

          OutlinedButton(
            onPressed: () => controller.skipBreak(),
            child: const Text('Skip break'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildInterruptions(BuildContext context, TimerState timerState) {
    final controller = ref.read(timerControllerProvider.notifier);
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Interruptions',
              style: textTheme.labelMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            Text(
              'Total: ${timerState.totalInterruptions}',
              style: textTheme.labelSmall?.copyWith(
                color: tokens.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    controller.recordInterruption(isInternal: true),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('My own thought (${timerState.interruptionsInternal})'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    controller.recordInterruption(isInternal: false),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Someone else (${timerState.interruptionsExternal})'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingSection(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'How focused were you?',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Helps you see which kinds of work actually hold your attention.',
          style: textTheme.bodySmall?.copyWith(
            color: tokens.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Scattered',
              style: textTheme.labelSmall?.copyWith(color: tokens.textMuted),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final val = index + 1;
                final isSelected = _selectedRating == val;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _selectedRating = val),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? colors.primary
                            : colors.surfaceContainerHigh,
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$val',
                        style: textTheme.labelLarge?.copyWith(
                          color: isSelected
                              ? colors.onPrimary
                              : colors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            Text(
              'Locked in',
              style: textTheme.labelSmall?.copyWith(color: tokens.textMuted),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleStop(BuildContext context) async {
    final controller = ref.read(timerControllerProvider.notifier);
    final clock = ref.read(clockProvider);
    final elapsedS =
        ref.read(timerControllerProvider).computeElapsedSeconds(clock());
    final elapsedM = elapsedS ~/ 60;
    final elapsedMsg = '${elapsedM}m';

    await controller.abandonSession();

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Session stopped. $elapsedMsg won\'t count toward totals.',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              controller.undoAbandonSession();
            },
          ),
        ),
      );
    }
  }

  Widget _buildAttachedTaskSection(
    BuildContext context,
    WidgetRef ref,
    TimerState timerState,
  ) {
    final colors = context.colors;

    if (timerState.taskId == null) {
      return ActionChip(
        avatar: Icon(Icons.add_task_rounded, size: 16, color: colors.primary),
        label: const Text('Attach task'),
        onPressed: () => TaskSelectorSheet.show(context),
      );
    }

    final taskAsync = ref.watch(taskDetailsStreamProvider(timerState.taskId!));
    return taskAsync.when(
      data: (td) {
        if (td == null) {
          return ActionChip(
            avatar: Icon(Icons.add_task_rounded, size: 16, color: colors.primary),
            label: const Text('Attach task'),
            onPressed: () => TaskSelectorSheet.show(context),
          );
        }

        final title = td.task.title;
        final estimate = td.task.estimatePomodoros != null
            ? ' · ${td.task.estimatePomodoros}p'
            : '';

        return InputChip(
          avatar: Icon(Icons.task_alt_rounded, size: 16, color: colors.primary),
          label: Text(
            '$title$estimate',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: () => TaskSelectorSheet.show(context),
          onDeleted: () {
            ref.read(timerControllerProvider.notifier).detachTask();
            ref.read(activeTaskIdProvider.notifier).state = null;
          },
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
          deleteButtonTooltipMessage: 'Detach task',
        );
      },
      loading: () => const SizedBox(height: 32),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  static String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }
}
