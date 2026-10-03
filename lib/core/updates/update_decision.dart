import 'update_checker.dart';

/// What the UI should do about a [ReleaseStatus]. The policy lives in
/// [decideUpdateAction]; the dialogs only present the answer.
sealed class UpdateAction {
  const UpdateAction();
}

/// No newer release, or the newer one was already declined and isn't mandatory.
class NoAction extends UpdateAction {
  const NoAction();
}

/// Offer [release]; the tester may dismiss it.
class OptionalUpdate extends UpdateAction {
  const OptionalUpdate(this.release);

  final ReleaseInfo release;
}

/// [release] must be installed and the dialog can't be dismissed. [reason] is
/// shown to the tester.
class MandatoryUpdate extends UpdateAction {
  const MandatoryUpdate(this.release, this.reason);

  final ReleaseInfo release;
  final MandatoryReason reason;
}

/// Why an update is mandatory.
enum MandatoryReason {
  /// The release notes carry a `FORCE_UPDATE` line.
  markedByRelease,

  /// The tester is [mandatoryReleasesBehind] or more releases behind.
  tooFarBehind,
}

/// Testers can decline up to 4 releases before an update becomes mandatory.
const int mandatoryReleasesBehind = 5;

/// Decides what to do about [status]. [lastSkippedVersion] is the version the
/// tester last declined with "Later", or null.
///
/// Pure. Rules apply in order:
///
/// 1. Nothing newer than the running build -> [NoAction].
/// 2. The latest release carries `FORCE_UPDATE` -> [MandatoryUpdate] with
///    [MandatoryReason.markedByRelease]. Only the latest release's marker
///    counts, and it wins over the behind-count.
/// 3. [mandatoryReleasesBehind] or more releases behind -> [MandatoryUpdate]
///    with [MandatoryReason.tooFarBehind].
/// 4. The latest release is the one already declined -> [NoAction].
/// 5. Otherwise -> [OptionalUpdate].
///
/// Mandatory is checked before the skip, so "Later" can only suppress an
/// optional update. The skip matches the latest version exactly: declining
/// 2.3.0 does not silence 2.4.0.
UpdateAction decideUpdateAction({
  required ReleaseStatus status,
  required String? lastSkippedVersion,
}) {
  final latest = status.latest;
  if (latest == null) return const NoAction();

  if (latest.isMandatory) {
    return MandatoryUpdate(latest, MandatoryReason.markedByRelease);
  }
  if (status.releasesBehind >= mandatoryReleasesBehind) {
    return MandatoryUpdate(latest, MandatoryReason.tooFarBehind);
  }

  if (lastSkippedVersion != null && latest.version == lastSkippedVersion) {
    return const NoAction();
  }
  return OptionalUpdate(latest);
}
