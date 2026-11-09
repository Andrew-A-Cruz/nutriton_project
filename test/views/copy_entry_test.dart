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

final _now = DateTime(2026, 10, 21, 12);
final _today = todayKey(_now);
final _tomorrow = addDays(_today, 1);

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

  Future<void> openCopy(WidgetTester tester) async {
    await tester.runAsync(
      () => LogRepository(db).logAdhoc(
        logDate: _today,
        name: 'Overnight oats',
        macros: const Macros(calories: 350, protein: 15, carbs: 50, fat: 9),
      ),
    );
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [clockProvider.overrideWithValue(() => _now)],
      ),
    );
    await settle(tester);
    await tester.longPress(find.text('Overnight oats'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('copy-entry')));
    await settle(tester);
  }

  Future<List<String>> namesOn(WidgetTester tester, String date) async => [
    for (final e in (await tester.runAsync(
      () => db.logDao.findEntriesForDate(date),
    ))!)
      e.name,
  ];

  appTest('Copy to tomorrow keeps the entry and logs a copy tomorrow', (
    tester,
  ) async {
    await openCopy(tester);
    expect(find.text('Copy to another day'), findsOneWidget);

    await tester.tap(find.byKey(const Key('copy-entry-tomorrow')));
    await settle(tester);

    expect(await namesOn(tester, _today), ['Overnight oats']);
    expect(await namesOn(tester, _tomorrow), ['Overnight oats']);
    expect(find.textContaining('Copied to'), findsOneWidget);

    await tester.tap(find.byKey(const Key('undo-button')));
    await settle(tester);
    expect(await namesOn(tester, _tomorrow), isEmpty);
    expect(await namesOn(tester, _today), ['Overnight oats']);
  });

  appTest('the picker copies to any day, tomorrow by default', (tester) async {
    await openCopy(tester);
    final picker = tester.widget<CupertinoDatePicker>(
      find.byKey(const Key('copy-entry-picker')),
    );
    expect(dateKey(picker.initialDateTime), _tomorrow);

    final later = addDays(_today, 5);
    picker.onDateTimeChanged(dateFromKey(later));
    await tester.tap(find.byKey(const Key('copy-entry-confirm')));
    await settle(tester);

    expect(await namesOn(tester, later), ['Overnight oats']);
    expect(await namesOn(tester, _today), ['Overnight oats']);
  });
}
