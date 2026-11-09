import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/providers/today_providers.dart';

import '../support/test_app.dart';

final _now = DateTime(2026, 11, 9, 12);
final _today = todayKey(_now);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> log(WidgetTester tester, String day, double kcal) =>
      tester.runAsync(
        () => LogRepository(db).logAdhoc(
          logDate: day,
          name: 'Food $day',
          macros: Macros(calories: kcal, protein: 0, carbs: 0, fat: 0),
        ),
      );

  Future<void> openCalendar(WidgetTester tester, {bool mindful = false}) async {
    tester.view.physicalSize = const Size(2400, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    final prefs = await tester.runAsync(
      () => mockPreferences({
        'onboarding_complete': true,
        'primary_metric': 'calories',
        'goal_calories': 2000.0,
        'mindful_mode': mindful,
      }),
    );
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs!,
        overrides: [clockProvider.overrideWithValue(() => _now)],
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('date-title')));
    await settle(tester);
  }

  testWidgets('marks logged days against the goal', (tester) async {
    await log(tester, '2026-11-02', 1500);
    await log(tester, '2026-11-03', 2050);
    await log(tester, '2026-11-04', 2600);
    await openCalendar(tester);

    expect(find.text('November 2026'), findsOneWidget);
    expect(
      find.bySemanticsLabel('November 2, logged, under goal'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('November 3, logged, on target'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('November 4, logged, over goal'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('November 9, today, nothing logged'),
      findsOneWidget,
    );
    expect(find.text('Over goal'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tapping a day shows it on Today', (tester) async {
    await log(tester, '2026-10-20', 1800);
    await openCalendar(tester);

    await tester.tap(find.byKey(const Key('calendar-previous')));
    await settle(tester);
    expect(find.text('October 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar-day-2026-10-20')));
    await settle(tester);

    expect(find.byType(CupertinoPageScaffold), findsWidgets);
    expect(find.text('Food 2026-10-20'), findsOneWidget);
    expect(find.text('Tue, Oct 20'), findsOneWidget);
    expect(_today, '2026-11-09');
    await unmount(tester);
  });

  testWidgets('mindful mode marks logged days without goal colours', (
    tester,
  ) async {
    await log(tester, '2026-11-04', 2600);
    await openCalendar(tester, mindful: true);

    expect(find.bySemanticsLabel('November 4, logged'), findsOneWidget);
    expect(find.text('Over goal'), findsNothing);
    await unmount(tester);
  });
}
