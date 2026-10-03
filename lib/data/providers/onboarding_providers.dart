import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/settings_repository.dart';
import 'database_provider.dart';

/// Riverpod wiring for the first-run tutorial (`OnboardingScreen`).

/// The `settings` key holding "the tutorial has been finished or skipped".
///
/// Stored as an int 0/1 (`getInt(key) == 1`, `setInt(key, 1)`), the same shape
/// `FeatureInfo.dismissedSettingsKey` uses for dismissed tips, rather than a
/// second storage convention. Unset and 0 both mean "show it".
const onboardingCompletedSettingsKey = 'onboarding_completed';

/// Reads the tutorial flag once, for `main()` to hand to the provider tree.
///
/// A separate step after `runStartupBootstrap` rather than one of its
/// parallelised reads, so the bootstrap's contents and timing are left alone.
/// It is a single indexed lookup on a database the bootstrap already opened.
///
/// An unreadable settings table answers "completed", as `FeatureInfoCard` does
/// for its own flag: a tutorial that can't record that it was finished would
/// greet the user on every launch, which is worse than never showing it once.
Future<bool> loadOnboardingCompleted(SettingsRepository settings) async {
  try {
    return await settings.getInt(onboardingCompletedSettingsKey) == 1;
  } catch (_) {
    return true;
  }
}

/// What `main()` read at startup. Defaults to `true` ("nothing to show") so a
/// test, or any host that never wires this up, lands straight on the app; same
/// shape as [deviceTzIdProvider], resolved once in `main()` and overridden
/// there.
final initialOnboardingCompletedProvider = Provider<bool>((ref) => true);

/// Whether the tutorial is done, and the one place that finishes it.
///
/// [complete] is the only writer, and only `OnboardingScreen`'s "Get started"
/// and "Skip" call it. Nothing writes the flag when the screen merely opens, so
/// a user who force-quits halfway sees the tutorial again rather than landing
/// in the app with it silently marked done.
class OnboardingCompletedNotifier extends StateNotifier<bool> {
  OnboardingCompletedNotifier(this._settingsRepo, {required bool initial})
      : super(initial);

  final SettingsRepository _settingsRepo;

  /// Marks the tutorial finished and persists that. State flips first so the
  /// app appears immediately; a failed write is swallowed, as in
  /// `FeatureInfoCard._dismiss`: the worst outcome is the tutorial returning
  /// next launch, which isn't worth an error in front of someone who just chose
  /// to leave it.
  Future<void> complete() async {
    state = true;
    try {
      await _settingsRepo.setInt(onboardingCompletedSettingsKey, 1);
    } catch (_) {}
  }
}

final onboardingCompletedProvider =
    StateNotifierProvider<OnboardingCompletedNotifier, bool>((ref) {
  return OnboardingCompletedNotifier(
    ref.watch(settingsRepositoryProvider),
    initial: ref.watch(initialOnboardingCompletedProvider),
  );
});
