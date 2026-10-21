import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
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

  /// Chicken logged yesterday (so it is also a recent food).
  Future<void> seedYesterday() async {
    final catalog = CatalogRepository(db);
    final id = await catalog.createFood(
      name: 'Chicken breast',
      perServing: const Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6),
      servingWeightG: 100,
    );
    await LogRepository(db).logFood(
      logDate: yesterday,
      food: (await catalog.findFood(id))!,
      servings: 1,
    );
  }

  testWidgets('Copy yesterday fills an empty day', (tester) async {
    await tester.runAsync(seedYesterday);
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    expect(find.text('Nothing logged yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('copy-previous-day')));
    await settle(tester);

    expect(find.text('Copy yesterday'), findsNothing);
    expect(find.text('Chicken breast'), findsOneWidget);
    final entries = await tester.runAsync(
      () => db.logDao.findEntriesForDate(today),
    );
    expect(entries!.single.calories, 165);
    await unmount(tester);
  });

  testWidgets('no copy button when the day before is empty', (tester) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(find.byKey(const Key('copy-previous-day')), findsNothing);
    await unmount(tester);
  });

  testWidgets('Add Food shows recent foods and tapping one opens it', (
    tester,
  ) async {
    await tester.runAsync(seedYesterday);
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);

    expect(find.byKey(const Key('recent-foods')), findsOneWidget);
    final chip = find.descendant(
      of: find.byKey(const Key('recent-foods')),
      matching: find.text('Chicken breast'),
    );
    expect(chip, findsOneWidget);

    // Searching hides the strip.
    await tester.enterText(find.byKey(const Key('catalog-search')), 'chi');
    await settle(tester);
    expect(find.byKey(const Key('recent-foods')), findsNothing);

    await tester.enterText(find.byKey(const Key('catalog-search')), '');
    await settle(tester);
    await tester.tap(chip);
    await settle(tester);
    expect(find.byKey(const Key('log-food-confirm')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('no recent strip before anything was logged', (tester) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
    expect(find.byKey(const Key('recent-foods')), findsNothing);
    await unmount(tester);
  });
}
