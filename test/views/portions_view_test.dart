import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/providers/food_lookup_providers.dart';
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
      'primary_metric': 'calories',
      'display_unit': 'g',
    });
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> addOats(WidgetTester tester, {bool withCup = true}) async =>
      (await tester.runAsync(() async {
        final catalog = CatalogRepository(db);
        final id = await catalog.createFood(
          name: 'Oats',
          perServing: const Macros(
            calories: 150,
            protein: 5,
            carbs: 27,
            fat: 3,
          ),
          servingWeightG: 40,
        );
        if (withCup) await catalog.addServing(id, name: 'cup', weightG: 80);
        return id;
      }))!;

  testWidgets('logging by a portion converts it to servings', (tester) async {
    tester.view.physicalSize = const Size(2400, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    await addOats(tester);
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-food-button')));
    await settle(tester);
    await tester.tap(find.text('Oats').last);
    await settle(tester);

    await tester.tap(find.text('cup (80 g)'));
    await tester.pump();
    // One serving (40 g) is half a cup.
    expect(
      tester
          .widget<CupertinoTextField>(find.byKey(const Key('log-amount')))
          .controller!
          .text,
      '0.5',
    );
    await tester.enterText(find.byKey(const Key('log-amount')), '1.5');
    await tester.pump();
    await tester.tap(find.byKey(const Key('log-food-confirm')));
    await settle(tester);

    final entry = (await tester.runAsync(
      () => db.logDao.findEntriesForDate(todayKey()),
    ))!.single;
    expect(entry.servings, 3);
    expect(entry.calories, 450);
    await unmount(tester);
  });

  testWidgets('a saved food gains a portion from the form', (tester) async {
    tester.view.physicalSize = const Size(2400, 5000);
    addTearDown(tester.view.resetPhysicalSize);
    final id = await addOats(tester, withCup: false);
    final food = (await tester.runAsync(
      () => CatalogRepository(db).findFood(id),
    ))!;
    await tester.pumpWidget(
      testScreen(
        db: db,
        prefs: prefs,
        home: FoodFormView(existing: food),
      ),
    );
    await settle(tester);

    await tester.tap(find.byKey(const Key('portion-add')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('portion-name')), 'scoop');
    await tester.enterText(find.byKey(const Key('portion-weight')), '30');
    await tester.tap(find.byKey(const Key('portion-add-confirm')));
    await settle(tester);

    expect(find.text('scoop'), findsOneWidget);
    expect(find.text('30 g'), findsOneWidget);
    final saved = (await tester.runAsync(
      () => db.select(db.foodServings).get(),
    ))!;
    expect(saved.single.weightG, 30);
    await unmount(tester);
  });

  testWidgets('a looked-up food saves its label portion', (tester) async {
    tester.view.physicalSize = const Size(2400, 5000);
    addTearDown(tester.view.resetPhysicalSize);
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'products': [
            {
              'product_name': 'Granola',
              'serving_quantity': 60,
              'serving_size': '2/3 cup (60 g)',
              'nutriments': {'energy-kcal_100g': 450},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await tester.pumpWidget(
      testScreen(
        db: db,
        prefs: prefs,
        home: const FoodFormView(),
        overrides: [httpClientProvider.overrideWithValue(client)],
      ),
    );
    await settle(tester);
    await tester.enterText(find.byKey(const Key('lookup-query')), 'granola');
    await tester.tap(find.byKey(const Key('lookup-query-go')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('lookup-result-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('food-save')));
    await settle(tester);

    final saved = (await tester.runAsync(
      () => db.select(db.foodServings).get(),
    ))!;
    expect(saved.single.name, 'cup');
    expect(saved.single.weightG, 90); // 60 g is two thirds of a cup
    await unmount(tester);
  });
}
