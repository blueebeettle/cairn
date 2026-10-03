import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/updates/update_decision.dart';
import '../../../data/providers/update_providers.dart';
import '../../../theme/app_theme.dart';
import 'update_dialog.dart';

/// Settings → About → "Check for updates".
///
/// Shown only where the updater exists (see [updatesSupportedProvider]); the
/// caller decides that, so on iOS and macOS there is no row at all rather than
/// one that silently does nothing.
///
/// Runs the same policy as the launch check — [decideUpdateAction] — and opens
/// the same dialogs, so a manual check cannot offer a bypassable dialog where
/// the automatic one would have forced the update.
///
/// Two deliberate differences from the launch check, both because the tester
/// asked this time:
/// * A failure is reported, in plain words, rather than swallowed.
/// * "Later" is not honoured. [decideUpdateAction] is handed no declined
///   version, so a release the tester previously dismissed is offered again
///   instead of the row claiming they are up to date when they are not. This
///   cannot weaken a mandatory update — those never consult the declined
///   version.
class CheckForUpdatesTile extends ConsumerStatefulWidget {
  const CheckForUpdatesTile({super.key});

  @override
  ConsumerState<CheckForUpdatesTile> createState() => _CheckForUpdatesTileState();
}

enum _CheckState { idle, checking, upToDate, updateAvailable, failed }

class _CheckForUpdatesTileState extends ConsumerState<CheckForUpdatesTile> {
  _CheckState _state = _CheckState.idle;
  String? _availableVersion;

  Future<void> _check() async {
    setState(() => _state = _CheckState.checking);

    final UpdateAction action;
    try {
      final currentVersion = await ref.read(installedVersionProvider.future);
      final status = await ref
          .read(updateCheckerProvider)
          .checkForUpdates(currentVersion: currentVersion);
      action = decideUpdateAction(status: status, lastSkippedVersion: null);
    } catch (_) {
      // No exception text, no stack trace: the tester needs to know it did not
      // work and that trying again later is reasonable, nothing more.
      if (mounted) setState(() => _state = _CheckState.failed);
      return;
    }
    if (!mounted) return;

    switch (action) {
      case NoAction():
        setState(() => _state = _CheckState.upToDate);
      case OptionalUpdate(:final release):
      case MandatoryUpdate(:final release):
        setState(() {
          _state = _CheckState.updateAvailable;
          _availableVersion = release.version;
        });
        await showUpdateDialog(context, action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final String subtitle;
    var subtitleColor = tokens.textSecondary;
    switch (_state) {
      case _CheckState.idle:
        subtitle = 'See if a newer version of Cairn is out';
      case _CheckState.checking:
        subtitle = 'Checking…';
      case _CheckState.upToDate:
        subtitle = "You're on the latest version";
      case _CheckState.updateAvailable:
        subtitle = 'Version $_availableVersion is available';
      case _CheckState.failed:
        subtitle = "Couldn't check for updates — try again later";
        subtitleColor = tokens.danger;
    }

    // No leading icon: the rest of the About card has none, and this row sits
    // between them.
    return ListTile(
      title: const Text('Check for updates'),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(color: subtitleColor),
      ),
      trailing: switch (_state) {
        _CheckState.checking => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        _CheckState.upToDate =>
          const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
        _ => const Icon(Icons.chevron_right_rounded),
      },
      onTap: _state == _CheckState.checking ? null : _check,
    );
  }
}
