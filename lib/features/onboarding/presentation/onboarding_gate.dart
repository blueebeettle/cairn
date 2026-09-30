import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/onboarding_providers.dart';
import '../../navigation/presentation/navigation_shell.dart';
import 'onboarding_screen.dart';

/// Picks between the first-run tutorial and the app, off one flag.
///
/// A small root widget rather than a branch inside `main()`, for two reasons.
/// The decision has to *change* at runtime — finishing the tutorial swaps it
/// for the app without restarting anything — and that is a provider watch,
/// not a startup-time `if`. And `main()`'s startup sequence, including
/// `runStartupBootstrap`'s parallelised reads, stays exactly as it was: `main`
/// reads the flag once afterwards (`loadOnboardingCompleted`) and seeds
/// [initialOnboardingCompletedProvider] with it, so this widget never touches
/// the database itself.
///
/// [NavigationShell] is only built once the tutorial is done. It starts a day
/// timer, syncs home-screen widgets and consumes pending notification taps in
/// its `initState`; none of that should run underneath a tutorial. A launch
/// from a reminder still works — the shell reads the pending habit/task
/// providers when it does mount.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, this.child = const NavigationShell()});

  /// The app itself, shown once the tutorial is done. Only overridden by
  /// tests, so the gate can be exercised without the whole navigation shell.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(onboardingCompletedProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: completed
          ? child
          : const OnboardingScreen(key: ValueKey('onboarding')),
    );
  }
}
