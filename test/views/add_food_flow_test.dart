import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late String today;
  late String yesterday;

  setUp(() async {
    today = todayKey();
    yesterday = addDays(today, -1);
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'display_unit': 'g',
    });
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedChicken() => CatalogRepository(db).createFood(
    name: 'Chicken breast',
    perServing: const Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6),
    servingWeightG: 100,
  );

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
  }

  /// Opens Add Food from Home. Home is on the day it was showing.
  Future<void> openAddFood(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
  }

  Future<List<FoodLogEntry>> entriesOn(String day) async =>
      (await db.logDao.watchEntriesForDate(day).first);

  testWidgets(
    'logging a food by grams lands on the day Home is showing, not today',
    (tester) async {
      await tester.runAsync(seedChicken);
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('previous-day')));
      await settle(tester);

      await openAddFood(tester);
      await tester.tap(find.text('Chicken breast'));
      await settle(tester);
      await tester.tap(find.text('Grams'));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('log-amount')), '150');
      await settle(tester);

      expect(find.text('Logging to Yesterday'), findsOneWidget);
      expect(find.byKey(const Key('log-servings')), findsOneWidget);
      expect(find.text('1.5 servings'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('log-preview'))).data,
        '248 kcal · 46.5 g protein · 0.0 g carbs · 5.4 g fat',
      );

      await tester.tap(find.byKey(const Key('log-food-confirm')));
      await settle(tester);

      // Back on Home, showing yesterday.
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Chicken breast'), findsOneWidget);
      final entries = await tester.runAsync(() => entriesOn(yesterday));
      expect(entries!.single.entryType, 'food');
      expect(entries.single.servings, closeTo(1.5, 1e-9));
      expect(entries.single.calories, closeTo(247.5, 1e-9));
      expect(await tester.runAsync(() => entriesOn(today)), isEmpty);
      await unmount(tester);
    },
  );

  testWidgets('servings are the default; switching modes converts the amount', (
    tester,
  ) async {
    await tester.runAsync(seedChicken);
    await pumpHome(tester);
    await openAddFood(tester);
    await tester.tap(find.text('Chicken breast'));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('log-amount')), '2');
    await settle(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('log-preview'))).data,
      '330 kcal · 62.0 g protein · 0.0 g carbs · 7.2 g fat',
    );

    // 2 servings is 200 g once switched to grams.
    await tester.tap(find.text('Grams'));
    await settle(tester);
    final amount = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('log-amount')),
        matching: find.byType(EditableText),
      ),
    );
    expect(amount.controller.text, '200');
    await unmount(tester);
  });

  testWidgets('with ounces as the display unit, weight is typed in oz', (
    tester,
  ) async {
    prefs = (await tester.runAsync(
      () => mockPreferences({
        'onboarding_complete': true,
        'primary_metric': 'calories',
        'display_unit': 'oz',
      }),
    ))!;
    await tester.runAsync(seedChicken);
    await pumpHome(tester);
    await openAddFood(tester);
    await tester.tap(find.text('Chicken breast'));
    await settle(tester);

    await tester.tap(find.text('Ounces'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('log-amount')), '4');
    await settle(tester);
    // 4 oz = 113.398 g = 1.13 servings of a 100 g serving.
    expect(find.text('1.13 servings'), findsOneWidget);

    await tester.tap(find.byKey(const Key('log-food-confirm')));
    await settle(tester);

    final entries = await tester.runAsync(() => entriesOn(today));
    expect(entries!.single.servings, closeTo(1.13398, 1e-9));
    expect(entries.single.calories, closeTo(165 * 1.13398, 1e-9));
    await unmount(tester);
  });

  testWidgets('a zero amount is rejected and nothing is logged', (
    tester,
  ) async {
    await tester.runAsync(seedChicken);
    await pumpHome(tester);
    await openAddFood(tester);
    await tester.tap(find.text('Chicken breast'));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('log-amount')), '0');
    await settle(tester);
    await tester.tap(find.byKey(const Key('log-food-confirm')));
    await settle(tester);

    expect(find.text('Enter a number greater than 0'), findsOneWidget);
    expect(find.text('Logging to Today'), findsOneWidget);
    expect(await tester.runAsync(() => entriesOn(today)), isEmpty);
    await unmount(tester);
  });

  testWidgets('a new catalog food is saved and logged in one step', (
    tester,
  ) async {
    await pumpHome(tester);
    await openAddFood(tester);

    await tester.tap(find.byKey(const Key('add-new-food')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('food-name')), 'Oats');
    await tester.enterText(find.byKey(const Key('food-calories')), '150');
    await tester.enterText(find.byKey(const Key('food-protein')), '5');
    await tester.enterText(find.byKey(const Key('food-carbs')), '27');
    await tester.enterText(find.byKey(const Key('food-fat')), '3');
    await tester.enterText(find.byKey(const Key('food-serving-weight')), '40');
    await tester.tap(find.byKey(const Key('food-save')));
    await settle(tester);

    // Save & Log opens the log step for the new food.
    expect(find.text('Oats'), findsWidgets);
    expect(find.byKey(const Key('log-food-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('log-food-confirm')));
    await settle(tester);

    final foods = await tester.runAsync(() => db.foodDao.findActive());
    expect(foods!.map((f) => f.name), ['Oats']);
    final entries = await tester.runAsync(() => entriesOn(today));
    expect(entries!.single.name, 'Oats');
    expect(entries.single.servings, 1);
    await unmount(tester);
  });

  testWidgets(
    'a one-off food logs for the selected day and skips the catalog',
    (tester) async {
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('previous-day')));
      await settle(tester);
      await openAddFood(tester);

      await tester.tap(find.text('One-off'));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('adhoc-name')), 'Burrito');
      await tester.enterText(find.byKey(const Key('adhoc-calories')), '600');
      await tester.enterText(find.byKey(const Key('adhoc-protein')), '25');
      await tester.enterText(find.byKey(const Key('adhoc-carbs')), '70');
      await tester.enterText(find.byKey(const Key('adhoc-fat')), '20');
      await tester.tap(find.byKey(const Key('adhoc-log')));
      await settle(tester);

      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Burrito'), findsOneWidget);
      final entries = await tester.runAsync(() => entriesOn(yesterday));
      expect(entries!.single.entryType, 'adhoc');
      expect(entries.single.calories, 600);
      expect(entries.single.foodItemId, isNull);
      expect(await tester.runAsync(() => db.foodDao.findActive()), isEmpty);
      await unmount(tester);
    },
  );

  testWidgets('the one-off form rejects a blank name and bad macros', (
    tester,
  ) async {
    await pumpHome(tester);
    await openAddFood(tester);
    await tester.tap(find.text('One-off'));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('adhoc-carbs')), '-2');
    await tester.tap(find.byKey(const Key('adhoc-log')));
    await settle(tester);

    expect(find.text('Enter a name (at least 2 characters)'), findsOneWidget);
    expect(find.text('Enter a number'), findsNWidgets(3));
    expect(find.text('Cannot be negative'), findsOneWidget);
    expect(await tester.runAsync(() => entriesOn(today)), isEmpty);
    await unmount(tester);
  });
}
