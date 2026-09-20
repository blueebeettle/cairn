import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';

void main() {
  setUpAll(() {
    // google_fonts downloads font files over HTTP the first time a face is
    // used. There is no network under the test binding, and the pending
    // request leaves work queued that keeps the tree from going idle. Falling
    // back to the bundled system font keeps the test hermetic.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('FocusStackApp renders NavigationShell and Today screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Without this override the test reaches eventsRepositoryProvider,
          // which builds a real AppDatabase and opens a SQLite file through
          // drift_flutter. That never completes under the test binding, so
          // todayEventsStreamProvider stays in its loading state and the Today
          // screen renders a CircularProgressIndicator — an animation that by
          // definition never ends, which is what made pumpAndSettle time out.
          //
          // Overriding the stream keeps the widget test about widgets. The
          // database belongs in its own integration test with an in-memory
          // NativeDatabase.
          todayEventsStreamProvider.overrideWith(
            (ref) => Stream<List<Event>>.value(const []),
          ),
        ],
        child: const FocusStackApp(),
      ),
    );

    // pump(), not pumpAndSettle(). Settling waits for the frame queue to drain,
    // so any indeterminate progress indicator anywhere on screen makes it
    // impossible to satisfy. Two frames is enough for the stream's first value
    // to arrive and the tree to rebuild against it.
    await tester.pump();
    await tester.pump();

    // 'Today' appears twice — the Today screen's AppBar and the nav label.
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);

    expect(find.text('Ready to focus', skipOffstage: false), findsOneWidget);
  });

  testWidgets('the empty event stream renders the Today screen, not a spinner',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayEventsStreamProvider.overrideWith(
            (ref) => Stream<List<Event>>.value(const []),
          ),
        ],
        child: const FocusStackApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Guards the regression directly: if the screen is stuck loading again,
    // this fails with a clear message instead of a six-second timeout.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
