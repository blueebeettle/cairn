import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/updates/update_decision.dart';
import '../../../data/providers/update_providers.dart';
import '../../../theme/app_theme.dart';
import 'update_dialog.dart';

/// Settings → About → "Check for updates". The caller shows it only where the
/// updater exists (see [updatesSupportedProvider]).
///
/// Uses the same [decideUpdateAction] policy and dialogs as the launch check, so
/// a manual check can't offer a dismissible dialog where the automatic one would
/// force the update. Two differences, since the tester asked this time:
/// * A failure is reported rather than swallowed.
/// * "Later" isn't honoured: no declined version is passed, so a release the
///   tester dismissed is offered again. Mandatory updates never consult it.
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
      // Deliberately no exception text: just that it failed and may be retried.
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

    // No leading icon, to match the rest of the About card.
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
