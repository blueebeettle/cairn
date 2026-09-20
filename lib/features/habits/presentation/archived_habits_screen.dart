import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/habit_providers.dart';
import '../../../theme/app_theme.dart';
import '../../reminders/reminder_service.dart';
import '../domain/habit_presentation.dart';
import 'habit_detail_screen.dart';

/// Archived habits. Their history is intact; restoring one brings the streak
/// back exactly as the schedule says it stands.
class ArchivedHabitsScreen extends ConsumerWidget {
  const ArchivedHabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedHabitsProvider);
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(title: const Text('Archived habits')),
      body: archivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (habits) {
          if (habits.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Nothing archived yet.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: tokens.textSecondary),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: habits.length,
            itemBuilder: (context, i) {
              final habit = habits[i];
              final accent = HabitColors.of(context, habit.colorIndex);
              return ListTile(
                leading: ExcludeSemantics(
                  child: CircleAvatar(
                    backgroundColor: accent.withValues(alpha: 0.14),
                    child: Icon(HabitIcons.of(habit.iconName), color: accent),
                  ),
                ),
                title: Text(habit.title),
                subtitle: Text(HabitScheduleText.describe(habit.scheduleRule)),
                onTap: () => HabitDetailScreen.open(context, habit.id),
                trailing: TextButton(
                  onPressed: () async {
                    final repo = ref.read(habitsRepositoryProvider);
                    final reminders = ref.read(reminderServiceProvider);
                    await repo.restoreHabit(habit.id);
                    final restored = await repo.habitById(habit.id);
                    if (restored != null) {
                      try {
                        await reminders.scheduleForHabit(restored);
                      } catch (_) {}
                    }
                  },
                  child: const Text('Restore'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
