import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/meal_slot.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/views/common/meal_slot_picker.dart';
import 'package:nutriton_project/views/tour/app_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

/// Layout checks at a phone size with 2x text and dark mode. A RenderFlex
/// overflow fails a widget test, so these tests pass only if nothing overflows.
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories', 'protein', 'carbs', 'fat'],
      'goal_calories': 2000.0,
      'goal_protein': 150.0,
      'goal_carbs': 250.0,
      'goal_fat': 70.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  /// iPhone-sized screen, 2x text and dark mode, cleared after the test.
  void stressScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }

  Future<void> seed() async {
    final log = LogRepository(db);
    await log.logAdhoc(
      logDate: todayKey(),
      name: 'A very long food name that should wrap cleanly onto more lines',
      macros: const Macros(
        calories: 1234.5,
        protein: 80.25,
        carbs: 120,
        fat: 40.75,
      ),
    );
    await log.logAdhoc(
      logDate: addDays(todayKey(), -1),
      name: 'Yesterday',
      macros: const Macros(calories: 800, protein: 20, carbs: 60, fat: 10),
    );
  }

  testWidgets('Home and Summary fit at 2x text in dark mode', (tester) async {
    stressScreen(tester);
    await tester.runAsync(seed);
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    expect(find.text('Food Log'), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
    await settle(tester);
    for (final segment in ['Day', 'Week', 'Month', '6M', 'Year']) {
      await tester.tap(find.text(segment).last);
      await settle(tester);
    }
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('secondary labels use the dark-mode color', (tester) async {
    stressScreen(tester);
    await tester.runAsync(seed);
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    final dark = CupertinoColors.secondaryLabel.darkColor;
    Color? colorOf(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).style?.color;

    expect(colorOf('primary-remaining'), isSameColorAs(dark));

    await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
    await settle(tester);
    expect(colorOf('days-logged'), isSameColorAs(dark));
    await unmount(tester);
  });

  testWidgets('Settings fits at 2x text in dark mode', (tester) async {
    stressScreen(tester);
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('onboarding fits at 2x text in dark mode', (tester) async {
    stressScreen(tester);
    final onboardingPrefs = await tester.runAsync(() => mockPreferences({}));
    await tester.pumpWidget(testApp(db: db, prefs: onboardingPrefs!));
    await settle(tester);

    // Every welcome page, then the setup form.
    for (var i = 0; i < 5; i++) {
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('welcome-next')));
      await settle(tester);
    }
    expect(find.text('Set up Nutriton'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('every tour step fits at 2x text in dark mode', (tester) async {
    stressScreen(tester);
    // Not onboarded yet, with the goal filled in: at 2x text its field is
    // below the fold and not built.
    final onboardingPrefs = await tester.runAsync(
      () => mockPreferences({'goal_calories': 2000.0}),
    );
    await tester.pumpWidget(testApp(db: db, prefs: onboardingPrefs!));
    await settle(tester);
    await skipWelcome(tester);
    await tapSubmitPreferences(tester);
    await settle(tester);

    for (var i = 0; i < tourSteps.length; i++) {
      expect(tester.takeException(), isNull);
      // Next must be on screen at every step: a missed tap leaves the card up.
      await tester.tap(find.byKey(const Key('tour-next')));
      await settle(tester);
    }
    expect(find.byKey(const Key('tour-card')), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('meal slot picker and Home sections fit at 2x text', (
    tester,
  ) async {
    stressScreen(tester);
    late FoodItem food;
    await tester.runAsync(() async {
      final catalog = CatalogRepository(db);
      final id = await catalog.createFood(
        name: 'Rice',
        perServing: const Macros(calories: 130, protein: 3, carbs: 28, fat: 1),
        servingWeightG: 100,
      );
      food = (await catalog.findFood(id))!;
      final log = LogRepository(db);
      for (final slot in [...MealSlot.values, null]) {
        await log.logFood(
          logDate: todayKey(),
          food: food,
          servings: 1,
          mealSlot: slot,
        );
      }
    });
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
    await tester.dragUntilVisible(
      find.byKey(const Key('section-other')),
      find.byType(CustomScrollView).first,
      const Offset(0, -200),
    );
    expect(tester.takeException(), isNull);

    // The servings dialog carries the picker too, in its compact layout.
    await tester.dragUntilVisible(
      find.text('Rice').first,
      find.byType(CustomScrollView).first,
      const Offset(0, 200),
    );
    await tester.tap(find.text('Rice').first);
    await settle(tester);
    expect(find.byType(MealSlotPicker), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await unmount(tester);

    // The logging screens' section on its own: all four labels are there.
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: ListView(
            children: [MealSlotFormSection(value: null, onChanged: (_) {})],
          ),
        ),
      ),
    );
    await tester.pump();
    for (final slot in MealSlot.values) {
      expect(find.text(slot.label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
