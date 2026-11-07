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
import 'package:nutriton_project/views/catalog/barcode_scanner_page.dart';
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

  Future<List<FoodLogEntry>> todaysEntries(WidgetTester tester) async =>
      (await tester.runAsync(
        () => db.logDao.watchEntriesForDate(todayKey()).first,
      ))!;

  group('Quick add', () {
    Future<void> openQuickAdd(WidgetTester tester) async {
      await tester.pumpWidget(testApp(db: db, prefs: prefs));
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-food-button')));
      await settle(tester);
      await tester.tap(find.text('Quick add'));
      await settle(tester);
    }

    testWidgets('logs just calories as "Quick add" with zero macros', (
      tester,
    ) async {
      await openQuickAdd(tester);
      await tester.enterText(find.byKey(const Key('quick-calories')), '650');
      await tester.tap(find.byKey(const Key('quick-log')));
      await settle(tester);

      final entry = (await todaysEntries(tester)).single;
      expect(entry.entryType, 'adhoc');
      expect(entry.name, 'Quick add');
      expect(entry.calories, 650);
      expect([entry.protein, entry.carbs, entry.fat], [0, 0, 0]);
      // Back on Home with the entry listed.
      expect(find.text('Quick add'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('keeps a label and any macros typed', (tester) async {
      await openQuickAdd(tester);
      await tester.enterText(find.byKey(const Key('quick-calories')), '480');
      await tester.enterText(find.byKey(const Key('quick-protein')), '30,5');
      await tester.enterText(find.byKey(const Key('quick-label')), 'Pho');
      await tester.tap(find.byKey(const Key('quick-log')));
      await settle(tester);

      final entry = (await todaysEntries(tester)).single;
      expect(entry.name, 'Pho');
      expect(entry.protein, 30.5);
      expect(entry.fat, 0);
      await unmount(tester);
    });

    testWidgets('needs calories and rejects bad macros', (tester) async {
      await openQuickAdd(tester);
      await tester.tap(find.byKey(const Key('quick-log')));
      await settle(tester);
      expect(find.text('Enter a number'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('quick-calories')), '200');
      await tester.enterText(find.byKey(const Key('quick-fat')), '-1');
      await tester.tap(find.byKey(const Key('quick-log')));
      await settle(tester);
      expect(find.text('Cannot be negative'), findsOneWidget);
      expect(await todaysEntries(tester), isEmpty);
      await unmount(tester);
    });
  });

  group('Scan from Add Food', () {
    Future<void> openAddFood(
      WidgetTester tester, {
      required bool supported,
      String? scanned,
      List<String>? looked,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = MockClient((req) async {
        looked?.add(req.url.path);
        return http.Response(
          jsonEncode({
            'status': 1,
            'product': {
              'product_name': 'Soda',
              'brands': 'Fizz',
              'nutriments': {'energy-kcal_100g': 42},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      await tester.pumpWidget(
        testApp(
          db: db,
          prefs: prefs,
          overrides: [
            httpClientProvider.overrideWithValue(client),
            barcodeScanSupportedProvider.overrideWithValue(supported),
            barcodeScannerProvider.overrideWithValue((_) async => scanned),
          ],
        ),
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-food-button')));
      await settle(tester);
    }

    testWidgets('has no scan button where the camera is not supported', (
      tester,
    ) async {
      await openAddFood(tester, supported: false);
      expect(find.byKey(const Key('catalog-scan')), findsNothing);
      await unmount(tester);
    });

    testWidgets('a catalog food goes straight to logging, with no network', (
      tester,
    ) async {
      await tester.runAsync(
        () => CatalogRepository(db).createFood(
          name: 'Cola',
          perServing: const Macros(calories: 140),
          servingWeightG: 330,
          barcode: '4006381333931',
        ),
      );
      final looked = <String>[];
      await openAddFood(
        tester,
        supported: true,
        scanned: '4006381333931',
        looked: looked,
      );

      await tester.tap(find.byKey(const Key('catalog-scan')));
      await settle(tester);
      expect(find.byKey(const Key('log-food-confirm')), findsOneWidget);
      expect(looked, isEmpty);

      await tester.tap(find.byKey(const Key('log-food-confirm')));
      await settle(tester);
      expect((await todaysEntries(tester)).single.name, 'Cola');
      await unmount(tester);
    });

    testWidgets('an unknown code opens New Food prefilled from the lookup', (
      tester,
    ) async {
      final looked = <String>[];
      await openAddFood(
        tester,
        supported: true,
        scanned: '5000112637922',
        looked: looked,
      );

      await tester.tap(find.byKey(const Key('catalog-scan')));
      await settle(tester);
      expect(looked, ['/api/v2/product/5000112637922.json']);

      String field(String key) => tester
          .widget<CupertinoTextField>(find.byKey(Key(key)))
          .controller!
          .text;
      expect(field('food-name'), 'Soda');
      expect(field('food-brand'), 'Fizz');
      expect(field('food-barcode'), '5000112637922');

      await tester.tap(find.byKey(const Key('food-save')));
      await settle(tester);
      // Save & Log goes on to the servings screen.
      await tester.tap(find.byKey(const Key('log-food-confirm')));
      await settle(tester);
      expect((await todaysEntries(tester)).single.name, 'Soda');
      final food = await tester.runAsync(
        () => CatalogRepository(db).findFoodByBarcode('5000112637922'),
      );
      expect(food!.brand, 'Fizz');
      await unmount(tester);
    });

    testWidgets('a cancelled scan changes nothing', (tester) async {
      await openAddFood(tester, supported: true);
      await tester.tap(find.byKey(const Key('catalog-scan')));
      await settle(tester);
      expect(find.text('Add Food'), findsOneWidget);
      expect(find.text('New Food'), findsNothing);
      await unmount(tester);
    });
  });
}
