import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/meal_slot.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/views/home/undo_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late LogRepository log;
  late String today;

  setUp(() async {
    today = todayKey();
    db = AppDatabase(NativeDatabase.memory());
    log = LogRepository(db);
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'display_unit': 'g',
    });
  });

  tearDown(() async {
    await db.close();
  });

  Macros kcal(double c) => Macros(calories: c, protein: 1, carbs: 1, fat: 1);

  Future<String> adhoc(String name, double c, MealSlot? slot) =>
      log.logAdhoc(logDate: today, name: name, macros: kcal(c), mealSlot: slot);

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    hideUndoBanner();
    await unmount(tester);
  }

  String totalOf(WidgetTester tester, String id) =>
      tester.widget<Text>(find.byKey(Key('section-total-$id'))).data!;

  testWidgets('Home groups entries into sections with calorie subtotals', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await adhoc('Oatmeal', 300, MealSlot.breakfast);
      await adhoc('Soup', 200, MealSlot.dinner);
      await adhoc('Pasta', 250.5, MealSlot.dinner);
      await adhoc('Apple', 100, MealSlot.snack);
      await adhoc('Old entry', 50, null);
    });
    await pumpHome(tester);

    for (final id in ['breakfast', 'dinner', 'snack', 'other']) {
      expect(find.byKey(Key('section-$id')), findsOneWidget, reason: id);
    }
    expect(find.byKey(const Key('section-lunch')), findsNothing);
    expect(find.text('Lunch'), findsNothing);

    expect(totalOf(tester, 'breakfast'), '300 kcal');
    expect(totalOf(tester, 'dinner'), '451 kcal');
    expect(totalOf(tester, 'snack'), '100 kcal');
    expect(totalOf(tester, 'other'), '50 kcal');
    expect(find.text('Other'), findsOneWidget);

    // Sections run Breakfast, Dinner, Snack, Other, top to bottom.
    double y(String id) => tester.getTopLeft(find.byKey(Key('section-$id'))).dy;
    expect(y('breakfast'), lessThan(y('dinner')));
    expect(y('dinner'), lessThan(y('snack')));
    expect(y('snack'), lessThan(y('other')));
    // Entries sit under their header, in creation order within a section.
    double e(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(e('Oatmeal'), greaterThan(y('breakfast')));
    expect(e('Oatmeal'), lessThan(y('dinner')));
    expect(e('Soup'), lessThan(e('Pasta')));
    expect(e('Old entry'), greaterThan(y('other')));
    await finish(tester);
  });

  testWidgets('a section with only null-slot entries shows just Other', (
    tester,
  ) async {
    await tester.runAsync(() => adhoc('Legacy', 120, null));
    await pumpHome(tester);

    expect(find.byKey(const Key('section-other')), findsOneWidget);
    expect(find.byKey(const Key('section-breakfast')), findsNothing);
    expect(find.byKey(const Key('section-snack')), findsNothing);
    await finish(tester);
  });

  testWidgets('deleting the last entry of a section removes its header', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await adhoc('Oatmeal', 300, MealSlot.breakfast);
      await adhoc('Apple', 100, MealSlot.snack);
    });
    await pumpHome(tester);

    await tester.drag(find.text('Apple'), const Offset(-600, 0));
    await settle(tester);

    expect(find.byKey(const Key('section-snack')), findsNothing);
    expect(find.byKey(const Key('section-breakfast')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('logging from the Add sheet stores the picked slot', (
    tester,
  ) async {
    await tester.runAsync(
      () => CatalogRepository(db).createFood(
        name: 'Chicken breast',
        perServing: const Macros(
          calories: 165,
          protein: 31,
          carbs: 0,
          fat: 3.6,
        ),
        servingWeightG: 100,
      ),
    );
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
    await tester.tap(find.text('Chicken breast'));
    await settle(tester);

    await tester.tap(find.text('Dinner'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('log-food-confirm')));
    await settle(tester);

    final entries = await tester.runAsync(
      () => db.logDao.watchEntriesForDate(today).first,
    );
    expect(entries!.single.mealSlot, 'dinner');
    expect(find.byKey(const Key('section-dinner')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the one-off form logs with the picked slot', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
    await tester.tap(find.text('One-off'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('adhoc-name')), 'Burrito');
    await tester.enterText(find.byKey(const Key('adhoc-calories')), '600');
    await tester.enterText(find.byKey(const Key('adhoc-protein')), '25');
    await tester.enterText(find.byKey(const Key('adhoc-carbs')), '70');
    await tester.enterText(find.byKey(const Key('adhoc-fat')), '20');
    await tester.tap(find.text('Breakfast'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('adhoc-log')));
    await settle(tester);

    final entries = await tester.runAsync(
      () => db.logDao.watchEntriesForDate(today).first,
    );
    expect(entries!.single.mealSlot, 'breakfast');
    await finish(tester);
  });

  testWidgets('a food entry is moved to another section from its edit sheet', (
    tester,
  ) async {
    await tester.runAsync(() => adhoc('Apple', 100, MealSlot.lunch));
    await tester.runAsync(() => adhoc('Rice', 200, null));
    await pumpHome(tester);

    // The one-off sheet: change Apple to Snack and save.
    await tester.tap(find.text('Apple'));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('meal-slot-picker')),
        matching: find.text('Snack'),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('adhoc-edit-save')));
    await settle(tester);

    expect(find.byKey(const Key('section-lunch')), findsNothing);
    expect(find.byKey(const Key('section-snack')), findsOneWidget);
    expect(totalOf(tester, 'snack'), '100 kcal');
    await finish(tester);
  });

  testWidgets('the servings dialog changes the slot of a food entry', (
    tester,
  ) async {
    late FoodItem food;
    await tester.runAsync(() async {
      final catalog = CatalogRepository(db);
      final id = await catalog.createFood(
        name: 'Rice',
        perServing: kcal(130),
        servingWeightG: 100,
      );
      food = (await catalog.findFood(id))!;
      await log.logFood(logDate: today, food: food, servings: 1);
    });
    await pumpHome(tester);
    expect(find.byKey(const Key('section-other')), findsOneWidget);

    await tester.tap(find.text('Rice'));
    await settle(tester);
    await tester.tap(find.text('Lunch'));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.byKey(const Key('section-other')), findsNothing);
    expect(find.byKey(const Key('section-lunch')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the meal sheet saves a slot change at once', (tester) async {
    late String entryId;
    await tester.runAsync(() async {
      final catalog = CatalogRepository(db);
      final foodId = await catalog.createFood(
        name: 'Rice',
        perServing: kcal(130),
        servingWeightG: 100,
      );
      final mealId = await catalog.createMeal(
        name: 'Bowl',
        items: [MealItemInput(foodItemId: foodId, weightG: 200)],
      );
      entryId = await log.logMeal(
        logDate: today,
        meal: (await catalog.findMeal(mealId))!,
        items: [MealItemInput(foodItemId: foodId, weightG: 150)],
        mealSlot: MealSlot.breakfast,
      );
    });
    await pumpHome(tester);

    await tester.tap(find.text('Bowl'));
    await settle(tester);
    await tester.tap(find.text('Dinner'));
    await settle(tester);

    final entry = await tester.runAsync(() => db.logDao.findEntry(entryId));
    expect(entry!.mealSlot, 'dinner');
    await finish(tester);
  });
}
