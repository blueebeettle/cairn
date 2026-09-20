import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class TasksPlaceholderScreen extends StatelessWidget {
  const TasksPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tasks',
          style: textTheme.headlineMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 40,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Task Management',
                style: textTheme.headlineSmall?.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Projects, priorities, recurring rules, and task capture arrive in Phase 03 per SPEC.md §2.4.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
