import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/body_weight_repository.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/views/common/wide_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/menu_fixture.dart';
import '../support/test_app.dart';

/// The two-pane layouts on an iPad or a phone on its side.
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late String today;

  setUp(() async {
    wideLayoutMinWidth = defaultWideLayoutMinWidth;
    today = todayKey();
    db = AppDatabase(NativeDatabase.memory());
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories', 'protein'],
      'goal_calories': 2000.0,
    });
  });

  tearDown(() async {
    wideLayoutMinWidth = double.infinity;
    await db.close();
  });

  void screen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  const ipad = Size(1024, 768);
  const ipadPortrait = Size(768, 1024);
  const phoneLandscape = Size(932, 430);
  const phone = Size(390, 844);

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(testApp(db: db, prefs: prefs));
    await settle(tester);
  }

  Future<String> addRice() => CatalogRepository(db).createFood(
    name: 'Rice',
    perServing: const Macros(calories: 130, protein: 3, carbs: 28),
    servingWeightG: 100,
  );

  group('Home', () {
    testWidgets('a phone keeps the + button and no pane', (tester) async {
      screen(tester, phone);
      await pumpApp(tester);

      expect(find.byKey(const Key('add-food-button')), findsOneWidget);
      expect(find.byKey(const Key('catalog-search')), findsNothing);
      await unmount(tester);
    });

    for (final (name, size) in [
      ('an iPad', ipad),
      ('an iPad upright', ipadPortrait),
      ('a phone on its side', phoneLandscape),
    ]) {
      testWidgets('$name shows Add Food beside the day', (tester) async {
        screen(tester, size);
        await pumpApp(tester);

        expect(find.byKey(const Key('add-food-button')), findsNothing);
        expect(find.byKey(const Key('catalog-search')), findsOneWidget);
        // A pane has nothing to close.
        expect(find.byKey(const Key('add-food-close')), findsNothing);
        // The day is on the left, the catalog on the right.
        expect(
          tester.getTopLeft(find.byKey(const Key('weigh-in-row'))).dx,
          lessThan(
            tester.getTopLeft(find.byKey(const Key('catalog-search'))).dx,
          ),
        );
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }

    testWidgets('logging from the pane stays on Home and returns to the list', (
      tester,
    ) async {
      screen(tester, ipad);
      await tester.runAsync(addRice);
      await pumpApp(tester);

      await tester.tap(find.text('Rice'));
      await settle(tester);
      // The servings screen opened inside the pane: the day is still there.
      expect(find.byKey(const Key('log-food-confirm')), findsOneWidget);
      expect(find.byKey(const Key('weigh-in-row')), findsOneWidget);

      await tester.tap(find.byKey(const Key('log-food-confirm')));
      await settle(tester);

      expect(find.byKey(const Key('log-food-confirm')), findsNothing);
      expect(find.byKey(const Key('catalog-search')), findsOneWidget);
      final entry = (await db.select(db.foodLogEntries).get()).single;
      expect(entry.name, 'Rice');
      expect(entry.logDate, today);
      await unmount(tester);
    });

    testWidgets('restaurant menus open inside the pane', (tester) async {
      screen(tester, ipad);
      await tester.pumpWidget(
        testApp(db: db, prefs: prefs, menus: menuFixture()),
      );
      await settle(tester);

      await tester.tap(find.byKey(const Key('restaurants-entry')));
      await settle(tester);
      expect(find.byKey(const Key('restaurants-search')), findsOneWidget);
      expect(find.byKey(const Key('weigh-in-row')), findsOneWidget);

      await tester.tap(find.byKey(const Key('chain-example-burger')));
      await settle(tester);
      expect(find.byKey(const Key('chain-search')), findsOneWidget);
      expect(find.byKey(const Key('weigh-in-row')), findsOneWidget);

      await tester.tap(find.byKey(const Key('menu-item-fries-medium')));
      await settle(tester);
      expect(find.byKey(const Key('weigh-in-row')), findsOneWidget);
      await tester.tap(find.byKey(const Key('log-food-confirm')));
      await settle(tester);

      // Back at the pane's catalog, with the entry in the day beside it.
      expect(find.byKey(const Key('restaurants-search')), findsNothing);
      expect(find.byKey(const Key('catalog-search')), findsOneWidget);
      final entry = (await db.select(db.foodLogEntries).get()).single;
      expect(entry.name, 'French Fries, Medium');
      expect(entry.logDate, today);
      await unmount(tester);
    });

    testWidgets('the pane logs to the day Home shows', (tester) async {
      screen(tester, ipad);
      await tester.runAsync(addRice);
      await pumpApp(tester);
      await tester.tap(find.byIcon(CupertinoIcons.chevron_left).first);
      await settle(tester);

      await tester.tap(find.text('Rice'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('log-food-confirm')));
      await settle(tester);

      final entry = (await db.select(db.foodLogEntries).get()).single;
      expect(entry.logDate, addDays(today, -1));
      await unmount(tester);
    });

    testWidgets('a quick add clears its form, so it cannot log twice', (
      tester,
    ) async {
      screen(tester, ipad);
      await pumpApp(tester);
      await tester.tap(find.text('Quick add'));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('quick-calories')), '250');
      await tester.tap(find.byKey(const Key('quick-log')));
      await settle(tester);

      expect(await db.select(db.foodLogEntries).get(), hasLength(1));
      // Add Food started afresh, back on the catalog.
      expect(find.byKey(const Key('quick-calories')), findsNothing);
      expect(find.byKey(const Key('catalog-search')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('turning the screen keeps the day', (tester) async {
      screen(tester, phoneLandscape);
      await tester.runAsync(
        () => LogRepository(db).logAdhoc(
          logDate: today,
          name: 'Toast',
          macros: const Macros(calories: 90),
        ),
      );
      await pumpApp(tester);
      expect(find.byKey(const Key('catalog-search')), findsOneWidget);

      tester.view.physicalSize = const Size(430, 932);
      await settle(tester);

      expect(find.byKey(const Key('catalog-search')), findsNothing);
      expect(find.byKey(const Key('add-food-button')), findsOneWidget);
      expect(find.text('Toast'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Summary', () {
    Future<void> seed() async {
      final log = LogRepository(db);
      for (var i = 0; i < 5; i++) {
        await log.logAdhoc(
          logDate: addDays(today, -i),
          name: 'Meal $i',
          macros: Macros(calories: 1800.0 + i * 50, protein: 100),
        );
      }
      await BodyWeightRepository(db).setWeight(today, 80);
      await BodyWeightRepository(db).setWeight(addDays(today, -3), 80.6);
    }

    Future<void> openSummary(WidgetTester tester) async {
      await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
      await settle(tester);
    }

    testWidgets('a phone stacks the cards', (tester) async {
      screen(tester, phone);
      await tester.runAsync(seed);
      await pumpApp(tester);
      await openSummary(tester);

      expect(find.byKey(const Key('summary-wide')), findsNothing);
      await unmount(tester);
    });

    testWidgets('an iPad puts the charts in a wider, taller column', (
      tester,
    ) async {
      screen(tester, ipad);
      await tester.runAsync(seed);
      await pumpApp(tester);
      await openSummary(tester);

      expect(find.byKey(const Key('summary-wide')), findsOneWidget);
      final averages = tester.getRect(find.byKey(const Key('days-logged')));
      final chart = tester.getRect(find.byKey(const Key('weight-chart')));
      expect(chart.left, greaterThan(averages.right));
      expect(chart.height, 260);
      expect(chart.width, greaterThan(450));
      expect(find.byKey(const Key('top-foods')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('an empty wide Summary still fits', (tester) async {
      screen(tester, phoneLandscape);
      await pumpApp(tester);
      await openSummary(tester);

      expect(find.byKey(const Key('summary-empty')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });
}
