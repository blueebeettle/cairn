import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/cairn_card.dart';
import '../../../core/widgets/cairn_glyph.dart';
import '../../../data/providers/onboarding_providers.dart';
import '../../../theme/app_theme.dart';

/// The first-launch tutorial: five short slides, shown once, before the app.
///
/// It introduces Cairn as a whole — what it is, what the five tabs are for,
/// and the quick-capture syntax that nothing else in the app explains until a
/// user stumbles onto it. It deliberately does NOT re-teach each screen. Every
/// screen already has a `FeatureInfoCard` and a permanent `FeatureInfoButton`
/// that own the detail, so the fourth slide points at that "?" pattern instead
/// of repeating what it says, and the two cannot drift apart.
///
/// **Skipping is not partial.** "Skip" and "Get started" both finish the
/// tutorial outright through [OnboardingCompletedNotifier.complete]; there is
/// no "seen some of it" state to resume. And that is the *only* place the
/// flag is written — merely opening this screen writes nothing, so a user who
/// force-quits on slide three sees the tutorial again next launch instead of
/// being marked as done by an app they never got through.
///
/// Built from the app's own pieces — [CairnCard]/[CardChrome], [CairnGlyph]
/// and the theme's tokens — with no onboarding package, in keeping with the
/// deliberately short dependency list.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  /// How many slides there are. The dots, the "Step n of m" label and the
  /// last-slide check all read this rather than each counting the list.
  static const int slideCount = 5;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  bool get _isFirst => _page == 0;
  bool get _isLast => _page == OnboardingScreen.slideCount - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _goTo(_page + 1);
    }
  }

  void _back() {
    if (!_isFirst) _goTo(_page - 1);
  }

  /// Finishes the tutorial. Guarded so a double tap on "Get started" cannot
  /// run the completion twice.
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await ref.read(onboardingCompletedProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      // The tutorial is the root screen, so the system back gesture would
      // otherwise leave the app from any slide. Step back a slide instead;
      // only on the first slide does back mean "leave".
      canPop: _isFirst,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Persistent, top right, outside the PageView so it does not
              // slide away with the page it appears on.
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onSurfaceVariant,
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('Skip'),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: const [
                    _WelcomeSlide(),
                    _TodayFocusSlide(),
                    _TasksSlide(),
                    _HabitsSlide(),
                    _StatsSlide(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label:
                            'Step ${_page + 1} of ${OnboardingScreen.slideCount}',
                        excludeSemantics: true,
                        child: _PageDots(
                          count: OnboardingScreen.slideCount,
                          index: _page,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // Same footprint whether or not Back shows, so the
                          // primary button does not jump on the first slide.
                          Visibility(
                            visible: !_isFirst,
                            maintainSize: true,
                            maintainAnimation: true,
                            maintainState: true,
                            child: TextButton(
                              onPressed: _back,
                              child: const Text('Back'),
                            ),
                          ),
                          const Spacer(),
                          // Scales its label down rather than overflowing:
                          // "Get started" at a 200% font scale is wider than
                          // the room left beside Back on a 360dp phone.
                          Flexible(
                            child: FilledButton(
                              onPressed: _next,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _isLast ? 'Get started' : 'Next',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: colors.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slides
// ─────────────────────────────────────────────────────────────────────────────

/// The shared shape of every slide: a visual, a heading, a plain paragraph
/// and optionally more.
///
/// Scrolls when it has to. The slides are short at normal text size, but at a
/// 200% font scale on a small phone the tasks slide is taller than the space
/// between the Skip row and the buttons, and clipping the syntax examples
/// would defeat the point of that slide.
class _SlideFrame extends StatelessWidget {
  const _SlideFrame({
    required this.visual,
    required this.title,
    required this.body,
    this.extra,
  });

  final Widget visual;
  final String title;
  final String body;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: ConstrainedBox(
            // Centres a short slide vertically; a tall one just scrolls.
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - 16),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: visual),
                    const SizedBox(height: 28),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: textTheme.headlineSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: tokens.textSecondary),
                    ),
                    if (extra != null) ...[
                      const SizedBox(height: 18),
                      extra!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Slide 1 — what Cairn is.
class _WelcomeSlide extends StatelessWidget {
  const _WelcomeSlide();

  @override
  Widget build(BuildContext context) {
    return const _SlideFrame(
      // The full four-stone cairn with its marker: the same glyph Today's
      // "Grow your cairn" card grows, shown finished.
      visual: ExcludeSemantics(
        child: CairnGlyph(stoneCount: 4, scale: 1.4),
      ),
      title: 'Welcome to Cairn',
      body: 'Cairn keeps your focus timer, your tasks and your habits in one '
          'place, so you can see how they add up. This is a quick tour of '
          'where things are. It takes about a minute, and you can skip it '
          'whenever you like.',
    );
  }
}

/// Slide 2 — the two tabs you live in.
class _TodayFocusSlide extends StatelessWidget {
  const _TodayFocusSlide();

  @override
  Widget build(BuildContext context) {
    return const _SlideFrame(
      visual: _TabBadges(
        badges: [
          _TabBadge(icon: Icons.calendar_today_rounded, label: 'Today'),
          _TabBadge(icon: Icons.timer_rounded, label: 'Focus'),
        ],
      ),
      title: 'Today and Focus',
      body: 'Today is your home screen: the focus you have logged, the tasks '
          'you planned and the habits you meant to keep, all on one page.\n\n'
          'Focus is the timer. Pick Pomodoro for a set length, or Open-ended '
          'to count up with no finish line. Only sessions you let finish are '
          'counted.',
    );
  }
}

/// Slide 3 — the quick-capture syntax.
///
/// The one thing here that is genuinely easy to miss: typing a date, a
/// priority, a tag or an estimate straight into a task's title. The rows are
/// the real syntax `TaskParser` accepts — see the Quick Capture sheet's own
/// legend — and say `#tag` because that is what `#` produces: a tag, not a
/// project. A task's project is chosen separately in the sheet.
class _TasksSlide extends StatelessWidget {
  const _TasksSlide();

  @override
  Widget build(BuildContext context) {
    return const _SlideFrame(
      visual: _TabBadges(
        badges: [
          _TabBadge(icon: Icons.check_circle_rounded, label: 'Tasks'),
        ],
      ),
      title: 'Capture a task in one line',
      body: 'Tap + on the Tasks tab and just type. Drop these into the title '
          'anywhere and Cairn picks them out for you:',
      extra: _SyntaxCard(),
    );
  }
}

/// Slide 4 — streaks, and where to find help.
class _HabitsSlide extends StatelessWidget {
  const _HabitsSlide();

  @override
  Widget build(BuildContext context) {
    return const _SlideFrame(
      visual: _TabBadges(
        badges: [
          _TabBadge(icon: Icons.local_fire_department_rounded, label: 'Habits'),
        ],
      ),
      title: 'Habits keep a streak',
      body: 'Check a habit off each day it is due and Cairn counts the chain '
          'of days in a row. Only days a habit is actually scheduled count, '
          'so a Monday habit is never missed on a Tuesday.',
      extra: _HelpButtonCard(),
    );
  }
}

/// Slide 5 — Stats, then out.
class _StatsSlide extends StatelessWidget {
  const _StatsSlide();

  @override
  Widget build(BuildContext context) {
    return const _SlideFrame(
      visual: _TabBadges(
        badges: [
          _TabBadge(icon: Icons.bar_chart_rounded, label: 'Stats'),
        ],
      ),
      title: 'See how it adds up',
      body: 'Stats shows your focused time, how often you finish the '
          'sessions you start, your streaks and a year of activity. It only '
          'counts sessions you finished and days you actually did the '
          'thing, so the numbers stay honest.',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pieces
// ─────────────────────────────────────────────────────────────────────────────

/// A row of tab badges. A `Wrap`, so two of them still fit at a 200% font
/// scale on a narrow phone.
class _TabBadges extends StatelessWidget {
  const _TabBadges({required this.badges});

  final List<_TabBadge> badges;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 28,
      runSpacing: 12,
      children: badges,
    );
  }
}

/// One tab's icon, drawn the way the navigation bar draws it, with its name.
///
/// The icons are the navigation bar's own selected icons, so the tutorial and
/// the bar it is describing read as the same thing.
class _TabBadge extends StatelessWidget {
  const _TabBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '$label tab',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: colors.onSecondaryContainer),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: colors.onSurface,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The quick-capture examples: a token, and what typing it does.
class _SyntaxCard extends StatelessWidget {
  const _SyntaxCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return CairnCard(
      color: CardChrome.panel(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SyntaxRow(
            token: 'fri 5pm',
            meaning: 'A due date and time. "tomorrow" and "sep 18" work too.',
          ),
          const SizedBox(height: 12),
          const _SyntaxRow(
            token: '!p1 – !p4',
            meaning: 'Priority. 1 is the highest.',
          ),
          const SizedBox(height: 12),
          const _SyntaxRow(
            token: '#work',
            meaning: 'A tag. Add as many as you like.',
          ),
          const SizedBox(height: 12),
          const _SyntaxRow(
            token: '~2p',
            meaning: 'How many focus sessions you expect it to take.',
          ),
          const SizedBox(height: 14),
          Text(
            'So "submit report fri 5pm !p1 #work ~2p" becomes a task called '
            '"submit report", due Friday at 5pm, top priority.',
            style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SyntaxRow extends StatelessWidget {
  const _SyntaxRow({required this.token, required this.meaning});

  final String token;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        token,
        style: textTheme.labelLarge?.copyWith(
          color: colors.onSecondaryContainer,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
    final text = Text(
      meaning,
      style: textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
    );

    // How much the user has scaled text up, from what 14px actually becomes —
    // right for a non-linear scaler as well as a linear one.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;

    // Large text: the token and its explanation no longer fit side by side, so
    // the explanation goes underneath rather than overflowing.
    if (scale > _stackAbove) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [pill, const SizedBox(height: 6), text],
      );
    }

    // Otherwise a two-column table: every token in the same-width column, so
    // the explanations line up. Left to wrap freely, a short explanation sat
    // beside its token and a long one dropped below it, and the four rows
    // looked ragged. The column grows with the text scale so the widest token
    // (`!p1 – !p4`) still fits it.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _tokenColumnWidth * scale.clamp(1.0, _stackAbove),
          child: Align(alignment: Alignment.centerLeft, child: pill),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: text,
          ),
        ),
      ],
    );
  }

  /// Width of the token column at normal text size — room for `!p1 – !p4`.
  static const double _tokenColumnWidth = 96;

  /// Past this text scale the two columns give way to a stacked layout.
  static const double _stackAbove = 1.3;
}

/// Points at the "?" button rather than repeating what it opens.
class _HelpButtonCard extends StatelessWidget {
  const _HelpButtonCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return CairnCard(
      color: CardChrome.panel(context),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline_rounded, size: 26, color: colors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Every screen has a ? button in its top bar. Tap it any time '
              'for a plain explanation of how that screen works.',
              style: textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The progress dots under the slides. The current one stretches into a pill.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? colors.primary : colors.outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
