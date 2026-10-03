import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/updates/apk_asset_matcher.dart';
import '../../../core/updates/update_checker.dart';
import '../../../core/updates/update_decision.dart';
import '../../../core/updates/update_installer.dart';
import '../../../data/providers/database_provider.dart';
import '../../../data/providers/update_providers.dart';
import '../../../theme/app_theme.dart';

/// How an optional [UpdateDialog] was closed, when it was closed by a button.
///
/// A pop that carries no value — the barrier tap or the system back button — is
/// the third way out, and is treated as "Later" (see [_UpdateDialogState]).
enum _DialogResult { later, closed }

/// Shows the dialog for [action]: nothing for [NoAction], a normal dismissible
/// dialog for [OptionalUpdate], and for [MandatoryUpdate] one that cannot be
/// dismissed at all.
///
/// Shared by the launch-time check (`NavigationShell`) and the Settings
/// button, so a manual check can never offer a bypassable dialog where the
/// automatic one would have forced the update. Everything about *which* dialog
/// comes from [action]; this file is presentation only.
Future<void> showUpdateDialog(BuildContext context, UpdateAction action) async {
  switch (action) {
    case NoAction():
      return;
    case OptionalUpdate(:final release):
      await showDialog<_DialogResult>(
        context: context,
        builder: (_) => UpdateDialog(release: release),
      );
    case MandatoryUpdate(:final release, :final reason):
      await showDialog<void>(
        context: context,
        // Tapping outside must not close it...
        barrierDismissible: false,
        // ...and the back button is stopped inside, by UpdateDialog's PopScope.
        builder: (_) => UpdateDialog(release: release, mandatoryReason: reason),
      );
  }
}

enum _Phase { offer, downloading, verifying, cancelling, launched, failed }

