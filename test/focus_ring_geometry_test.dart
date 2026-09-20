import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/focus_ring.dart';
import 'package:habit_tracker/theme/app_theme.dart';

void main() {
  Widget buildTestRing({
    required double screenWidth,
    required double widthFactor,
    double progress = 0.5,
    String figure = '25:00',
    String? label = 'PLANNED',
    bool isPaused = false,
    bool drawProgress = true,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: Size(screenWidth, 800)),
        child: Scaffold(
          body: Center(
            child: FocusRing(
              widthFactor: widthFactor,
              progress: progress,
              figure: figure,
              label: label,
              isPaused: isPaused,
              drawProgress: drawProgress,
            ),
          ),
        ),
      ),
    );
  }

  group('FocusRing Geometry and Clamps', () {
    testWidgets('360dp width screen: Timer screen (factor 0.60)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestRing(screenWidth: 360, widthFactor: 0.60),
      );
      await tester.pump();

      // ringBox = (360 * 0.60).clamp(200.0, 260.0) = 216.0
      final sizedBoxFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.width == 216.0 &&
            widget.height == 216.0,
      );
      expect(sizedBoxFinder, findsOneWidget);

      final text = tester.widget<Text>(find.text('25:00'));
      // figure = (360 * 0.13).clamp(44.0, 56.0) = 46.8
      expect(text.style?.fontSize, closeTo(46.8, 0.01));
      expect(text.style?.height, 1.0);
    });

    testWidgets('360dp width screen: Today screen (factor 0.58)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestRing(screenWidth: 360, widthFactor: 0.58),
      );
      await tester.pump();

      // ringBox = (360 * 0.58).clamp(200.0, 260.0) ≈ 208.8
      final sizedBoxFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.width != null &&
            (widget.width! - 208.8).abs() < 0.01 &&
            widget.height != null &&
            (widget.height! - 208.8).abs() < 0.01,
      );
      expect(sizedBoxFinder, findsOneWidget);
    });

    testWidgets('412dp width screen: Timer screen (factor 0.60)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestRing(screenWidth: 412, widthFactor: 0.60),
      );
      await tester.pump();

      // ringBox = (412 * 0.60).clamp(200.0, 260.0) = 247.2
      final sizedBoxFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.width != null &&
            (widget.width! - 247.2).abs() < 0.01 &&
            widget.height != null &&
            (widget.height! - 247.2).abs() < 0.01,
      );
      expect(sizedBoxFinder, findsOneWidget);

      final text = tester.widget<Text>(find.text('25:00'));
      // figure = (412 * 0.13).clamp(44.0, 56.0) = 53.56
      expect(text.style?.fontSize, closeTo(53.56, 0.01));
    });

    testWidgets('412dp width screen: Today screen (factor 0.58)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestRing(screenWidth: 412, widthFactor: 0.58),
      );
      await tester.pump();

      // ringBox = (412 * 0.58).clamp(200.0, 260.0) ≈ 238.96
      final sizedBoxFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.width != null &&
            (widget.width! - 238.96).abs() < 0.01 &&
            widget.height != null &&
            (widget.height! - 238.96).abs() < 0.01,
      );
      expect(sizedBoxFinder, findsOneWidget);
    });

    testWidgets('Desktop / Large screen (1200dp width): clamp holds at 260.0 dp',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestRing(screenWidth: 1200, widthFactor: 0.60),
      );
      await tester.pump();

      // ringBox = (1200 * 0.60).clamp(200.0, 260.0) = 260.0
      final sizedBoxFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.width == 260.0 &&
            widget.height == 260.0,
      );
      expect(sizedBoxFinder, findsOneWidget);

      final text = tester.widget<Text>(find.text('25:00'));
      // figure = (1200 * 0.13).clamp(44.0, 56.0) = 56.0
      expect(text.style?.fontSize, 56.0);
    });

    testWidgets('Small screen (250dp width): clamp holds at 200.0 dp',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestRing(screenWidth: 250, widthFactor: 0.60),
      );
      await tester.pump();

      // ringBox = (250 * 0.60).clamp(200.0, 260.0) = 200.0
      final sizedBoxFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.width == 200.0 &&
            widget.height == 200.0,
      );
      expect(sizedBoxFinder, findsOneWidget);

      final text = tester.widget<Text>(find.text('25:00'));
      // figure = (250 * 0.13).clamp(44.0, 56.0) = 44.0
      expect(text.style?.fontSize, 44.0);
    });
  });
}
