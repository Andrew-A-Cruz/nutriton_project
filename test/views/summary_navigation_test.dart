import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:nutriton_project/views/summary/summary_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  final now = DateTime(2026, 11, 3, 12);
  final today = todayKey(now);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories'],
      'goal_calories': 2000.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  /// This week: 1900 and 2600 kcal. The week before: 2000 kcal once.
  Future<void> seed() async {
    final log = LogRepository(db);
    Future<void> day(String date, double kcal) => log.logAdhoc(
      logDate: date,
      name: 'Food',
      macros: Macros(calories: kcal),
    );
    await day(today, 1900);
    await day(addDays(today, -1), 2600);
    await day(addDays(today, -10), 2000);
  }

  Future<void> openSummary(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [clockProvider.overrideWithValue(() => now)],
      ),
    );
    await settle(tester);
    await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
    await settle(tester);
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  test('periodLabel names the span, with the year once', () {
    expect(periodLabel('2026-10-28', '2026-11-03'), 'Oct 28 – Nov 3, 2026');
    expect(
      periodLabel('2025-12-29', '2026-01-04'),
      'Dec 29, 2025 – Jan 4, 2026',
    );
    expect(periodLabel('2026-11-03', '2026-11-03'), 'Nov 3, 2026');
  });

  testWidgets('steps back a week and returns to today', (tester) async {
    await tester.runAsync(seed);
    await openSummary(tester);

    expect(text(tester, 'summary-period'), 'Oct 28 – Nov 3, 2026');
    expect(text(tester, 'days-logged'), 'Days logged: 2 of 7');
    expect(find.byKey(const Key('summary-today')), findsNothing);
    final next = tester.widget<CupertinoButton>(
      find.byKey(const Key('summary-next')),
    );
    expect(next.onPressed, isNull);

    await tester.tap(find.byKey(const Key('summary-previous')));
    await settle(tester);
    expect(text(tester, 'summary-period'), 'Oct 21 – Oct 27, 2026');
    expect(text(tester, 'days-logged'), 'Days logged: 1 of 7');
    expect(text(tester, 'average-calories'), '2000 kcal');

    await tester.tap(find.byKey(const Key('summary-today')));
    await settle(tester);
    expect(text(tester, 'summary-period'), 'Oct 28 – Nov 3, 2026');

    await tester.tap(find.byKey(const Key('summary-previous')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('summary-next')));
    await settle(tester);
    expect(text(tester, 'summary-period'), 'Oct 28 – Nov 3, 2026');
    await unmount(tester);
  });

  testWidgets('counts days on target and describes the chart', (tester) async {
    await tester.runAsync(seed);
    await openSummary(tester);

    expect(
      text(tester, 'days-on-target'),
      'On target (within 10% of the goal): 1 of 2 logged days',
    );
    expect(find.byKey(const Key('summary-legend')), findsOneWidget);
    final semantics = tester.getSemantics(
      find.byKey(const Key('summary-chart-semantics')),
    );
    expect(semantics.label, contains('2 of 7 bars with data'));
    expect(semantics.label, contains('highest 2600 kcal'));
    expect(semantics.label, contains('1 on target'));
    await unmount(tester);
  });

  testWidgets('no goal: no on-target line and no legend', (tester) async {
    await prefs.remove('goal_calories');
    await tester.runAsync(seed);
    await openSummary(tester);
    expect(find.byKey(const Key('days-on-target')), findsNothing);
    expect(find.byKey(const Key('summary-legend')), findsNothing);
    await unmount(tester);
  });
}
