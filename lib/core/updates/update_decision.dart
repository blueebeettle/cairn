import 'update_checker.dart';

/// What the UI should do about a [ReleaseStatus], given what the tester
/// last explicitly declined.
///
/// Three outcomes, and only three: nothing to do, an optional offer the tester
/// can defer, or a mandatory update the tester cannot dismiss or work around.
/// All of the "what should happen" lives in [decideUpdateAction]; the dialogs
/// that act on the answer are presentation only.
sealed class UpdateAction {
  const UpdateAction();
}

/// Nothing newer, or the only newer release is the exact one already
/// declined and neither the mandatory marker nor the behind-count rule
/// overrides that.
class NoAction extends UpdateAction {
  const NoAction();
}

/// Offer [release]; the tester may dismiss this.
class OptionalUpdate extends UpdateAction {
  const OptionalUpdate(this.release);

  final ReleaseInfo release;
}

/// [release] must be installed before the tester can keep using the
/// dialog's dismiss affordances — see [reason] for why.
class MandatoryUpdate extends UpdateAction {
  const MandatoryUpdate(this.release, this.reason);

  final ReleaseInfo release;
  final MandatoryReason reason;
}

/// Why an update is mandatory — the dialog says so out loud, so a tester never
/// meets a blocking dialog with no explanation.
enum MandatoryReason {
  /// The release's own notes carry the `FORCE_UPDATE` line: a deliberate act
  /// by whoever published it, for a fix that cannot wait.
  markedByRelease,

  /// The tester has let [mandatoryReleasesBehind] or more releases go by.
  tooFarBehind,
}

/// How many releases behind makes the latest one mandatory.
///
/// Five, so four is the most a tester gets to decline in a row before the
/// fifth stops being optional. Without a ceiling, "Later" would let a tester
/// drift arbitrarily far from the build everyone else is on.
const int mandatoryReleasesBehind = 5;

/// Decides what to do about [status], given [lastSkippedVersion] — whatever
/// the tester last tapped "Later" on (null if never, or if they have since
/// updated).
///
/// Pure on purpose: no I/O, no context, nothing but its two arguments, so the
/// whole policy can be read, and tested against a table, in one place.
///
/// In order:
///
/// 1. Nothing newer than the running build -> [NoAction].
/// 2. The latest release carries the `FORCE_UPDATE` marker ->
///    [MandatoryUpdate] / [MandatoryReason.markedByRelease]. Only the *latest*
///    release's marker counts: the update on offer is the latest one, so it is
///    the one whose notes say whether it is optional. The marker overrides how
///    far behind the tester is — one release behind is enough.
/// 3. [mandatoryReleasesBehind] or more releases newer than the running build
///    -> [MandatoryUpdate] / [MandatoryReason.tooFarBehind].
/// 4. The latest release is the one already declined -> [NoAction].
/// 5. Otherwise -> [OptionalUpdate] for the latest.
///
/// The order is the whole point. Mandatory is checked before the skip, so a
/// "Later" can only ever suppress an [OptionalUpdate] — it never lets a
/// tester sit on a release that has since become unskippable. And when both
/// mandatory triggers apply, the marker is reported: it is the more specific,
/// intentional reason, where "too far behind" is just arithmetic.
///
/// The skip is matched against the latest release's version exactly, not "any
/// release at or below it". Declining 2.3.0 stays quiet until something newer
/// than 2.3.0 is published; it does not silence 2.4.0.
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
