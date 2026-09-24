import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/cairn_glyph.dart';
import '../../../data/providers/habit_providers.dart';
import '../../../theme/app_theme.dart';
import 'widgets/habit_milestone.dart';

/// Full-screen celebration for a habit's streak crossing a
/// `MilestoneThresholds` round number (§4).
///
/// Opened by `NavigationShell` when `milestoneCelebrationControllerProvider`
/// reports a pending `habitId`/`streak` pair — see that controller for the
/// trigger and "celebrated once" bookkeeping. Nothing here decides *whether*
/// to celebrate, only how.
///
/// Match: `claude-outputs/designs/Milestone.dc.html` /
/// `Milestone.Dark.dc.html`, with two deliberate departures from those
/// boards:
///  * the primary/secondary actions are swapped — "Keep going" primary,
///    "Share your cairn" secondary — per the brief this was built from,
///    rather than the mockup's share-first pair.
///  * the personal-best line only appears when this streak is actually the
///    habit's best (`current >= longest`). A habit that broke a longer
///    streak and is now celebrating a fresh 30-day run has not "never gone
///    this far before" — that claim would be false the moment someone who
///    once ran 100 days sees it at day 30.
class MilestoneCelebrationScreen extends ConsumerStatefulWidget {
  const MilestoneCelebrationScreen({
    super.key,
    required this.habitId,
    required this.streak,
  });

  final String habitId;

  /// The threshold just crossed — the celebration's headline number until
  /// the live snapshot resolves, and its fallback if that snapshot never
  /// loads (an archived-mid-celebration edge case).
  final int streak;

  static Future<void> open(
    BuildContext context, {
    required String habitId,
    required int streak,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            MilestoneCelebrationScreen(habitId: habitId, streak: streak),
      ),
    );
  }

  @override
  ConsumerState<MilestoneCelebrationScreen> createState() =>
      _MilestoneCelebrationScreenState();
}

