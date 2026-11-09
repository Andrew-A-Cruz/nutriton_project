import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:nutriton_project/views/home/undo_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

final _now = DateTime(2026, 11, 9, 12);
final _today = todayKey(_now);
final _yesterday = addDays(_today, -1);

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

  /// Cleans up even when an expectation fails, so no timer is left pending.
  void appTest(String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        hideUndoBanner();
        await unmount(tester);
      }
    });
  }

  Future<void> logOneOff(WidgetTester tester, String day, String name) =>
      tester.runAsync(
        () => LogRepository(db).logAdhoc(
          logDate: day,
          name: name,
          macros: const Macros(calories: 400, protein: 20, carbs: 40, fat: 15),
        ),
      );

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [clockProvider.overrideWithValue(() => _now)],
      ),
    );
    await settle(tester);
  }

  Future<List<FoodLogEntry>> entriesOn(WidgetTester tester, String day) async =>
      (await tester.runAsync(() => db.logDao.findEntriesForDate(day)))!;

  Future<void> undo(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('undo-button')));
    await settle(tester);
    await settle(tester);
  }

  appTest('an edit can be undone', (tester) async {
    await logOneOff(tester, _today, 'Soup');
    await pumpHome(tester);
    await tester.tap(find.text('Soup'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('adhoc-edit-name')), 'Stew');
    await tester.enterText(find.byKey(const Key('adhoc-edit-calories')), '650');
    await tester.tap(find.byKey(const Key('adhoc-edit-save')));
    await settle(tester);

    expect(find.text('Entry updated'), findsOneWidget);
    expect((await entriesOn(tester, _today)).single.name, 'Stew');

    await undo(tester);
    final back = (await entriesOn(tester, _today)).single;
    expect(back.name, 'Soup');
    expect(back.calories, 400);
  });

  appTest('a move can be undone', (tester) async {
    await logOneOff(tester, _today, 'Soup');
    await pumpHome(tester);
    await tester.longPress(find.text('Soup'));
    await settle(tester);
    await tester.tap(find.text('Move to another day'));
    await settle(tester);
    tester
        .widget<CupertinoDatePicker>(find.byKey(const Key('move-entry-picker')))
        .onDateTimeChanged(dateFromKey(_yesterday));
    await tester.tap(find.byKey(const Key('move-entry-confirm')));
    await settle(tester);
    await settle(tester);

    expect(find.text('Moved to Yesterday'), findsOneWidget);
    expect(await entriesOn(tester, _today), isEmpty);

    await undo(tester);
    expect((await entriesOn(tester, _today)).single.name, 'Soup');
  });

  appTest('Copy yesterday can be undone', (tester) async {
    await logOneOff(tester, _yesterday, 'Oats');
    await logOneOff(tester, _yesterday, 'Salad');
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('copy-previous-day')));
    await settle(tester);
    await settle(tester);

    expect(find.text('Day copied'), findsOneWidget);
    expect(await entriesOn(tester, _today), hasLength(2));

    await undo(tester);
    expect(await entriesOn(tester, _today), isEmpty);
    expect(await entriesOn(tester, _yesterday), hasLength(2));
  });
}