/// The update dialog: the offer, then — in place, not in a second dialog — the
/// download, the checksum check, and the hand-off to Android's installer.
///
/// [mandatoryReason] null means optional. A mandatory dialog has no "Later",
/// is wrapped in a `PopScope(canPop: false)`, and says why it is required; the
/// only way past it is to update.
class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.release, this.mandatoryReason});

  final ReleaseInfo release;
  final MandatoryReason? mandatoryReason;

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  _Phase _phase = _Phase.offer;
  int _received = 0;
  int? _total;
  String? _error;

  /// Whether the failure on screen can be fixed by trying again. A release
  /// that has no APK for this device cannot: the release list in hand is
  /// already out of date, and it takes a fresh check — the next launch — to
  /// see an upload that finished since.
  bool _canRetry = true;

  /// The verified APK, once there is one. Kept after the installer launches so
  /// "Install again" does not download 25-70MB a second time.
  File? _verifiedApk;

  UpdateCancelToken? _cancelToken;

  bool get _isMandatory => widget.mandatoryReason != null;
  bool get _busy =>
      _phase == _Phase.downloading ||
      _phase == _Phase.verifying ||
      _phase == _Phase.cancelling;

  @override
  void dispose() {
    // A dialog torn down mid-download must not leave the download running.
    _cancelToken?.cancel();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// "Later" on an optional update: remember the version so the next launch
  /// stays quiet until something newer is published.
  void _later() {
    unawaited(rememberSkippedUpdateVersion(
      ref.read(settingsRepositoryProvider),
      widget.release.version,
    ));
    Navigator.of(context).pop(_DialogResult.later);
  }

  /// Runs the whole flow: pick the APK for this device, download it with
  /// progress, verify it, hand it to the installer.
  Future<void> _startUpdate() async {
    if (_busy) return;
    final installer = ref.read(updateInstallerProvider);
    final release = widget.release;

    // The moment they tap Update they are no longer "just declined", whatever
    // happens next — including a failure below.
    unawaited(clearSkippedUpdateVersion(ref.read(settingsRepositoryProvider)));

    List<String> abis;
    try {
      abis = await ref.read(supportedAbisProvider.future);
    } catch (_) {
      // Unreadable device info is not a reason to refuse. An empty list still
      // reaches the universal APK, which runs everywhere.
      abis = const [];
    }
    if (!mounted) return;

    final apk = selectApkAsset(
      supportedAbis: abis,
      version: release.version,
      assets: release.assets,
    );
    if (apk == null) {
      _fail(
        'No compatible build found for your device. The release may still be '
        'uploading — reopen Cairn in a little while to check again.',
        canRetry: false,
      );
      return;
    }

    final token = _cancelToken = UpdateCancelToken();
    setState(() {
      _phase = _Phase.downloading;
      _received = 0;
      _total = null;
      _error = null;
    });

    final File file;
    try {
      file = await installer.downloadAndVerify(
        apk: apk,
        checksumsUrl: release.assets[checksumsAssetName],
        cancel: token,
        onProgress: (received, total) {
          if (!mounted || token.isCancelled) return;
          setState(() {
            _received = received;
            _total = total;
          });
        },
        onVerifying: () {
          if (mounted && !token.isCancelled) {
            setState(() => _phase = _Phase.verifying);
          }
        },
      );
    } on UpdateCancelledException {
      _backToOffer();
      return;
    } on UpdateInstallException catch (e) {
      // A cancel that could only take effect once a slow request timed out
      // surfaces as a download failure; the tester asked for it, so it is not
      // one.
      if (token.isCancelled) {
        _backToOffer();
      } else if (mounted) {
        _fail(_messageFor(e.failure));
      }
      return;
    } catch (_) {
      if (token.isCancelled) {
        _backToOffer();
      } else if (mounted) {
        _fail(_messageFor(UpdateFailure.download));
      }
      return;
    }
    if (!mounted) return;
    if (token.isCancelled) {
      // Cancelled in the instant the download finished: honour it, and do not
      // leave a verified APK behind.
      await installer.discard(file);
      _backToOffer();
      return;
    }

    _verifiedApk = file;
    await _launchInstaller(file);
  }

  Future<void> _launchInstaller(File apk) async {
    try {
      await ref.read(updateInstallerProvider).install(apk);
      if (mounted) setState(() => _phase = _Phase.launched);
    } on UpdateInstallException catch (e) {
      // The installer already deleted the file.
      _verifiedApk = null;
      if (mounted) _fail(_messageFor(e.failure));
    } catch (_) {
      _verifiedApk = null;
      if (mounted) _fail(_messageFor(UpdateFailure.installerNotLaunched));
    }
  }

  /// "Install again", after the system installer has been opened once: reuse
  /// the verified file if it is still there, rather than downloading again.
  Future<void> _installAgain() async {
    final apk = _verifiedApk;
    if (apk == null) return _startUpdate();
    await _launchInstaller(apk);
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    // Held on "Cancelling" until the download actually stops (it checks between
    // chunks). Returning to the offer immediately would let a second tap on
    // Update start a download into the same file the first is still closing.
    setState(() => _phase = _Phase.cancelling);
  }

  /// Back to the offer — for a mandatory update too: cancelling a download is
  /// not a way past the dialog, it just returns to "Update".
  void _backToOffer() {
    if (mounted) setState(() => _phase = _Phase.offer);
  }

  void _fail(String message, {bool canRetry = true}) {
    setState(() {
      _phase = _Phase.failed;
      _error = message;
      _canRetry = canRetry;
    });
  }

  /// Plain language only — never the exception text behind a failure.
  static String _messageFor(UpdateFailure failure) => switch (failure) {
        UpdateFailure.download =>
          "The download didn't finish. Check your connection and try again.",
        UpdateFailure.checksumMismatch =>
          "The download didn't match its published checksum, so it was thrown "
              'away. Try again; if it keeps happening, the release may be damaged.',
        UpdateFailure.checksumUnavailable =>
          "Couldn't verify the download, so it wasn't installed. Try again "
              'in a little while.',
        UpdateFailure.installerNotLaunched =>
          "Couldn't open Android's installer. Try again.",
      };

  // ── Presentation ───────────────────────────────────────────────────────────

  String get _requiredText => switch (widget.mandatoryReason) {
        MandatoryReason.markedByRelease => 'This update is required.',
        MandatoryReason.tooFarBehind =>
          "You've skipped several updates — this one's required.",
        null => '',
      };

  static String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return PopScope(
      // A mandatory dialog can never be popped. An optional one can, except
      // mid-download, where a stray tap outside would orphan the transfer.
      canPop: !_isMandatory && !_busy,
      onPopInvokedWithResult: (didPop, result) {
        // An optional offer dismissed with no button — barrier tap or back — is
        // "Later". Without this, closing it that way would show it again on
        // every launch, which is the nagging "Later" exists to prevent. Button
        // pops carry a result and are handled by the button.
        if (didPop && result == null && !_isMandatory && _phase == _Phase.offer) {
          unawaited(rememberSkippedUpdateVersion(
            ref.read(settingsRepositoryProvider),
            widget.release.version,
          ));
        }
      },
      child: AlertDialog(
        title: Text(_isMandatory ? 'Update required' : 'Update available'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _body(textTheme, tokens),
          ),
        ),
        actions: _actions(),
      ),
    );
  }

  List<Widget> _body(TextTheme textTheme, AppTokens tokens) {
    final version = widget.release.version;
    switch (_phase) {
      case _Phase.offer:
        final notes = releaseNotesForDisplay(widget.release.notes);
        return [
          Text('Cairn $version is available.', style: textTheme.bodyLarge),
          if (_isMandatory) ...[
            const SizedBox(height: 8),
            Text(
              _requiredText,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text("What's new", style: textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              notes,
              style: textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ];
      case _Phase.downloading:
        final total = _total;
        return [
          LinearProgressIndicator(
            value: total == null || total == 0 ? null : _received / total,
            semanticsLabel: 'Download progress',
          ),
          const SizedBox(height: 12),
          Text(
            total == null
                ? 'Downloading… ${_megabytes(_received)} MB'
                : 'Downloading… ${_megabytes(_received)} of ${_megabytes(total)} MB',
            style: textTheme.bodyMedium,
          ),
        ];
      case _Phase.verifying:
        return [
          const LinearProgressIndicator(semanticsLabel: 'Verifying download'),
          const SizedBox(height: 12),
          Text('Verifying download…', style: textTheme.bodyMedium),
        ];
      case _Phase.cancelling:
        return [
          const LinearProgressIndicator(semanticsLabel: 'Cancelling'),
          const SizedBox(height: 12),
          Text('Cancelling…', style: textTheme.bodyMedium),
        ];
      case _Phase.launched:
        return [
          Text(
            'Finish installing Cairn $version in the Android prompt that just '
            'opened. If you backed out of it, tap Install again.',
            style: textTheme.bodyMedium,
          ),
          if (_isMandatory) ...[
            const SizedBox(height: 8),
            Text(
              _requiredText,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ];
      case _Phase.failed:
        return [
          Text(
            _error ?? '',
            style: textTheme.bodyMedium?.copyWith(color: tokens.danger),
          ),
          if (_isMandatory) ...[
            const SizedBox(height: 8),
            Text(
              _requiredText,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ];
    }
  }

  List<Widget>? _actions() {
    switch (_phase) {
      case _Phase.offer:
        return [
          // No "Later" on a mandatory update: only "Update".
          if (!_isMandatory)
            TextButton(onPressed: _later, child: const Text('Later')),
          FilledButton(onPressed: _startUpdate, child: const Text('Update')),
        ];
      case _Phase.downloading:
        return [TextButton(onPressed: _cancelDownload, child: const Text('Cancel'))];
      case _Phase.verifying:
      case _Phase.cancelling:
        // Hashing cannot be interrupted, and a cancel is already in flight.
        return null;
      case _Phase.launched:
        return [
          if (!_isMandatory)
            TextButton(
              onPressed: () => Navigator.of(context).pop(_DialogResult.closed),
              child: const Text('Close'),
            ),
          FilledButton(onPressed: _installAgain, child: const Text('Install again')),
        ];
      case _Phase.failed:
        return [
          if (!_isMandatory)
            TextButton(
              onPressed: () => Navigator.of(context).pop(_DialogResult.closed),
              child: const Text('Close'),
            ),
          if (_canRetry)
            FilledButton(onPressed: _startUpdate, child: const Text('Try again')),
        ];
    }
  }
}