class _MilestoneCelebrationScreenState
    extends ConsumerState<MilestoneCelebrationScreen> {
  final _cardBoundaryKey = GlobalKey();
  final _shareButtonKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final file =
          File('${tempDir.path}/cairn-milestone-${widget.streak}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

      // Anchors the iPad share popover to the button that opened it, the
      // same way `BackupStorage.shareBackupFile`'s callers do.
      final box =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final origin =
          box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(file.path,
                name: 'cairn-milestone.png', mimeType: 'image/png'),
          ],
          text: '${widget.streak}-day streak on Cairn.',
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      // Sharing is a bonus on top of the celebration, not the point of the
      // screen — no share target, a refused temp-file write, or (in tests) no
      // platform channel at all must never block "Keep going" from working.
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(habitSnapshotProvider(widget.habitId));
    final colors = context.colors;
    final isDark = colors.brightness == Brightness.dark;

    // The mockup's full-bleed background is a solid deep purple in light
    // mode but the app's own near-black ground in dark mode — not literally
    // `colorScheme.primary` in either theme (that token is a light lavender
    // in dark mode, which would wash out the card and the confetti rather
    // than sit behind them). `tertiary` is the exact light-mode token for
    // that purple (`#40128B`), and dark mode is already that dark by
    // default, so it reuses `surface` instead of inventing a second one.
    final background = isDark ? colors.surface : colors.tertiary;
    final onBackground = isDark ? colors.onSurface : colors.onTertiary;

    final snapshot = snapshotAsync.value;
    final currentStreak = snapshot?.streaks.current ?? widget.streak;
    final isPersonalBest = snapshot == null ||
        snapshot.streaks.current >= snapshot.streaks.longest;
    final freezesRemaining =
        snapshot == null ? null : habitFreezesRemaining(snapshot);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          const Positioned.fill(child: _ConfettiField()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: RepaintBoundary(
                        key: _cardBoundaryKey,
                        child: _CelebrationCard(
                          streak: currentStreak,
                          isPersonalBest: isPersonalBest,
                          sharing: _sharing,
                          shareButtonKey: _shareButtonKey,
                          onKeepGoing: () => Navigator.of(context).pop(),
                          onShare: _share,
                        ),
                      ),
                    ),
                  ),
                ),
                if (freezesRemaining != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _FreezeFooterChip(
                      remaining: freezesRemaining,
                      color: onBackground,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({
    required this.streak,
    required this.isPersonalBest,
    required this.sharing,
    required this.shareButtonKey,
    required this.onKeepGoing,
    required this.onShare,
  });

  final int streak;
  final bool isPersonalBest;
  final bool sharing;
  final Key shareButtonKey;
  final VoidCallback onKeepGoing;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final isDark = colors.brightness == Brightness.dark;
    final accent = MilestoneChrome.accent(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainer : colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: isDark ? Border.all(color: colors.outline) : null,
        boxShadow: [
          // Same CSS-blur-to-Flutter-blurRadius conversion as
          // `MilestoneChrome.glow` and `CairnGlyph._cssBlur`: a CSS blur of r
          // is a Flutter `blurRadius` of `r * 0.866`. The mockup's card
          // shadow is `0 30px 60px`.
          BoxShadow(
            color: colors.scrim.withValues(alpha: isDark ? 0.55 : 0.28),
            blurRadius: 60 * 0.866,
            offset: const Offset(0, 30),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: 130,
              height: 146,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  // A big soft backdrop glow behind the whole glyph — distinct
                  // from `CairnGlyph`'s own small marker halo, and reusing
                  // §5's milestone accent rather than a new color.
                  Positioned(
                    bottom: 6,
                    child: Container(
                      width: 118,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: isDark ? 0.45 : 0.5),
                            accent.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const CairnGlyph(stoneCount: 4, scale: 1.7),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'MILESTONE',
            textAlign: TextAlign.center,
            style: textTheme.labelSmall?.copyWith(
              color: tokens.warning,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$streak',
            textAlign: TextAlign.center,
            style: statFigure(context).copyWith(
              fontSize: 52,
              fontWeight: FontWeight.w800,
              height: 1.0,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'day streak',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: colors.onSurface),
          ),
          const SizedBox(height: 14),
          Text(
            isPersonalBest
                ? "You've never gone this far before. That's who you are now."
                : "$streak days in, and still going strong.",
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: 22),
          Container(height: 1, color: colors.outline),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onKeepGoing,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'Keep going',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const SizedBox(height: 2),
          TextButton(
            key: shareButtonKey,
            onPressed: sharing ? null : onShare,
            style: TextButton.styleFrom(
              foregroundColor: tokens.textMuted,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: sharing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.textMuted,
                    ),
                  )
                : const Text(
                    'Share your cairn',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
          ),
        ],
      ),
    );
  }
}

/// "N streak freezes in your pocket, saved for a rough day" — the single-
/// habit answer to the Habits-list `FreezesChip`'s total.
class _FreezeFooterChip extends StatelessWidget {
  const _FreezeFooterChip({required this.remaining, required this.color});

  final int remaining;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = remaining == 1
        ? '1 streak freeze in your pocket, saved for a rough day'
        : '$remaining streak freezes in your pocket, saved for a rough day';

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ac_unit_rounded, size: 14, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Decorative confetti flecks scattered above and below the card.
///
/// A fixed, designed scatter lifted from the mockup's layout (fractional, so
/// it holds up across phone sizes) rather than randomly generated — the
/// screen should look the same on every celebration, not roll new confetti
/// each time.
class _ConfettiField extends StatelessWidget {
  const _ConfettiField();

  static const List<_Fleck> _flecks = [
    _Fleck(dx: 0.123, dy: 0.083, size: 10, seriesIndex: 0),
    _Fleck(dx: 0.795, dy: 0.142, size: 8, seriesIndex: 3, rotation: 20),
    _Fleck(dx: 0.103, dy: 0.178, size: 7, seriesIndex: 2, rotation: 30, tall: true),
    _Fleck(dx: 0.513, dy: 0.113, size: 9, seriesIndex: 0),
    _Fleck(dx: 0.846, dy: 0.237, size: 9, seriesIndex: 4),
    _Fleck(dx: 0.051, dy: 0.190, size: 8, seriesIndex: 0),
    _Fleck(dx: 0.128, dy: 0.800, size: 8, seriesIndex: 0),
    _Fleck(dx: 0.846, dy: 0.850, size: 10, seriesIndex: 3),
    _Fleck(dx: 0.821, dy: 0.760, size: 7, seriesIndex: 2),
  ];

  @override
  Widget build(BuildContext context) {
    final series = context.tokens.series;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            for (final f in _flecks)
              Positioned(
                left: f.dx * constraints.maxWidth - f.size / 2,
                top: f.dy * constraints.maxHeight -
                    (f.tall ? f.size : f.size / 2),
                child: Transform.rotate(
                  angle: f.rotation * math.pi / 180,
                  child: Container(
                    width: f.size,
                    height: f.tall ? f.size * 2 : f.size,
                    decoration: BoxDecoration(
                      color: series[f.seriesIndex % series.length],
                      borderRadius: BorderRadius.circular(f.size / 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Fleck {
  const _Fleck({
    required this.dx,
    required this.dy,
    required this.size,
    required this.seriesIndex,
    this.rotation = 0,
    this.tall = false,
  });

  /// Fractional position within the screen, 0-1.
  final double dx;
  final double dy;
  final double size;
  final int seriesIndex;
  final double rotation;
  final bool tall;
}
