import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class TimerPlaceholderScreen extends StatelessWidget {
  const TimerPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Focus Timer',
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
                  Icons.timer_outlined,
                  size: 40,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Timer Engine',
                style: textTheme.headlineSmall?.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Focus timer state machine, recovery, and persistence arrive in Phase 02 per SPEC.md §3.',
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
