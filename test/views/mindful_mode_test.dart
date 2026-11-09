import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// Two days logged, so there is a streak and a chart.
  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    final log = LogRepository(db);
    for (final day in [todayKey(), addDays(todayKey(), -1)]) {
      await log.logAdhoc(
        logDate: day,
        name: 'Burrito',
        macros: const Macros(calories: 900, protein: 40, carbs: 100, fat: 30),
      );
    }
  });

  Future<void> open(WidgetTester tester, {required bool mindful}) async {
    final prefs = await tester.runAsync(
      () => mockPreferences({
        'onboarding_complete': true,
        'primary_metric': 'calories',
        'tracked_metrics': ['calories', 'protein'],
        'goal_calories': 2000.0,
        'goal_protein': 150.0,
        'mindful_mode': mindful,
      }),
    );
    await tester.pumpWidget(testApp(db: db, prefs: prefs!));
    await settle(tester);
  }

  testWidgets('hides the numbers and the streak, keeps foods and progress', (
    tester,
  ) async {
    await seed(tester);
    await open(tester, mindful: true);

    expect(find.text('Burrito'), findsOneWidget);
    expect(find.byKey(const Key('mindful-totals')), findsOneWidget);
    expect(find.byKey(const Key('primary-amount')), findsNothing);
    expect(find.textContaining('kcal'), findsNothing);
    expect(find.byKey(const Key('streak-badge')), findsNothing);
    expect(find.bySemanticsLabel('Calories: 45% of goal'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
    await settle(tester);
    await tester.tap(find.text('Week').last);
    await settle(tester);
    expect(find.byKey(const Key('summary-legend')), findsNothing);
    await unmount(tester);
  });

  testWidgets('off by default: numbers, streak and legend show', (
    tester,
  ) async {
    await seed(tester);
    await open(tester, mindful: false);

    expect(find.byKey(const Key('mindful-totals')), findsNothing);
    expect(find.byKey(const Key('primary-amount')), findsOneWidget);
    expect(find.byKey(const Key('streak-badge')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the Settings switch turns it on at once', (tester) async {
    await seed(tester);
    await open(tester, mindful: false);
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    final toggle = find.byKey(const Key('mindful-mode'));
    await scrollPreferencesTo(tester, toggle);
    await tester.ensureVisible(toggle);
    await tester.pump();
    await tester.tap(toggle);
    await settle(tester);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await settle(tester);

    expect(find.byKey(const Key('mindful-totals')), findsOneWidget);
    expect(find.byKey(const Key('streak-badge')), findsNothing);
    await unmount(tester);
  });
}
