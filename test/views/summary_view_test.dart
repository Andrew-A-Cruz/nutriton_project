import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/views/summary/summary_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  final today = todayKey();
  final yesterday = addDays(today, -1);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories', 'protein'],
      'goal_calories': 2000.0,
      'goal_protein': 150.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  /// Today: 1000 kcal, 40 g protein. Yesterday: 2000 kcal, 60 g protein.
  /// Nothing on the other five days of the week.
  Future<void> seed() async {
    final log = LogRepository(db);
    await log.logAdhoc(
      logDate: today,
      name: 'Lunch',
      macros: const Macros(calories: 1000, protein: 40, carbs: 90, fat: 20),
    );
    await log.logAdhoc(
      logDate: yesterday,
      name: 'Dinner',
      macros: const Macros(calories: 2000, protein: 60, carbs: 200, fat: 50),
    );
  }

  Future<void> openSummary(WidgetTester tester) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
    await settle(tester);
  }

  /// The text of one average row. Keyed, because the Home tab stays built
  /// offstage and shows the same amounts.
  String averageText(WidgetTester tester, String metric) =>
      tester.widget<Text>(find.byKey(Key('average-$metric'))).data!;

  Future<void> choose(WidgetTester tester, String segment) async {
    await tester.tap(find.text(segment).last);
    await settle(tester);
  }

  testWidgets('week averages use only logged days and count them', (
    tester,
  ) async {
    await tester.runAsync(seed);
    await openSummary(tester);

    expect(find.text('Days logged: 2 of 7'), findsOneWidget);
    expect(averageText(tester, 'calories'), '1500 kcal');
    expect(averageText(tester, 'protein'), '50.0 g');
    expect(find.byType(SummaryChart), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('month counts 30 days and still skips unlogged days', (
    tester,
  ) async {
    await tester.runAsync(seed);
    await openSummary(tester);
    await choose(tester, 'Month');

    expect(find.text('Days logged: 2 of 30'), findsOneWidget);
    expect(averageText(tester, 'calories'), '1500 kcal');
    await unmount(tester);
  });

  testWidgets('day shows only today, with no chart', (tester) async {
    await tester.runAsync(seed);
    await openSummary(tester);
    await choose(tester, 'Day');

    expect(find.text('Days logged: 1 of 1'), findsOneWidget);
    expect(averageText(tester, 'calories'), '1000 kcal');
    expect(find.byType(SummaryChart), findsNothing);
    await unmount(tester);
  });

  testWidgets('six months and year show the aggregated chart', (tester) async {
    await tester.runAsync(seed);
    await openSummary(tester);

    await choose(tester, '6M');
    expect(find.text('Days logged: 2 of 180'), findsOneWidget);
    expect(find.byType(SummaryChart), findsOneWidget);

    await choose(tester, 'Year');
    expect(find.text('Days logged: 2 of 365'), findsOneWidget);
    expect(find.byType(SummaryChart), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a range with nothing logged says so', (tester) async {
    await openSummary(tester);

    expect(find.text('Nothing logged in this period.'), findsOneWidget);
    expect(find.text('Days logged: 0 of 7'), findsOneWidget);
    await unmount(tester);
  });
}
