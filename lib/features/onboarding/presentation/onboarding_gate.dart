import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/onboarding_providers.dart';
import '../../navigation/presentation/navigation_shell.dart';
import 'onboarding_screen.dart';

/// Picks between the first-run tutorial and the app, off one flag.
///
/// A small root widget rather than a branch inside `main()`: the decision has
/// to *change* at runtime (finishing the tutorial swaps in the app without
/// restarting), which is a provider watch, not a startup-time `if`. `main()`
/// reads the flag once (`loadOnboardingCompleted`) and seeds
/// [initialOnboardingCompletedProvider], so this widget never touches the
/// database and `runStartupBootstrap`'s parallelised reads stay as they were.
///
/// [NavigationShell] is only built once the tutorial is done: it starts a day
/// timer, syncs home-screen widgets and consumes pending notification taps in
/// its `initState`, and none of that should run underneath a tutorial. A launch
/// from a reminder still works; the shell reads the pending habit/task
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
