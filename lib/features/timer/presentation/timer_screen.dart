import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_permission_helper.dart';
import '../../../core/widgets/cairn_card.dart';
import '../../../core/widgets/focus_ring.dart';
import '../../../core/widgets/feature_info.dart';
import '../../../core/widgets/feature_info_content.dart';
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
/// 1. Ready: pill mode picker (Pomodoro/Open-ended), equal-width FilterChips, track-only FocusRing, FilledButton "Start focus".
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

/// The fixed length options. Anything else is a "custom" length.
const List<int> _presetMinutes = [15, 25, 45, 60];

/// Bounds for a custom focus length. Five minutes is the shortest span that
/// still produces a session worth recording; three hours is well past any
/// realistic single sitting and keeps the slider usable.
const int _customMinMinutes = 5;
const int _customMaxMinutes = 180;

/// Settings key holding the last custom length, so reopening the picker
/// starts where the user left it instead of resetting to a default.
const String _customMinutesKey = 'timer_custom_minutes';

class _TimerScreenState extends ConsumerState<TimerScreen> {
  int? _selectedRating;

  /// Last custom length the user picked, remembered across restarts.
  int _customMinutes = 30;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(timerControllerProvider.notifier).initialize();
    });
    Future.microtask(_loadCustomMinutes);
  }

  Future<void> _loadCustomMinutes() async {
    try {
      final stored =
          await ref.read(settingsRepositoryProvider).getInt(_customMinutesKey);
      if (stored != null && mounted) {
        setState(() => _customMinutes = _clampCustom(stored));
      }
    } catch (_) {
      // Falls back to the default; never worth failing the screen over.
    }
  }

  static int _clampCustom(int minutes) =>
      minutes.clamp(_customMinMinutes, _customMaxMinutes);

  bool _isCustomSelected(int plannedDurationS) {
    if (plannedDurationS <= 0 || plannedDurationS % 60 != 0) return true;
    return !_presetMinutes.contains(plannedDurationS ~/ 60);
  }

  /// Opens the custom-length picker and applies the result.
  Future<void> _pickCustomDuration(
    TimerController controller,
    int plannedDurationS,
  ) async {
    final current = _isCustomSelected(plannedDurationS)
        ? _clampCustom(plannedDurationS ~/ 60)
        : _customMinutes;

    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => _CustomDurationDialog(initialMinutes: current),
    );
    if (picked == null || !mounted) return;

    final minutes = _clampCustom(picked);
    setState(() => _customMinutes = minutes);
    controller.setPlannedDuration(minutes * 60);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setInt(_customMinutesKey, minutes);
    } catch (_) {
      // The length is already applied to this session either way.
    }
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
          'Focus',
          style: textTheme.headlineSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: const [
          FeatureInfoButton(info: FeatureInfoContent.timer),
        ],
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FeatureInfoCard(
                      info: FeatureInfoContent.timer,
                      padding: EdgeInsets.only(bottom: 12),
                    ),
                    _buildGroupedContent(context, timerState),
                  ],
                ),
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
          _buildModePicker(context, controller, timerState.mode),
          const SizedBox(height: 12),

          // Duration chips: four presets plus Custom, all equal width.
          if (timerState.isPomodoro)
            Row(
              children: [
                ..._presetMinutes.map((minutes) {
                  final seconds = minutes * 60;
                  final isSelected = timerState.plannedDurationS == seconds;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: FilterChip(
                        showCheckmark: false,
                        shape: const StadiumBorder(),
                        side: _TimerChrome.chipSide(context, isSelected),
                        backgroundColor: CardChrome.card(context),
                        selectedColor: colors.primary,
                        labelStyle: _TimerChrome.chipLabel(context, isSelected),
                        labelPadding: EdgeInsets.zero,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
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
                }),
                // Selected whenever the planned length is not one of the
                // presets, so a custom length still reads as "the chosen one"
                // when you come back to the screen. Shows the value itself
                // once picked rather than a generic "Custom".
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Builder(builder: (context) {
                      final isSelected =
                          _isCustomSelected(timerState.plannedDurationS);
                      return FilterChip(
                        showCheckmark: false,
                        shape: const StadiumBorder(),
                        side: _TimerChrome.chipSide(context, isSelected),
                        backgroundColor: CardChrome.card(context),
                        selectedColor: colors.primary,
                        labelStyle: _TimerChrome.chipLabel(context, isSelected),
                        labelPadding: EdgeInsets.zero,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                        label: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isSelected
                                  ? '${timerState.plannedDurationS ~/ 60} min'
                                  : 'Custom',
                            ),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => _pickCustomDuration(
                          controller,
                          timerState.plannedDurationS,
                        ),
                      );
                    }),
                  ),
                ),
              ],
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
          _StatusChip(
            icon: Icons.play_circle_fill_rounded,
            label: timerState.isFlow ? 'Open-ended' : 'Focusing',
            foreground: colors.primary,
            background: colors.primaryContainer,
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
          // Status chip: "Paused · Xm Ys". The lavender `secondary` itself
          // scores 2.74:1 on cream and must never carry text, so the chip
          // takes the lavender *container* pair — the same family the paused
          // ring arc uses, at a contrast that is legible.
          _StatusChip(
            icon: Icons.pause_circle_outline_rounded,
            label: pausedLabel,
            foreground: colors.onSecondaryContainer,
            background: colors.secondaryContainer,
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
          _StatusChip(
            icon: Icons.self_improvement_rounded,
            label: 'Break in progress',
            foreground: tokens.success,
            // No container slot exists for the success token, so the fill is
            // a tint of it — the same thing the Stats trend chip does.
            background: tokens.success.withValues(alpha: 0.14),
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

  /// Pomodoro / Open-ended, as a tinted track with one filled pill.
  ///
  /// Not `SegmentedButton`: the global `segmentedButtonTheme` gives two
  /// adjoining stadium outlines, which is right where it is already used but
  /// reads as two buttons rather than the single-track control this redesign
  /// uses for mode-like choices. Built the same way the Stats range picker
  /// builds its Week/30d/90d/All track, rather than reskinning that theme —
  /// five other screens depend on it.
  Widget _buildModePicker(
    BuildContext context,
    TimerController controller,
    TimerMode selected,
  ) {
    const labels = {
      TimerMode.pomodoro: 'Pomodoro',
      TimerMode.flow: 'Open-ended',
    };

    return Container(
      decoration: BoxDecoration(
        color: CardChrome.pickerTrack(context),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final mode in TimerMode.values) ...[
            if (mode != TimerMode.values.first) const SizedBox(width: 2),
            Expanded(
              child: _ModeSegment(
                label: labels[mode]!,
                selected: mode == selected,
                onTap: () => controller.setMode(mode),
              ),
            ),
          ],
        ],
      ),
    );
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
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: tokens.textSecondary,
              ),
            ),
            Text(
              'Total: ${timerState.totalInterruptions}',
              style: textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
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
            // Flexible so the two end labels give way before the row does.
            // Five 40dp targets plus their gaps already eat most of a 360dp
            // screen, and at a large text scale the labels would otherwise
            // push the row into an overflow.
            Flexible(
              child: Text(
                'Scattered',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(color: tokens.textMuted),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final val = index + 1;
                final isSelected = _selectedRating == val;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
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
            Flexible(
              child: Text(
                'Locked in',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: textTheme.labelSmall?.copyWith(color: tokens.textMuted),
              ),
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
        shape: const StadiumBorder(),
        side: BorderSide(color: colors.outline),
        backgroundColor: CardChrome.card(context),
        labelStyle: _TimerChrome.taskChipLabel(context),
        label: const Text('Attach task'),
        onPressed: () => TaskSelectorSheet.show(context),
      );
    }

    final taskAsync = ref.watch(taskDetailsStreamProvider(timerState.taskId!));
    return taskAsync.when(
      data: (td) {
        if (td == null) {
          return ActionChip(
            avatar:
                Icon(Icons.add_task_rounded, size: 16, color: colors.primary),
            shape: const StadiumBorder(),
            side: BorderSide(color: colors.outline),
            backgroundColor: CardChrome.card(context),
            labelStyle: _TimerChrome.taskChipLabel(context),
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
          shape: const StadiumBorder(),
          side: BorderSide.none,
          backgroundColor: context.tokens.lineSoft,
          labelStyle: _TimerChrome.taskChipLabel(context),
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

/// Picker for a custom focus length.
///
/// A slider in five-minute steps covers the whole range quickly, and the
/// -/+ buttons handle the last bit of precision without fighting the slider
/// on a small screen.
class _CustomDurationDialog extends StatefulWidget {
  const _CustomDurationDialog({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_CustomDurationDialog> createState() => _CustomDurationDialogState();
}

class _CustomDurationDialogState extends State<_CustomDurationDialog> {
  late int _minutes = widget.initialMinutes
      .clamp(_customMinMinutes, _customMaxMinutes);

  void _nudge(int delta) {
    setState(() {
      _minutes =
          (_minutes + delta).clamp(_customMinMinutes, _customMaxMinutes);
    });
  }

  String get _readable {
    final h = _minutes ~/ 60;
    final m = _minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return h == 1 ? '1 hour' : '$h hours';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Custom focus length'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_readable, style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                onPressed:
                    _minutes > _customMinMinutes ? () => _nudge(-5) : null,
                icon: const Icon(Icons.remove),
                tooltip: 'Five minutes shorter',
              ),
              Expanded(
                child: Slider(
                  value: _minutes.toDouble(),
                  min: _customMinMinutes.toDouble(),
                  max: _customMaxMinutes.toDouble(),
                  divisions:
                      (_customMaxMinutes - _customMinMinutes) ~/ 5,
                  label: _readable,
                  onChanged: (v) => setState(() => _minutes = v.round()),
                ),
              ),
              IconButton.outlined(
                onPressed:
                    _minutes < _customMaxMinutes ? () => _nudge(5) : null,
                icon: const Icon(Icons.add),
                tooltip: 'Five minutes longer',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Anything from $_customMinMinutes minutes to '
            '${_customMaxMinutes ~/ 60} hours.',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_minutes),
          child: const Text('Use this'),
        ),
      ],
    );
  }
}

/// Chip typography for the Focus screen. Surfaces and tracks come from the
/// shared [CardChrome].
abstract final class _TimerChrome {


  /// A duration chip's outline. The selected chip's border matches its fill so
  /// the pill reads as one solid shape rather than a filled chip inside a
  /// contrasting ring.
  static BorderSide chipSide(BuildContext context, bool selected) {
    final colors = context.colors;
    return BorderSide(color: selected ? colors.primary : colors.outline);
  }

  /// Duration-chip label: 11px, 700, no tracking.
  static TextStyle? chipLabel(BuildContext context, bool selected) {
    final colors = context.colors;
    return Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: selected ? colors.onPrimary : context.tokens.textSecondary,
        );
  }

  /// Attached-task chip label: 12px, 700, no tracking.
  static TextStyle? taskChipLabel(BuildContext context) {
    return Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: context.tokens.textSecondary,
        );
  }
}

/// One segment of the Pomodoro / Open-ended pill.
///
/// `Semantics(inMutuallyExclusiveGroup)` is what keeps this readable to a
/// screen reader now that it is two plain tap targets rather than a real
/// `SegmentedButton` — the same thing the Stats range picker does.
class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 11.5,
                    letterSpacing: 0,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? colors.onPrimary : tokens.textMuted,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The centred state pill above the ring — Focusing / Paused / Break.
///
/// One widget for all three so the three states cannot drift apart; only the
/// icon, the wording and the colour pair change.
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      color: foreground,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
