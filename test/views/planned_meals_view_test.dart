import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/schedule_repository.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

// A Monday.
final _now = DateTime(2026, 11, 9, 12);

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
    });
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> openPlans(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.runAsync(() async {
      await db.mealDao.insertMeal(
        MealsCompanion.insert(id: 'm1', name: 'Work lunch'),
      );
      await ScheduleRepository(db).scheduleWeekdays(
        mealId: 'm1',
        startDate: '2026-11-09',
        weekdays: {1, 2, 3, 4, 5},
      );
    });
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [clockProvider.overrideWithValue(() => _now)],
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    final row = find.byKey(const Key('planned-meals'));
    await scrollPreferencesTo(tester, row);
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(row);
    await settle(tester);
  }

  Future<List<ScheduledMeal>> plans(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.scheduledMeals).get()))!;

  testWidgets('lists plans, and an edit adds an end date', (tester) async {
    await openPlans(tester);
    expect(find.text('Work lunch'), findsOneWidget);
    expect(find.text('Mon-Fri · By time of day'), findsOneWidget);

    await tester.tap(find.text('Work lunch'));
    await settle(tester);
    expect(find.text('Edit plan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('schedule-ends')));
    await tester.pump();
    tester
        .widget<CupertinoDatePicker>(
          find.byKey(const Key('schedule-end-picker')),
        )
        .onDateTimeChanged(DateTime(2026, 12, 4));
    await tester.pump();
    await tester.tap(find.byKey(const Key('schedule-save')));
    await settle(tester);

    final plan = (await plans(tester)).single;
    expect(plan.endDate, '2026-12-04');
    expect(plan.weekdays, 0x1F);
    expect(
      find.text('Mon-Fri · until Fri, Dec 4 · By time of day'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('a plan can be removed', (tester) async {
    await openPlans(tester);
    final id = (await plans(tester)).single.id;
    await tester.tap(find.byKey(Key('plan-remove-$id')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('plan-remove-confirm')));
    await settle(tester);

    expect(await plans(tester), isEmpty);
    expect(find.byKey(const Key('plans-empty')), findsOneWidget);
    await unmount(tester);
  });
}
