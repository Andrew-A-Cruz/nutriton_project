import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/label_scan.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/providers/infrastructure_providers.dart';
import 'package:nutriton_project/providers/label_scan_providers.dart';
import 'package:nutriton_project/views/catalog/food_form_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_label_scanner.dart';
import '../support/test_app.dart';

List<OcrLine> fixture(String name) => [
  for (final m
      in jsonDecode(File('test/fixtures/labels/$name.json').readAsStringSync())
          as List)
    OcrLine.fromMap(m)!,
];

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'display_unit': 'g',
      'tracked_metrics': ['calories', 'fiber', 'sugar', 'sodium'],
    });
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> open(
    WidgetTester tester, {
    FakeLabelScanner? scanner,
    FoodItem? existing,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (scanner != null) labelScannerProvider.overrideWithValue(scanner),
        ],
        child: CupertinoApp(home: FoodFormView(existing: existing)),
      ),
    );
    await settle(tester);
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<CupertinoTextField>(find.byKey(Key(key))).controller!.text;

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
  }

  testWidgets('a US label fills the nutrition and the serving weight', (
    tester,
  ) async {
    final scanner = FakeLabelScanner(lines: fixture('us_cereal'));
    await open(tester, scanner: scanner);
    await tester.enterText(find.byKey(const Key('food-name')), 'Granola');

    await tap(tester, 'label-scan-camera');

    expect(scanner.asked, [LabelPhotoSource.camera]);
    expect(text(tester, 'food-calories'), '230');
    expect(text(tester, 'food-protein'), '3');
    expect(text(tester, 'food-carbs'), '37');
    expect(text(tester, 'food-fat'), '8');
    expect(text(tester, 'food-fiber'), '4');
    expect(text(tester, 'food-sugar'), '12');
    expect(text(tester, 'food-sodium'), '160');
    expect(text(tester, 'food-serving-weight'), '55');
    // The name typed before the scan stays.
    expect(text(tester, 'food-name'), 'Granola');
    expect(
      find.text(
        'Filled from the label, per serving. Check every value against '
        'the label.',
      ),
      findsOneWidget,
    );

    // The values are only a prefill: saving stores what the form shows.
    await tap(tester, 'food-save');
    final food = (await db.select(db.foodItems).get()).single;
    expect(food.name, 'Granola');
    expect(food.calories, 230);
    expect(food.servingWeightG, 55);
    expect(food.sodium, 160);
    await unmount(tester);
  });

  testWidgets('a per 100 g label says so and sets 100 g', (tester) async {
    final scanner = FakeLabelScanner(lines: fixture('eu_per_100_comma'));
    await open(tester, scanner: scanner);

    await tap(tester, 'label-scan-library');

    expect(scanner.asked, [LabelPhotoSource.library]);
    expect(text(tester, 'food-calories'), '250');
    expect(text(tester, 'food-fat'), '9.5');
    expect(text(tester, 'food-serving-weight'), '100');
    expect(find.textContaining('per 100 g.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('what the label lacks is named and left as it was', (
    tester,
  ) async {
    final scanner = FakeLabelScanner(
      lines: const [
        OcrLine(
          text: 'Calories 120',
          x1: 0,
          y1: 10,
          x2: 200,
          y2: 10,
          height: 20,
        ),
        OcrLine(
          text: 'Total Carbohydrate 20g',
          x1: 0,
          y1: 50,
          x2: 300,
          y2: 50,
          height: 20,
        ),
      ],
    );
    await open(tester, scanner: scanner);
    await tester.enterText(find.byKey(const Key('food-protein')), '7');

    await tap(tester, 'label-scan-camera');

    expect(text(tester, 'food-calories'), '120');
    expect(text(tester, 'food-carbs'), '20');
    expect(text(tester, 'food-protein'), '7');
    expect(text(tester, 'food-fat'), '');
    expect(text(tester, 'food-serving-weight'), '');
    expect(
      find.textContaining('Not found: protein, fat, serving weight.'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('a photo with no label says so and changes nothing', (
    tester,
  ) async {
    final scanner = FakeLabelScanner(
      lines: const [
        OcrLine(
          text: 'Best before 2027',
          x1: 0,
          y1: 10,
          x2: 200,
          y2: 10,
          height: 20,
        ),
      ],
    );
    await open(tester, scanner: scanner);
    await tester.enterText(find.byKey(const Key('food-calories')), '99');

    await tap(tester, 'label-scan-camera');

    expect(find.byKey(const Key('label-scan-message')), findsOneWidget);
    expect(text(tester, 'food-calories'), '99');
    expect(find.byKey(const Key('lookup-notice')), findsNothing);
    await unmount(tester);
  });

  testWidgets('cancelling the photo changes nothing and shows no error', (
    tester,
  ) async {
    await open(tester, scanner: FakeLabelScanner());

    await tap(tester, 'label-scan-camera');

    expect(find.byKey(const Key('label-scan-message')), findsNothing);
    expect(text(tester, 'food-calories'), '');
    await unmount(tester);
  });

  testWidgets('a recognizer failure is reported, not thrown', (tester) async {
    await open(tester, scanner: FakeLabelScanner(error: StateError('boom')));

    await tap(tester, 'label-scan-camera');

    expect(find.text('Could not read the label. Try again.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the section is hidden where photos cannot be read', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('label-scan-camera')), findsNothing);
    await unmount(tester);
  });

  testWidgets('the section is for new foods only', (tester) async {
    late FoodItem food;
    await tester.runAsync(() async {
      await db
          .into(db.foodItems)
          .insert(
            FoodItemsCompanion.insert(
              id: 'f1',
              name: 'Oats',
              calories: 150,
              protein: 5,
              carbs: 27,
              fat: 3,
              servingWeightG: 40,
            ),
          );
      food = (await db.select(db.foodItems).get()).single;
    });
    await open(tester, scanner: FakeLabelScanner(), existing: food);

    expect(find.byKey(const Key('label-scan-camera')), findsNothing);
    await unmount(tester);
  });
}
