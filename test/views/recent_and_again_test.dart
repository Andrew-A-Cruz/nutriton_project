import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/views/add_food/log_food_view.dart';
import 'package:nutriton_project/views/home/undo_banner.dart';
import 'package:nutriton_project/views/meals/meal_log_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late CatalogRepository catalog;
  late LogRepository log;
  late String today;
  late String yesterday;

  setUp(() async {
    today = todayKey();
    yesterday = addDays(today, -1);
    db = AppDatabase(NativeDatabase.memory());
    catalog = CatalogRepository(db);
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

  Future<FoodItem> food(String name, {double calories = 100}) async {
    final id = await catalog.createFood(
      name: name,
      perServing: Macros(calories: calories, protein: 10, carbs: 10, fat: 1),
      servingWeightG: 100,
    );
    return (await catalog.findFood(id))!;
  }

  Future<void> openAddFood(WidgetTester tester) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
  }

  double leftOf(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dx;

  /// Also hides the Undo banner, so no timer is left pending.
  Future<void> finish(WidgetTester tester) async {
    hideUndoBanner();
    await unmount(tester);
  }

  group('Add Food: recent and frequent', () {
    testWidgets('the toggle switches between newest and most often', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final chicken = await food('Chicken');
        final rice = await food('Rice');
        for (var i = 0; i < 3; i++) {
          await log.logFood(logDate: yesterday, food: chicken, servings: 1);
        }
        await log.logFood(logDate: yesterday, food: rice, servings: 1);
      });
      await openAddFood(tester);

      final chicken = find.byWidgetPredicate(
        (w) =>
            w.key.toString().contains('recent-food-') && _hasText(w, 'Chicken'),
      );
      final rice = find.byWidgetPredicate(
        (w) => w.key.toString().contains('recent-food-') && _hasText(w, 'Rice'),
      );
      expect(chicken, findsOneWidget);
      // Recent: Rice was logged last, so it comes first.
      expect(leftOf(tester, rice), lessThan(leftOf(tester, chicken)));

      await tester.tap(find.text('Frequent'));
      await settle(tester);
      expect(leftOf(tester, chicken), lessThan(leftOf(tester, rice)));

      await tester.tap(find.text('Recent'));
      await settle(tester);
      expect(leftOf(tester, rice), lessThan(leftOf(tester, chicken)));
      await finish(tester);
    });

    testWidgets('Frequent says so when nothing was logged lately', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final chicken = await food('Chicken');
        await log.logFood(
          logDate: addDays(today, -40),
          food: chicken,
          servings: 1,
        );
      });
      await openAddFood(tester);

      expect(find.byKey(const Key('recent-foods')), findsOneWidget);
      expect(find.byKey(const Key('recent-empty')), findsNothing);
      await tester.tap(find.text('Frequent'));
      await settle(tester);
      expect(find.byKey(const Key('recent-empty')), findsOneWidget);
      await tester.tap(find.text('Recent'));
      await settle(tester);
      expect(find.byKey(const Key('recent-empty')), findsNothing);
      await finish(tester);
    });

    testWidgets('a meal shows up and opens the meal flow', (tester) async {
      late String mealId;
      await tester.runAsync(() async {
        final chicken = await food('Chicken');
        mealId = await catalog.createMeal(
          name: 'Chicken bowl',
          items: [MealItemInput(foodItemId: chicken.id, weightG: 100)],
        );
        await log.logMeal(
          logDate: yesterday,
          meal: (await catalog.findMeal(mealId))!,
          items: [MealItemInput(foodItemId: chicken.id, weightG: 100)],
        );
      });
      await openAddFood(tester);

      final chip = find.byKey(Key('recent-meal-$mealId'));
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await settle(tester);
      expect(find.byType(MealLogView), findsOneWidget);
      await finish(tester);
    });

    testWidgets('the strip is hidden while searching', (tester) async {
      await tester.runAsync(() async {
        await log.logFood(
          logDate: yesterday,
          food: await food('Chicken'),
          servings: 1,
        );
      });
      await openAddFood(tester);

      expect(find.byKey(const Key('recent-ranking')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('catalog-search')), 'chi');
      await settle(tester);
      expect(find.byKey(const Key('recent-ranking')), findsNothing);
      expect(find.byKey(const Key('recent-foods')), findsNothing);
      await finish(tester);
    });
  });

  group('Add Food: servings prefill', () {
    String amount(WidgetTester tester) => tester
        .widget<CupertinoTextField>(find.byKey(const Key('log-amount')))
        .controller!
        .text;

    testWidgets('a recent food starts from the amount used last time', (
      tester,
    ) async {
      late FoodItem chicken;
      await tester.runAsync(() async {
        chicken = await food('Chicken');
        await log.logFood(logDate: yesterday, food: chicken, servings: 1);
        await log.logFood(logDate: yesterday, food: chicken, servings: 2.5);
      });
      await openAddFood(tester);

      await tester.tap(find.byKey(Key('recent-food-${chicken.id}')));
      await settle(tester);

      expect(find.byType(LogFoodView), findsOneWidget);
      expect(amount(tester), '2.5');
      expect(
        tester.widget<Text>(find.byKey(const Key('log-servings'))).data,
        '2.5 servings',
      );
      await finish(tester);
    });

    testWidgets('a food picked from the catalog list is prefilled too', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await log.logFood(
          logDate: yesterday,
          food: await food('Chicken'),
          servings: 3,
        );
      });
      await openAddFood(tester);

      await tester.enterText(find.byKey(const Key('catalog-search')), 'chi');
      await settle(tester);
      await tester.tap(find.text('Chicken'));
      await settle(tester);

      expect(amount(tester), '3');
      await finish(tester);
    });

    testWidgets('a food never logged starts at one serving', (tester) async {
      await tester.runAsync(() async {
        await food('Chicken');
      });
      await openAddFood(tester);

      await tester.tap(find.text('Chicken'));
      await settle(tester);

      expect(amount(tester), '1');
      await finish(tester);
    });

    testWidgets('logging with the prefilled amount saves it', (tester) async {
      await tester.runAsync(() async {
        await log.logFood(
          logDate: yesterday,
          food: await food('Chicken'),
          servings: 2,
        );
      });
      await openAddFood(tester);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w.key.toString().contains('recent-food-'),
        ),
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('log-food-confirm')));
      await settle(tester);

      final entries = await tester.runAsync(
        () => db.logDao.findEntriesForDate(today),
      );
      expect(entries!.single.servings, 2);
      expect(entries.single.calories, 200);
      await finish(tester);
    });
  });

  group('Log again today', () {
    Future<void> goToYesterday(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('previous-day')));
      await settle(tester);
    }

    testWidgets('copies a past entry onto today, with Undo', (tester) async {
      await tester.runAsync(() async {
        await log.logFood(
          logDate: yesterday,
          food: await food('Chicken'),
          servings: 2,
        );
      });
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await goToYesterday(tester);

      await tester.longPress(find.text('Chicken'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('log-again-today')));
      await settle(tester);

      expect(find.text('Logged again today'), findsOneWidget);
      var todays = await tester.runAsync(
        () => db.logDao.findEntriesForDate(today),
      );
      expect(todays!.single.servings, 2);
      expect(todays.single.calories, 200);
      // The entry on yesterday stays, and Home is still on yesterday.
      final past = await tester.runAsync(
        () => db.logDao.findEntriesForDate(yesterday),
      );
      expect(past, hasLength(1));
      expect(find.text('Yesterday'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      todays = await tester.runAsync(() => db.logDao.findEntriesForDate(today));
      expect(todays, isEmpty);
      await finish(tester);
    });

    testWidgets('copies a meal with its breakdown', (tester) async {
      await tester.runAsync(() async {
        final chicken = await food('Chicken');
        final rice = await food('Rice');
        final mealId = await catalog.createMeal(
          name: 'Bowl',
          items: [
            MealItemInput(foodItemId: chicken.id, weightG: 100),
            MealItemInput(foodItemId: rice.id, weightG: 200),
          ],
        );
        await log.logMeal(
          logDate: yesterday,
          meal: (await catalog.findMeal(mealId))!,
          items: [
            MealItemInput(foodItemId: chicken.id, weightG: 100),
            MealItemInput(foodItemId: rice.id, weightG: 200),
          ],
        );
      });
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await goToYesterday(tester);

      await tester.longPress(find.text('Bowl'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('log-again-today')));
      await settle(tester);

      final copied = await tester.runAsync(() async {
        final entry = (await db.logDao.findEntriesForDate(today)).single;
        return db.logDao.findEntryItems(entry.id);
      });
      expect(copied, hasLength(2));
      await finish(tester);
    });

    testWidgets('is not offered for an entry that is already on today', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await log.logFood(
          logDate: today,
          food: await food('Chicken'),
          servings: 1,
        );
      });
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      await tester.longPress(find.text('Chicken'));
      await settle(tester);

      expect(find.text('Move to another day'), findsOneWidget);
      expect(find.byKey(const Key('log-again-today')), findsNothing);
      await finish(tester);
    });
  });

  group('Copy from…', () {
    testWidgets('copies the day before onto the day shown', (tester) async {
      await tester.runAsync(() async {
        final chicken = await food('Chicken');
        await log.logFood(logDate: yesterday, food: chicken, servings: 1);
        await log.logAdhoc(
          logDate: yesterday,
          name: 'Cake',
          macros: const Macros(calories: 300, protein: 3, carbs: 40, fat: 10),
        );
        // Today already has an entry; copying keeps it.
        await log.logFood(logDate: today, food: chicken, servings: 4);
      });
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      await tester.tap(find.byKey(const Key('copy-from-button')));
      await settle(tester);
      expect(find.text('Copy from…'), findsOneWidget);
      expect(find.text('2 entries on this day.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('copy-day-confirm')));
      await settle(tester);

      expect(find.text('Copy from…'), findsNothing);
      final entries = await tester.runAsync(
        () => db.logDao.findEntriesForDate(today),
      );
      expect(
        [for (final e in entries!) e.name],
        ['Chicken', 'Chicken', 'Cake'],
      );
      expect(find.text('Cake'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('an empty day cannot be copied', (tester) async {
      await tester.runAsync(() async {
        await log.logFood(
          logDate: addDays(today, -2),
          food: await food('Chicken'),
          servings: 1,
        );
      });
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);

      await tester.tap(find.byKey(const Key('copy-from-button')));
      await settle(tester);

      // The picker starts on yesterday, which has nothing.
      expect(find.text('Nothing logged on this day.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('copy-day-confirm')));
      await settle(tester);
      expect(find.text('Copy from…'), findsOneWidget);
      final entries = await tester.runAsync(
        () => db.logDao.findEntriesForDate(today),
      );
      expect(entries, isEmpty);

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Copy from…'), findsNothing);
      await finish(tester);
    });

    testWidgets('starts one day before the day being shown', (tester) async {
      await tester.runAsync(() async {
        final chicken = await food('Chicken');
        await log.logFood(
          logDate: addDays(today, -2),
          food: chicken,
          servings: 1,
        );
      });
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await tester.tap(find.byKey(const Key('previous-day')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('copy-from-button')));
      await settle(tester);
      expect(find.text('1 entry on this day.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('copy-day-confirm')));
      await settle(tester);

      final entries = await tester.runAsync(
        () => db.logDao.findEntriesForDate(yesterday),
      );
      expect(entries!.single.name, 'Chicken');
      // Today, which was never selected, is untouched.
      final todays = await tester.runAsync(
        () => db.logDao.findEntriesForDate(today),
      );
      expect(todays, isEmpty);
      await finish(tester);
    });
  });
}

/// True if [w] or something under it shows exactly [text].
bool _hasText(Widget w, String text) {
  if (w is Text) return w.data == text;
  if (w is CupertinoButton && w.child is Text) {
    return (w.child as Text).data == text;
  }
  return false;
}
