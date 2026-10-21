import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/views/catalog/food_form_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'display_unit': 'g',
    });
  });

  tearDown(() async {
    await db.close();
  });

  /// The form opened from a page, so a save can pop back to it.
  Future<void> openForm(WidgetTester tester) async {
    await tester.pumpWidget(
      testScreen(
        db: db,
        prefs: prefs,
        home: RouteHost(route: (_) => const FoodFormView()),
      ),
    );
    await tester.tap(find.byKey(const Key('open-route')));
    await settle(tester);
  }

  Future<void> fill(
    WidgetTester tester, {
    String name = 'Chicken breast',
    String calories = '165',
    String protein = '31',
    String carbs = '0',
    String fat = '3.6',
    String weight = '100',
  }) async {
    await tester.enterText(find.byKey(const Key('food-name')), name);
    await tester.enterText(find.byKey(const Key('food-calories')), calories);
    await tester.enterText(find.byKey(const Key('food-protein')), protein);
    await tester.enterText(find.byKey(const Key('food-carbs')), carbs);
    await tester.enterText(find.byKey(const Key('food-fat')), fat);
    await tester.enterText(
      find.byKey(const Key('food-serving-weight')),
      weight,
    );
  }

  testWidgets('an empty form shows every required error and saves nothing', (
    tester,
  ) async {
    await openForm(tester);

    await tester.tap(find.byKey(const Key('food-save')));
    await settle(tester);

    expect(find.text('Enter a name (at least 2 characters)'), findsOneWidget);
    // Four macros and the serving weight.
    expect(find.text('Enter a number'), findsNWidgets(5));
    final foods = await tester.runAsync(() => db.foodDao.findActive());
    expect(foods, isEmpty);
    await unmount(tester);
  });

  testWidgets('negative macros and a zero serving weight are rejected', (
    tester,
  ) async {
    await openForm(tester);

    await fill(tester, calories: '-5', weight: '0');
    await tester.tap(find.byKey(const Key('food-save')));
    await settle(tester);

    expect(find.text('Cannot be negative'), findsOneWidget);
    expect(find.text('Enter a number greater than 0'), findsOneWidget);
    expect(find.text('Enter a name (at least 2 characters)'), findsNothing);
    final foods = await tester.runAsync(() => db.foodDao.findActive());
    expect(foods, isEmpty);
    await unmount(tester);
  });

  testWidgets('a valid form saves the food and pops back', (tester) async {
    await openForm(tester);

    await fill(tester);
    await tester.tap(find.byKey(const Key('food-save')));
    await settle(tester);

    expect(find.byKey(const Key('food-name')), findsNothing);
    final foods = await tester.runAsync(() => db.foodDao.findActive());
    expect(foods!.single.name, 'Chicken breast');
    expect(foods.single.calories, 165);
    expect(foods.single.servingWeightG, 100);
    await unmount(tester);
  });

  testWidgets('a serving weight entered in ounces is stored in grams', (
    tester,
  ) async {
    await openForm(tester);

    // Switch to ounces first, then type 4 oz.
    await tester.tap(find.text('oz'));
    await settle(tester);
    await fill(tester, weight: '4');
    await tester.tap(find.byKey(const Key('food-save')));
    await settle(tester);

    final foods = await tester.runAsync(() => db.foodDao.findActive());
    expect(foods!.single.servingWeightG, closeTo(113.398, 1e-6));
    expect(foods.single.displayUnit, 'oz');
    await unmount(tester);
  });
}
