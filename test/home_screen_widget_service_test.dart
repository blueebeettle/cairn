import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/features/widgets/home_screen_widget_service.dart';

void main() {
  group('HomeScreenWidgetService', () {
    test('formatDate correctly formats YYYY-MM-DD to readable weekday and month', () {
      expect(HomeScreenWidgetService.formatDate('2026-09-20'), equals('Sun, Sep 20'));
      expect(HomeScreenWidgetService.formatDate('2026-01-01'), equals('Thu, Jan 1'));
      expect(HomeScreenWidgetService.formatDate('2026-12-25'), equals('Fri, Dec 25'));
      expect(HomeScreenWidgetService.formatDate('invalid-date'), equals('invalid-date'));
    });

    test('parseWidgetUri correctly resolves deep-link targets', () {
      expect(
        HomeScreenWidgetService.parseWidgetUri(Uri.parse('cairn://widget/habits')),
        equals(NavTabs.habits),
      );
      expect(
        HomeScreenWidgetService.parseWidgetUri(Uri.parse('cairn://widget/timer')),
        equals(NavTabs.timer),
      );
      expect(
        HomeScreenWidgetService.parseWidgetUri(Uri.parse('cairn://widget/today')),
        equals(NavTabs.today),
      );
      expect(
        HomeScreenWidgetService.parseWidgetUri(Uri.parse('cairn://widget/tasks')),
        equals(NavTabs.tasks),
      );
      expect(
        HomeScreenWidgetService.parseWidgetUri(Uri.parse('cairn://widget/stats')),
        equals(NavTabs.stats),
      );
      expect(
        HomeScreenWidgetService.parseWidgetUri(Uri.parse('https://example.com/habits')),
        isNull,
      );
    });

    test('canUpdate is false when platform is not supported', () {
      final service = HomeScreenWidgetService(isPlatformSupported: false);
      expect(service.canUpdate, isFalse);
    });

    test('updateHabitsWidget and updateTodayWidget are safe no-ops when platform is unsupported', () async {
      final service = HomeScreenWidgetService(isPlatformSupported: false);
      await expectLater(
        service.updateHabitsWidget(habits: const [], todayLocalDate: '2026-09-20'),
        completes,
      );
      await expectLater(
        service.updateTodayWidget(
          focusMinutesToday: 45,
          habitsDone: 3,
          habitsTotal: 5,
          tasksDueCount: 2,
        ),
        completes,
      );
    });
  });
}
