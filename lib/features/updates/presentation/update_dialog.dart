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

/// How an optional [UpdateDialog] was closed by a button. A pop with no value
/// (barrier tap or back button) is treated as "Later"; see [_UpdateDialogState].
enum _DialogResult { later, closed }

/// Shows the dialog for [action]: nothing for [NoAction], a dismissible dialog
/// for [OptionalUpdate], and one that can't be dismissed for [MandatoryUpdate].
///
/// Shared by the launch check (`NavigationShell`) and the Settings tile.
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

/// The update dialog: the offer, then the download, checksum check and installer
/// hand-off, all in place.
///
/// A null [mandatoryReason] means optional. A mandatory dialog has no "Later",
/// is wrapped in `PopScope(canPop: false)`, and says why it's required.
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

  /// False when the release has no APK for this device: retrying would reuse the
  /// same stale release list, and only the next launch's check can see an upload
  /// that has since finished.
  bool _canRetry = true;

  /// The verified APK, kept after the installer launches so "Install again"
  /// doesn't download 25-70MB twice.
  File? _verifiedApk;

  UpdateCancelToken? _cancelToken;

  bool get _isMandatory => widget.mandatoryReason != null;
  bool get _busy =>
      _phase == _Phase.downloading ||
      _phase == _Phase.verifying ||
      _phase == _Phase.cancelling;

  @override
  void dispose() {
    // Don't leave a download running after the dialog is torn down.
    _cancelToken?.cancel();
    super.dispose();
  }

  /// "Later": remember the version so launches stay quiet until something newer
  /// is published.
  void _later() {
    unawaited(rememberSkippedUpdateVersion(
      ref.read(settingsRepositoryProvider),
      widget.release.version,
    ));
    Navigator.of(context).pop(_DialogResult.later);
  }

  /// The whole flow: pick the APK for this device, download it with progress,
  /// verify it, hand it to the installer.
  Future<void> _startUpdate() async {
    if (_busy) return;
    final installer = ref.read(updateInstallerProvider);
    final release = widget.release;

    // Tapping Update ends the "just declined" state, even if the update then
    // fails.
    unawaited(clearSkippedUpdateVersion(ref.read(settingsRepositoryProvider)));

    List<String> abis;
    try {
      abis = await ref.read(supportedAbisProvider.future);
    } catch (_) {
      // Unreadable device info shouldn't block the update: an empty list still
      // gets the universal APK.
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
      // A cancel that only took effect when a slow request timed out arrives as
      // a download failure; it isn't one.
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
      // Cancelled just as the download finished: honour it and discard the APK.
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

  /// "Install again": reuse the verified file if it's still there rather than
  /// downloading again.
  Future<void> _installAgain() async {
    final apk = _verifiedApk;
    if (apk == null) return _startUpdate();
    await _launchInstaller(apk);
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    // Stay on "Cancelling" until the download stops (it checks between chunks).
    // Returning to the offer now would let a second Update tap write to the file
    // the first is still closing.
    setState(() => _phase = _Phase.cancelling);
  }

  /// Back to the offer, for a mandatory update too: cancelling isn't a way past
  /// the dialog.
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

  /// Plain language only, never the exception text.
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
      // Mandatory: never poppable. Optional: poppable except mid-download, where
      // a stray tap outside would orphan the transfer.
      canPop: !_isMandatory && !_busy,
      onPopInvokedWithResult: (didPop, result) {
        // An optional offer dismissed without a button (barrier tap or back)
        // counts as "Later", or it would reappear on every launch. Button pops
        // carry a result and are handled by the button.
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
          if (!_isMandatory)
            TextButton(onPressed: _later, child: const Text('Later')),
          FilledButton(onPressed: _startUpdate, child: const Text('Update')),
        ];
      case _Phase.downloading:
        return [TextButton(onPressed: _cancelDownload, child: const Text('Cancel'))];
      case _Phase.verifying:
      case _Phase.cancelling:
        // No actions: hashing can't be interrupted, and a cancel is in flight.
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
