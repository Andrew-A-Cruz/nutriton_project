import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/providers/infrastructure_providers.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:nutriton_project/views/home/undo_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

/// The fixed "now" every test uses, so the Home day never depends on the real
/// clock.
final _now = DateTime(2026, 10, 21, 12);
final _today = todayKey(_now);
final _yesterday = addDays(_today, -1);
final _tomorrow = addDays(_today, 1);

/// A test body that always cleans up: the Undo banner is hidden and the tree
/// unmounted even when an expectation fails, so no timer is left pending.
typedef _Body = Future<void> Function(WidgetTester tester);

void _appTest(String description, _Body body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      hideUndoBanner();
      await unmount(tester);
    }
  });
}

/// A [LogRepository] that can hold a copy open, count moves and fail restores.
class _SpyLogRepository extends LogRepository {
  _SpyLogRepository(super.db);

  final _copyGate = Completer<void>();
  bool gateCopy = false;
  int copyCalls = 0;
  int moveCalls = 0;
  bool failRestore = false;
  Future<int>? lastCopy;

  void releaseCopy() => _copyGate.complete();

  @override
  Future<int> copyDay({required String fromDate, required String toDate}) {
    copyCalls++;
    lastCopy = () async {
      if (gateCopy) await _copyGate.future;
      return super.copyDay(fromDate: fromDate, toDate: toDate);
    }();
    return lastCopy!;
  }

  @override
  Future<void> moveEntry(String entryId, String logDate) {
    moveCalls++;
    return super.moveEntry(entryId, logDate);
  }

