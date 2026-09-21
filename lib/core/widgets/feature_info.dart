import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/database_provider.dart';
import '../../theme/app_theme.dart';

/// One explained section inside a feature's help sheet.
class FeatureInfoSection {
  const FeatureInfoSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

/// What a screen's feature is and how to use it.
///
/// Surfaced twice, deliberately: once as a [FeatureInfoCard] the first time
/// someone lands on the screen (so a new user cannot miss it), and
/// permanently behind a [FeatureInfoButton] in the app bar (so anyone can go
/// back for the detail later without the card nagging forever).
class FeatureInfo {
  const FeatureInfo({
    required this.id,
    required this.title,
    required this.summary,
    required this.sections,
  });

  /// Stable key for the "card dismissed" flag. Changing it re-shows the card.
  final String id;

  final String title;

  /// One or two plain sentences for the inline card.
  final String summary;

  /// The full explanation shown in the sheet.
  final List<FeatureInfoSection> sections;

  String get dismissedSettingsKey => 'info_card_dismissed_$id';
}

/// Opens the full explanation for [info].
Future<void> showFeatureInfoSheet(BuildContext context, FeatureInfo info) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final textTheme = Theme.of(ctx).textTheme;
      final colors = ctx.colors;
      final tokens = ctx.tokens;

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info.title,
                  style: textTheme.headlineSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(info.summary, style: textTheme.bodyLarge),
                const SizedBox(height: 20),
                for (final section in info.sections) ...[
                  Text(
                    section.heading,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    section.body,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// App-bar button that opens [info]'s explanation. Always available.
class FeatureInfoButton extends StatelessWidget {
  const FeatureInfoButton({super.key, required this.info});

  final FeatureInfo info;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'About ${info.title}',
      // Explicit floor: the ambient visual density renders an unconstrained
      // IconButton at 44dp here, under the 48dp accessibility minimum the
      // TalkBack audit enforces.
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(Icons.help_outline_rounded),
      onPressed: () => showFeatureInfoSheet(context, info),
    );
  }
}

/// Inline explainer shown until the user dismisses it.
///
/// Renders nothing at all once dismissed, and renders nothing while the
/// stored flag is still loading — a card that appears a frame late and
/// shoves the screen down is worse than one that never flashes.
class FeatureInfoCard extends ConsumerStatefulWidget {
  const FeatureInfoCard({super.key, required this.info, this.padding});

  final FeatureInfo info;

  /// Outer padding. Defaults to a standalone inset; screens whose own list
  /// already pads horizontally should pass one with no horizontal component
  /// so the card lines up with the content rather than sitting inside it.
  final EdgeInsetsGeometry? padding;

  @override
  ConsumerState<FeatureInfoCard> createState() => _FeatureInfoCardState();
}

class _FeatureInfoCardState extends ConsumerState<FeatureInfoCard> {
  /// null = still loading, true = show, false = dismissed.
  bool? _visible;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadDismissed);
  }

  Future<void> _loadDismissed() async {
    var dismissed = true;
    try {
      final stored = await ref
          .read(settingsRepositoryProvider)
          .getInt(widget.info.dismissedSettingsKey);
      dismissed = stored == 1;
    } catch (_) {
      // Unreadable settings: stay hidden rather than show a card that
      // cannot be dismissed permanently.
      dismissed = true;
    }
    if (mounted) setState(() => _visible = !dismissed);
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setInt(widget.info.dismissedSettingsKey, 1);
    } catch (_) {
      // Worst case it returns next launch; not worth surfacing.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_visible != true) return const SizedBox.shrink();

    // At very large text scales this card is the first thing that should give
    // way. Screens like Tasks carry a fixed header — filter chips and tabs —
    // that already fills the viewport at 200%, so several lines of optional
    // explanation on top of it cannot fit however it is laid out. The
    // app-bar button carries exactly the same text and stays at every scale,
    // so nothing is actually lost; the onboarding nicety just steps aside
    // for the content it is describing.
    final scaledBodySize = MediaQuery.textScalerOf(context).scale(14);
    if (scaledBodySize > 14 * 1.5) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;
    final tokens = context.tokens;

    return Padding(
      padding: widget.padding ?? const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Material(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showFeatureInfoSheet(context, widget.info),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.lineSoft),
            ),
            padding: const EdgeInsets.only(left: 12),
            // A slim one-line banner rather than a block with its own
            // heading and button. The whole strip opens the full
            // explanation, so it stays a single row tall and pushes the
            // screen's real content down as little as possible.
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 20, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.info.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall
                        ?.copyWith(color: tokens.textSecondary),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  iconSize: 18,
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _dismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
