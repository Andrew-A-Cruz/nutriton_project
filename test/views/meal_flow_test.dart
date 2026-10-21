import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/database/daos/meal_dao.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/views/meals/food_picker_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  final today = todayKey();

  setUp(() async {
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

  /// Chicken at 165 kcal per 100 g, and a "Lunch bowl" template that holds
  /// 150 g of it.
  Future<String> seedLunchBowl() async {
    final catalog = CatalogRepository(db);
    final chickenId = await catalog.createFood(
      name: 'Chicken breast',
      perServing: const Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6),
      servingWeightG: 100,
    );
    return catalog.createMeal(
      name: 'Lunch bowl',
      items: [MealItemInput(foodItemId: chickenId, weightG: 150)],
    );
  }

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
  }

  Future<List<MealItemRow>> templateItems(String mealId) async =>
      (await db.mealDao.findItems(mealId));

  testWidgets('builds a meal from catalog foods and lists it with its totals', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await CatalogRepository(db).createFood(
        name: 'Chicken breast',
        perServing: const Macros(
          calories: 165,
          protein: 31,
          carbs: 0,
          fat: 3.6,
        ),
        servingWeightG: 100,
      );
    });
    await pumpHome(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoTabBar),
        matching: find.text('Catalog'),
      ),
    );
    await settle(tester);

    await tester.tap(find.byKey(const Key('catalog-add')));
    await settle(tester);
    await tester.tap(find.text('New meal'));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('meal-name')), 'Lunch bowl');
    await tester.tap(find.byKey(const Key('add-meal-item')));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(FoodPickerPage),
        matching: find.text('Chicken breast'),
      ),
    );
    await settle(tester);

    // A new row starts at the food's serving weight; change it to 150 g.
    await tester.enterText(find.byKey(const Key('item-weight-0')), '150');
    await settle(tester);
    expect(find.text('248 kcal'), findsOneWidget);

    await tester.tap(find.byKey(const Key('meal-save')));
    await settle(tester);

    // Back on the catalog. The meal shows under Meals.
    await tester.tap(find.text('Meals'));
    await settle(tester);
    expect(find.text('Lunch bowl'), findsOneWidget);
    expect(find.text('1 food · 248 kcal'), findsOneWidget);

    final meals = await tester.runAsync(() => db.mealDao.findActive());
    final items = await tester.runAsync(() => templateItems(meals!.single.id));
    expect(items!.single.link.weightG, 150);
    await unmount(tester);
  });

  testWidgets('a meal needs a name and at least one food to save', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoTabBar),
        matching: find.text('Catalog'),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('catalog-add')));
    await settle(tester);
    await tester.tap(find.text('New meal'));
    await settle(tester);

    await tester.tap(find.byKey(const Key('meal-save')));
    await settle(tester);

    expect(find.text('Enter a name (at least 2 characters)'), findsOneWidget);
    expect(find.text('Add at least one food'), findsOneWidget);
    expect(await tester.runAsync(() => db.mealDao.findActive()), isEmpty);
    await unmount(tester);
  });

  testWidgets(
    'logging a meal writes one entry and leaves the template unchanged',
    (tester) async {
      final mealId = await tester.runAsync(seedLunchBowl);
      await pumpHome(tester);

      await tester.tap(find.byKey(const Key('add-food-button')));
      await settle(tester);
      await tester.tap(find.text('Meals'));
      await settle(tester);
      await tester.tap(find.text('Lunch bowl'));
      await settle(tester);

      expect(find.text('Logging to Today'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const Key('item-weight-0')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '150',
      );
      await tester.enterText(find.byKey(const Key('item-weight-0')), '120');
      await settle(tester);
      await tester.tap(find.byKey(const Key('meal-log-confirm')));
      await settle(tester);

      // Home shows the one entry, at the eaten weight: 120 g = 198 kcal.
      expect(find.text('Lunch bowl'), findsOneWidget);
      expect(find.text('198 kcal'), findsOneWidget);
      final entries = await tester.runAsync(
        () => db.logDao.watchEntriesForDate(today).first,
      );
      expect(entries!.single.entryType, 'meal');
      expect(entries.single.calories, closeTo(198, 1e-9));
      final breakdown = await tester.runAsync(
        () => db.logDao.findEntryItems(entries.single.id),
      );
      expect(breakdown!.single.weightG, 120);

      // The template still says 150 g.
      final template = await tester.runAsync(() => templateItems(mealId!));
      expect(template!.single.link.weightG, 150);
      await unmount(tester);
    },
  );

  group('with ounces as the display unit', () {
    /// Opens the Lunch bowl log screen with `display_unit` set to oz.
    Future<String> openLunchBowlInOunces(WidgetTester tester) async {
      final mealId = await tester.runAsync(seedLunchBowl);
      prefs = (await tester.runAsync(
        () => mockPreferences({
          'onboarding_complete': true,
          'primary_metric': 'calories',
          'display_unit': 'oz',
        }),
      ))!;
      await pumpHome(tester);
      await tester.tap(find.byKey(const Key('add-food-button')));
      await settle(tester);
      await tester.tap(find.text('Meals'));
      await settle(tester);
      await tester.tap(find.text('Lunch bowl'));
      await settle(tester);
      return mealId!;
    }

    String weightField(WidgetTester tester) => tester
        .widget<EditableText>(
          find.descendant(
            of: find.byKey(const Key('item-weight-0')),
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text;

    testWidgets('an untouched weight is shown in oz and logged exactly', (
      tester,
    ) async {
      await openLunchBowlInOunces(tester);

      // 150 g = 5.29 oz, shown rounded.
      expect(weightField(tester), '5.29');
      expect(find.text('Weights are in ounces.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('meal-log-confirm')));
      await settle(tester);

      final entries = await tester.runAsync(
        () => db.logDao.watchEntriesForDate(today).first,
      );
      final breakdown = await tester.runAsync(
        () => db.logDao.findEntryItems(entries!.single.id),
      );
      // The stored grams are the template's, not 5.29 oz converted back.
      expect(breakdown!.single.weightG, 150);
      expect(entries!.single.calories, closeTo(247.5, 1e-9));
      await unmount(tester);
    });

    testWidgets('a typed weight is read as ounces', (tester) async {
      await openLunchBowlInOunces(tester);

      await tester.enterText(find.byKey(const Key('item-weight-0')), '4');
      await settle(tester);
      await tester.tap(find.byKey(const Key('meal-log-confirm')));
      await settle(tester);

      final entries = await tester.runAsync(
        () => db.logDao.watchEntriesForDate(today).first,
      );
      final breakdown = await tester.runAsync(
        () => db.logDao.findEntryItems(entries!.single.id),
      );
      // 4 oz = 113.398 g; chicken is 165 kcal per 100 g.
      expect(breakdown!.single.weightG, closeTo(113.398, 1e-9));
      expect(entries!.single.calories, closeTo(165 * 1.13398, 1e-9));
      await unmount(tester);
    });
  });

  testWidgets('switching on "update meal template" changes the template too', (
    tester,
  ) async {
    final mealId = await tester.runAsync(seedLunchBowl);
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
    await tester.tap(find.text('Meals'));
    await settle(tester);
    await tester.tap(find.text('Lunch bowl'));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('item-weight-0')), '120');
    await tester.tap(find.byKey(const Key('update-template-toggle')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('meal-log-confirm')));
    await settle(tester);

    final template = await tester.runAsync(() => templateItems(mealId!));
    expect(template!.single.link.weightG, 120);
    await unmount(tester);
  });

  testWidgets('a logged meal can add and remove foods for that entry only', (
    tester,
  ) async {
    final mealId = await tester.runAsync(seedLunchBowl);
    await tester.runAsync(
      () => CatalogRepository(db).createFood(
        name: 'White rice',
        perServing: const Macros(
          calories: 130,
          protein: 2.7,
          carbs: 28,
          fat: 0.3,
        ),
        servingWeightG: 100,
      ),
    );
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
    await tester.tap(find.text('Meals'));
    await settle(tester);
    await tester.tap(find.text('Lunch bowl'));
    await settle(tester);

    // Drop the chicken, add rice for this one entry.
    await tester.tap(find.byKey(const Key('item-remove-0')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-meal-item')));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(FoodPickerPage),
        matching: find.text('White rice'),
      ),
    );
    await settle(tester);
    await tester.enterText(find.byKey(const Key('item-weight-0')), '200');
    await settle(tester);
    await tester.tap(find.byKey(const Key('meal-log-confirm')));
    await settle(tester);

    final entries = await tester.runAsync(
      () => db.logDao.watchEntriesForDate(today).first,
    );
    final breakdown = await tester.runAsync(
      () => db.logDao.findEntryItems(entries!.single.id),
    );
    expect(breakdown!.map((i) => i.name), ['White rice']);
    expect(entries!.single.calories, closeTo(260, 1e-9));

    final template = await tester.runAsync(() => templateItems(mealId!));
    expect(template!.map((r) => r.food.name), ['Chicken breast']);
    await unmount(tester);
  });

  testWidgets('a logged meal needs at least one food', (tester) async {
    await tester.runAsync(seedLunchBowl);
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
    await tester.tap(find.text('Meals'));
    await settle(tester);
    await tester.tap(find.text('Lunch bowl'));
    await settle(tester);

    await tester.tap(find.byKey(const Key('item-remove-0')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('meal-log-confirm')));
    await settle(tester);

    expect(find.text('Add at least one food'), findsOneWidget);
    expect(
      await tester.runAsync(() => db.logDao.watchEntriesForDate(today).first),
      isEmpty,
    );
    await unmount(tester);
  });
}