  @override
  Future<void> restoreEntry(DeletedLogEntry deleted) {
    if (failRestore) throw StateError('disk full');
    return super.restoreEntry(deleted);
  }
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories', 'protein'],
      'goal_calories': 2000.0,
      'goal_protein': 150.0,
      'display_unit': 'g',
    });
  });

  tearDown(() async {
    hideUndoBanner();
    await db.close();
  });

  /// Today: 1.5 servings of chicken (247.5 kcal) and a 200 kcal protein bar.
  Future<void> seedDay() async {
    final catalog = CatalogRepository(db);
    final log = LogRepository(db);
    final chickenId = await catalog.createFood(
      name: 'Chicken breast',
      perServing: const Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6),
      servingWeightG: 100,
    );
    await log.logFood(
      logDate: _today,
      food: (await catalog.findFood(chickenId))!,
      servings: 1.5,
    );
    await log.logAdhoc(
      logDate: _today,
      name: 'Protein bar',
      macros: const Macros(calories: 200, protein: 20, carbs: 22, fat: 7),
    );
  }

  /// Today: one meal, "Lunch bowl", with 150 g of chicken.
  Future<void> seedMealDay() async {
    final catalog = CatalogRepository(db);
    final chickenId = await catalog.createFood(
      name: 'Chicken breast',
      perServing: const Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6),
      servingWeightG: 100,
    );
    final mealId = await catalog.createMeal(
      name: 'Lunch bowl',
      items: [MealItemInput(foodItemId: chickenId, weightG: 150)],
    );
    await LogRepository(db).logMeal(
      logDate: _today,
      meal: (await catalog.findMeal(mealId))!,
      items: [MealItemInput(foodItemId: chickenId, weightG: 150)],
    );
  }

  /// Home on the fixed day, with [overrides] added to the clock override.
  Future<void> pumpHome(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [
          clockProvider.overrideWithValue(() => _now),
          ...overrides,
        ],
      ),
    );
    await settle(tester);
  }

  /// Swipes [finder] left to delete it, then lets the delete reach the
  /// database and the banner appear.
  Future<void> swipeToDelete(WidgetTester tester, Finder finder) async {
    await tester.drag(finder, const Offset(-500, 0));
    await tester.pump();
    await settle(tester);
    await settle(tester);
  }

  Future<List<String>> entryNamesOn(WidgetTester tester, String date) async {
    final entries = await tester.runAsync(
      () => db.logDao.findEntriesForDate(date),
    );
    return [for (final e in entries!) e.name];
  }

  /// Long-presses [name], picks [to] in the Move picker and confirms.
  Future<void> moveViaLongPress(
    WidgetTester tester,
    String name,
    String to,
  ) async {
    await tester.longPress(find.text(name));
    await settle(tester);
    await tester.tap(find.text('Move to another day'));
    await settle(tester);
    tester
        .widget<CupertinoDatePicker>(find.byKey(const Key('move-entry-picker')))
        .onDateTimeChanged(dateFromKey(to));
    await tester.tap(find.byKey(const Key('move-entry-confirm')));
    await settle(tester);
    await settle(tester);
  }

  _appTest('undo brings a swiped entry back and removes the banner', (
    tester,
  ) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    await swipeToDelete(tester, find.text('Protein bar'));

    expect(find.text('Protein bar'), findsNothing);
    expect(find.byKey(const Key('undo-banner')), findsOneWidget);
    expect(find.text('Entry deleted'), findsOneWidget);

    await tester.tap(find.byKey(const Key('undo-button')));
    await settle(tester);
    await settle(tester);

    expect(find.text('Protein bar'), findsOneWidget);
    expect(find.byKey(const Key('undo-banner')), findsNothing);
    expect(await entryNamesOn(tester, _today), [
      'Chicken breast',
      'Protein bar',
    ]);
  });

  _appTest('the banner auto-dismisses and the entry stays deleted', (
    tester,
  ) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    await swipeToDelete(tester, find.text('Protein bar'));
    expect(find.byKey(const Key('undo-banner')), findsOneWidget);

    await tester.pump(undoBannerDuration + const Duration(milliseconds: 100));
    await settle(tester);

    expect(find.byKey(const Key('undo-banner')), findsNothing);
    expect(find.text('Protein bar'), findsNothing);
    expect(await entryNamesOn(tester, _today), ['Chicken breast']);
  });

  _appTest('deleting the last entry of the day, then Undo, restores it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await LogRepository(db).logAdhoc(
        logDate: _today,
        name: 'Protein bar',
        macros: const Macros(calories: 200, protein: 20, carbs: 22, fat: 7),
      );
    });
    await pumpHome(tester);
    expect(find.text('Protein bar'), findsOneWidget);

    await swipeToDelete(tester, find.byType(Dismissible).first);

    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(find.byKey(const Key('undo-banner')), findsOneWidget);
    expect(await entryNamesOn(tester, _today), isEmpty);

    await tester.tap(find.byKey(const Key('undo-button')));
    await settle(tester);
    await settle(tester);

    expect(find.text('Nothing logged yet'), findsNothing);
    expect(find.text('Protein bar'), findsOneWidget);
    expect(await entryNamesOn(tester, _today), ['Protein bar']);
  });

  _appTest('a second delete replaces the banner: only one is shown', (
    tester,
  ) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    await swipeToDelete(tester, find.text('Protein bar'));
    expect(find.byKey(const Key('undo-banner')), findsOneWidget);

    await swipeToDelete(tester, find.text('Chicken breast'));
    expect(find.byKey(const Key('undo-banner')), findsOneWidget);
    expect(find.text('Nothing logged yet'), findsOneWidget);

    // Dropping the first undo is intended: only one undo is pending at a time,
    // so Undo restores the most recent delete and the first stays deleted.
    await tester.tap(find.byKey(const Key('undo-button')));
    await settle(tester);
    await settle(tester);

    expect(find.text('Chicken breast'), findsOneWidget);
    expect(find.text('Protein bar'), findsNothing);
    expect(find.byKey(const Key('undo-banner')), findsNothing);
    expect(await entryNamesOn(tester, _today), ['Chicken breast']);
  });

  _appTest('swipe-deleting a meal then Undo brings back its breakdown', (
    tester,
  ) async {
    await tester.runAsync(seedMealDay);
    await pumpHome(tester);

    await swipeToDelete(tester, find.text('Lunch bowl'));
    expect(find.text('Lunch bowl'), findsNothing);

    await tester.tap(find.byKey(const Key('undo-button')));
    await settle(tester);
    await settle(tester);

    expect(find.text('Lunch bowl'), findsOneWidget);
    final entries = await tester.runAsync(
      () => db.logDao.findEntriesForDate(_today),
    );
    final meal = entries!.single;
    expect(meal.entryType, 'meal');
    final items = await tester.runAsync(
      () => db.logDao.findEntryItems(meal.id),
    );
    expect(items!.map((i) => (i.name, i.weightG)), [('Chicken breast', 150.0)]);
  });

  _appTest('tapping a one-off opens the edit sheet and saving updates Home', (
    tester,
  ) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    await tester.tap(find.text('Protein bar'));
    await settle(tester);
    expect(find.text('Edit one-off food'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('adhoc-edit-name')),
      'Protein shake',
    );
    await tester.enterText(find.byKey(const Key('adhoc-edit-calories')), '250');
    await tester.tap(find.byKey(const Key('adhoc-edit-save')));
    await settle(tester);
    await settle(tester);

    expect(find.text('Edit one-off food'), findsNothing);
    expect(find.text('Protein bar'), findsNothing);
    expect(find.text('Protein shake'), findsOneWidget);
    expect(find.text('250 kcal'), findsOneWidget);

    final entries = await tester.runAsync(
      () => db.logDao.findEntriesForDate(_today),
    );
    final shake = entries!.firstWhere((e) => e.name == 'Protein shake');
    expect(shake.entryType, 'adhoc');
    expect(shake.calories, 250);
    expect(shake.protein, 20);
  });

  _appTest('the one-off edit sheet rejects invalid input and does not save', (
    tester,
  ) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    await tester.tap(find.text('Protein bar'));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('adhoc-edit-name')), 'P');
    await tester.enterText(find.byKey(const Key('adhoc-edit-calories')), 'abc');
    await tester.enterText(find.byKey(const Key('adhoc-edit-fat')), '-1');
    await tester.tap(find.byKey(const Key('adhoc-edit-save')));
    await settle(tester);

    expect(find.text('Enter a name (at least 2 characters)'), findsOneWidget);
    expect(find.text('Enter a number'), findsOneWidget);
    expect(find.text('Cannot be negative'), findsOneWidget);
    // Still open, nothing written.
    expect(find.text('Edit one-off food'), findsOneWidget);
    final entries = await tester.runAsync(
      () => db.logDao.findEntriesForDate(_today),
    );
    final bar = entries!.firstWhere((e) => e.entryType == 'adhoc');
    expect(bar.name, 'Protein bar');
    expect(bar.calories, 200);
    expect(bar.fat, 7);
  });

  _appTest('Cancel on the one-off edit sheet leaves the entry unchanged', (
    tester,
  ) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    await tester.tap(find.text('Protein bar'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('adhoc-edit-name')),
      'Changed my mind',
    );
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.text('Edit one-off food'), findsNothing);
    expect(find.text('Protein bar'), findsOneWidget);
    expect(find.text('Changed my mind'), findsNothing);
    final entries = await tester.runAsync(
      () => db.logDao.findEntriesForDate(_today),
    );
    expect(entries!.firstWhere((e) => e.entryType == 'adhoc').name, 'Protein bar');
  });

  _appTest('the Move button in the one-off edit sheet moves the entry', (
    tester,
  ) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    await tester.tap(find.text('Protein bar'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('adhoc-edit-move')));
    await settle(tester);
    expect(find.byKey(const Key('move-entry-picker')), findsOneWidget);

    tester
        .widget<CupertinoDatePicker>(find.byKey(const Key('move-entry-picker')))
        .onDateTimeChanged(dateFromKey(_tomorrow));
    await tester.tap(find.byKey(const Key('move-entry-confirm')));
    await settle(tester);
    await settle(tester);

    expect(find.text('Edit one-off food'), findsNothing);
    expect(find.text('Protein bar'), findsNothing);
    expect(await entryNamesOn(tester, _today), ['Chicken breast']);
    expect(await entryNamesOn(tester, _tomorrow), ['Protein bar']);
  });

  _appTest('long-press then Move to another day moves the entry off today', (
    tester,
  ) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    await moveViaLongPress(tester, 'Protein bar', _tomorrow);

    expect(find.text('Protein bar'), findsNothing);
    expect(find.text('Chicken breast'), findsOneWidget);
    expect(await entryNamesOn(tester, _today), ['Chicken breast']);
    expect(await entryNamesOn(tester, _tomorrow), ['Protein bar']);
  });

  _appTest('long-press Move works for a food entry', (tester) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    await moveViaLongPress(tester, 'Chicken breast', _tomorrow);

    expect(find.text('Chicken breast'), findsNothing);
    expect(await entryNamesOn(tester, _today), ['Protein bar']);
    expect(await entryNamesOn(tester, _tomorrow), ['Chicken breast']);
    final moved = await tester.runAsync(
      () => db.logDao.findEntriesForDate(_tomorrow),
    );
    expect(moved!.single.servings, 1.5);
  });

  _appTest('long-press Move works for a meal entry and keeps its breakdown', (
    tester,
  ) async {
    await tester.runAsync(seedMealDay);
    await pumpHome(tester);

    await moveViaLongPress(tester, 'Lunch bowl', _tomorrow);

    expect(find.text('Lunch bowl'), findsNothing);
    expect(await entryNamesOn(tester, _today), isEmpty);
    final moved = await tester.runAsync(
      () => db.logDao.findEntriesForDate(_tomorrow),
    );
    expect(moved!.single.entryType, 'meal');
    final items = await tester.runAsync(
      () => db.logDao.findEntryItems(moved.single.id),
    );
    expect(items, hasLength(1));
  });

  _appTest('Cancel on the long-press action sheet changes nothing', (
    tester,
  ) async {
    await tester.runAsync(seedDay);
    await pumpHome(tester);

    await tester.longPress(find.text('Protein bar'));
    await settle(tester);
    expect(find.text('Move to another day'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.text('Move to another day'), findsNothing);
    expect(await entryNamesOn(tester, _today), [
      'Chicken breast',
      'Protein bar',
    ]);
  });

  _appTest('Cancel on the move picker changes nothing', (tester) async {
    await tester.runAsync(seedDay);
    final spy = _SpyLogRepository(db);
    await pumpHome(
      tester,
      overrides: [logRepositoryProvider.overrideWithValue(spy)],
    );

    await tester.longPress(find.text('Protein bar'));
    await settle(tester);
    await tester.tap(find.text('Move to another day'));
    await settle(tester);
    tester
        .widget<CupertinoDatePicker>(find.byKey(const Key('move-entry-picker')))
        .onDateTimeChanged(dateFromKey(_tomorrow));
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.byKey(const Key('move-entry-picker')), findsNothing);
    expect(spy.moveCalls, 0);
    expect(await entryNamesOn(tester, _today), [
      'Chicken breast',
      'Protein bar',
    ]);
    expect(await entryNamesOn(tester, _tomorrow), isEmpty);
  });

  _appTest('moving to the same day closes the picker without writing', (
    tester,
  ) async {
    await tester.runAsync(seedDay);
    final spy = _SpyLogRepository(db);
    await pumpHome(
      tester,
      overrides: [logRepositoryProvider.overrideWithValue(spy)],
    );

    await tester.longPress(find.text('Protein bar'));
    await settle(tester);
    await tester.tap(find.text('Move to another day'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('move-entry-confirm')));
    await settle(tester);

    expect(find.byKey(const Key('move-entry-picker')), findsNothing);
    expect(spy.moveCalls, 0);
    expect(find.text('Protein bar'), findsOneWidget);
    expect(await entryNamesOn(tester, _today), [
      'Chicken breast',
      'Protein bar',
    ]);
  });

  _appTest('a failed undo shows an error dialog and the entry stays deleted', (
    tester,
  ) async {
    await tester.runAsync(seedDay);
    final spy = _SpyLogRepository(db)..failRestore = true;
    await pumpHome(
      tester,
      overrides: [logRepositoryProvider.overrideWithValue(spy)],
    );

    await swipeToDelete(tester, find.text('Protein bar'));
    await tester.tap(find.byKey(const Key('undo-button')));
    await settle(tester);

    expect(find.text('Could not undo: Bad state: disk full'), findsOneWidget);
    expect(find.text('Protein bar'), findsNothing);

    await tester.tap(find.text('OK'));
    await settle(tester);

    expect(find.text('Could not undo: Bad state: disk full'), findsNothing);
    expect(await entryNamesOn(tester, _today), ['Chicken breast']);
  });

  _appTest('Copy yesterday, pressed twice in one frame, copies the day once', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final catalog = CatalogRepository(db);
      final id = await catalog.createFood(
        name: 'Chicken breast',
        perServing: const Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6),
        servingWeightG: 100,
      );
      await LogRepository(db).logFood(
        logDate: _yesterday,
        food: (await catalog.findFood(id))!,
        servings: 1,
      );
    });

    final spy = _SpyLogRepository(db)..gateCopy = true;
    await pumpHome(
      tester,
      overrides: [logRepositoryProvider.overrideWithValue(spy)],
    );

    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(find.text('Copy yesterday'), findsOneWidget);

    // Grab the handler before the first press, then call it twice in the same
    // frame: the in-method guard must stop the second copy, not the disabled
    // button.
    final press = tester
        .widget<CupertinoButton>(find.byKey(const Key('copy-previous-day')))
        .onPressed!;
    press();
    press();
    await tester.pump();

    expect(spy.copyCalls, 1);
    expect(find.text('Copy yesterday'), findsOneWidget);
    expect(
      tester
          .widget<CupertinoButton>(find.byKey(const Key('copy-previous-day')))
          .onPressed,
      isNull,
    );

    // Let the held copy run to completion.
    spy.releaseCopy();
    await tester.runAsync(() => spy.lastCopy!);
    await settle(tester);
    await settle(tester);

    expect(spy.copyCalls, 1);
    expect(await entryNamesOn(tester, _today), ['Chicken breast']);
    expect(find.text('Chicken breast'), findsOneWidget);
  });
}
