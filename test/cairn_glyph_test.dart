import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/cairn_glyph.dart';
import 'package:habit_tracker/theme/app_theme.dart';

void main() {
  Widget host(ThemeData theme, Widget child) => MaterialApp(
        theme: theme,
        home: Scaffold(body: Center(child: child)),
      );

  Iterable<BoxDecoration> decorations(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(CairnGlyph),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((box) => box.decoration as BoxDecoration);

  List<Color?> stoneFills(WidgetTester tester) => decorations(tester)
      .map((decoration) => decoration.color)
      .where(CairnGlyph.stoneFills.contains)
      .toList();

  int markers(WidgetTester tester) => decorations(tester)
      .where((decoration) => decoration.shape == BoxShape.circle)
      .length;

  // Built lazily: AppTheme reaches into google_fonts, which needs the test
  // binding to be up, so the themes cannot be constructed at collection time.
  final themes = <String, ThemeData Function()>{
    'light': () => AppTheme.light,
    'dark': () => AppTheme.dark,
  };

  for (final entry in themes.entries) {
    final themeName = entry.key;
    final buildTheme = entry.value;

    group('CairnGlyph ($themeName)', () {
      for (var stones = 0; stones <= 4; stones++) {
        testWidgets('builds with $stones stones', (tester) async {
          await tester.pumpWidget(
            host(buildTheme(), CairnGlyph(stoneCount: stones)),
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(CairnGlyph), findsOneWidget);

          // The box is a fixed size regardless of stone count, so a growing
          // glyph never shifts the layout around it.
          expect(
            tester.getSize(find.byType(CairnGlyph)),
            const Size(CairnGlyph.baseWidth, CairnGlyph.baseHeight),
          );

          // Stones are drawn bottom-up in the fixed palette order.
          expect(
            stoneFills(tester),
            CairnGlyph.stoneFills.take(stones).toList(),
          );

          // The marker only exists once there is a stone to sit above.
          expect(markers(tester), stones == 0 ? 0 : 1);
        });
      }

      testWidgets('hides the marker when showMarker is false', (tester) async {
        await tester.pumpWidget(
          host(buildTheme(), const CairnGlyph(stoneCount: 4)),
        );
        expect(markers(tester), 1);

        await tester.pumpWidget(
          host(
            buildTheme(),
            const CairnGlyph(stoneCount: 4, showMarker: false),
          ),
        );
        expect(markers(tester), 0);
        expect(stoneFills(tester), CairnGlyph.stoneFills);
      });

      testWidgets('scale and opacity apply', (tester) async {
        await tester.pumpWidget(
          host(
            buildTheme(),
            const CairnGlyph(stoneCount: 3, scale: 0.3, opacity: 0.5),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(CairnGlyph)),
          const Size(CairnGlyph.baseWidth * 0.3, CairnGlyph.baseHeight * 0.3),
        );
        expect(
          tester
              .widget<Opacity>(
                find.descendant(
                  of: find.byType(CairnGlyph),
                  matching: find.byType(Opacity),
                ),
              )
              .opacity,
          0.5,
        );
      });

      testWidgets('clamps an out-of-range stone count', (tester) async {
        await tester.pumpWidget(
          host(buildTheme(), const CairnGlyph(stoneCount: 9)),
        );

        expect(tester.takeException(), isNull);
        expect(stoneFills(tester), CairnGlyph.stoneFills);
      });
    });
  }

  testWidgets('stone fills are identical in light and dark', (tester) async {
    await tester.pumpWidget(
      host(AppTheme.light, const CairnGlyph(stoneCount: 4)),
    );
    final light = stoneFills(tester);

    await tester.pumpWidget(
      host(AppTheme.dark, const CairnGlyph(stoneCount: 4)),
    );

    expect(light, CairnGlyph.stoneFills);
    expect(stoneFills(tester), light);
  });
}
