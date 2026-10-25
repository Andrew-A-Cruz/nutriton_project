import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/meal_slot.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/body_weight_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/views/catalog/food_form_view.dart';
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
    // Body weight: the Home row and the Summary chart.
    final weights = BodyWeightRepository(db);
    await weights.setWeight(todayKey(), 1234.5 / 10);
    await weights.setWeight(addDays(todayKey(), -1), 124.1);
  }

  testWidgets('Home and Summary fit at 2x text in dark mode', (tester) async {
    stressScreen(tester);
    await tester.runAsync(seed);
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);

    expect(find.text('Food Log'), findsOneWidget);
    // At 2x text the row sits below the first screenful.
    await tester.dragUntilVisible(
      find.byKey(const Key('weigh-in-value')),
      find.byType(CustomScrollView),
      const Offset(0, -100),
    );
    await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
    await settle(tester);
    for (final segment in ['Day', 'Week', 'Month', '6M', 'Year']) {
      await tester.tap(find.text(segment).last);
      await settle(tester);
      if (segment != 'Day') {
        expect(find.byKey(const Key('weight-chart')), findsOneWidget);
      }
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

  testWidgets('sodium, fiber and sugar fit at 2x text', (tester) async {
    stressScreen(tester);
    final allMetrics = await tester.runAsync(
      () => mockPreferences({
        'onboarding_complete': true,
        'primary_metric': 'calories',
        'tracked_metrics': [for (final m in Metric.values) m.name],
        'goal_calories': 2000.0,
        'goal_sodium': 2300.0,
        'goal_fiber': 30.0,
      }),
    );
    await tester.runAsync(() async {
      final log = LogRepository(db);
      for (var i = 0; i < 5; i++) {
        await log.logAdhoc(
          logDate: todayKey(),
          name: 'Snack $i',
          macros: Macros(
            calories: 100,
            protein: 1,
            carbs: 10,
            fat: 2,
            fiber: i < 3 ? 2 : null,
            sugar: i < 3 ? 4 : null,
            sodium: i < 3 ? 410 : null,
          ),
        );
      }
    });
    await tester.pumpWidget(testApp(db: db, prefs: allMetrics!));
    await settle(tester);
    await tester.dragUntilVisible(
      find.byKey(const Key('coverage-sodium')),
      find.byType(CustomScrollView).first,
      const Offset(0, -100),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
    await settle(tester);
    expect(find.byKey(const Key('average-sodium')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('New and Edit Food fit at 2x text', (tester) async {
    stressScreen(tester);
    final allMetrics = await tester.runAsync(
      () => mockPreferences({
        'onboarding_complete': true,
        'primary_metric': 'calories',
        'tracked_metrics': [for (final m in Metric.values) m.name],
      }),
    );
    final food = await tester.runAsync(() async {
      final catalog = CatalogRepository(db);
      final id = await catalog.createFood(
        name: 'A very long food name that should wrap cleanly onto more lines',
        perServing: const Macros(
          calories: 1234.5,
          protein: 80.25,
          carbs: 120,
          fat: 40.75,
          fiber: 12.5,
          sugar: 30,
          sodium: 2300,
        ),
        servingWeightG: 250,
        barcode: '01234567890128',
      );
      return catalog.findFood(id);
    });

    for (final existing in [null, food]) {
      await tester.pumpWidget(
        testScreen(
          db: db,
          prefs: allMetrics!,
          home: FoodFormView(existing: existing),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      // Scroll to the end so every row is built and laid out.
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      await unmount(tester);
    }
  });
}
