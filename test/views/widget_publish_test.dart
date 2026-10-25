import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/data/widget/widget_publisher.dart';
import 'package:nutriton_project/providers/preferences_providers.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:nutriton_project/providers/widget_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_widget_publisher.dart';
import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late FakeWidgetPublisher publisher;
  var now = DateTime(2026, 10, 21, 8);

  Future<String> logOn(String date, double calories) =>
      LogRepository(db).logAdhoc(
        logDate: date,
        name: 'Toast',
        macros: Macros(calories: calories, protein: 3, carbs: 15, fat: 2),
      );

  setUp(() async {
    now = DateTime(2026, 10, 21, 8);
    db = AppDatabase(NativeDatabase.memory());
    publisher = FakeWidgetPublisher();
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories'],
      'goal_calories': 2000.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  Widget app() => testApp(
    db: db,
    prefs: prefs,
    overrides: [
      widgetPublisherProvider.overrideWithValue(publisher),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(CupertinoApp)));

  testWidgets('publishes the empty day at launch', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    expect(publisher.published, hasLength(1));
    expect(publisher.last.dateKey, '2026-10-21');
    expect(publisher.last.valueText, '2000');
    expect(publisher.last.progress, 0);
    await unmount(tester);
  });

  testWidgets('logging, editing and deleting today republish', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    late String id;
    await tester.runAsync(() async => id = await logOn('2026-10-21', 500));
    await settle(tester);
    expect(publisher.published, hasLength(2));
    expect(publisher.last.valueText, '1500');

    await tester.runAsync(
      () => LogRepository(db).updateAdhoc(
        id,
        name: 'Toast',
        macros: const Macros(calories: 2400, protein: 3, carbs: 15, fat: 2),
      ),
    );
    await settle(tester);
    expect(publisher.published, hasLength(3));
    expect(publisher.last.valueText, '400');
    expect(publisher.last.caption, 'kcal over');
    expect(publisher.last.overGoal, isTrue);

    await tester.runAsync(() => LogRepository(db).deleteEntry(id));
    await settle(tester);
    expect(publisher.published, hasLength(4));
    expect(publisher.last.valueText, '2000');
    await unmount(tester);
  });

  testWidgets('a change to another day does not republish', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    final before = publisher.published.length;

    await tester.runAsync(() => logOn('2026-10-20', 700));
    await settle(tester);

    expect(publisher.published, hasLength(before));
    await unmount(tester);
  });

  testWidgets('changing the goal or primary metric republishes', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await settle(tester);
    final notifier = container(tester).read(preferencesProvider.notifier);
    final settings = container(tester).read(preferencesProvider);

    await tester.runAsync(
      () => notifier.save(
        settings.copyWith(goals: {Metric.calories: 1800, Metric.protein: 120}),
      ),
    );
    await settle(tester);
    expect(publisher.last.valueText, '1800');

    await tester.runAsync(
      () => notifier.save(
        container(
          tester,
        ).read(preferencesProvider).copyWith(primaryMetric: Metric.protein),
      ),
    );
    await settle(tester);
    expect(publisher.last.caption, 'g protein left');
    expect(publisher.last.valueText, '120.0');
    await unmount(tester);
  });

  testWidgets('republishes when the day rolls over', (tester) async {
    await tester.runAsync(() => logOn('2026-10-21', 500));
    await tester.pumpWidget(app());
    await settle(tester);
    expect(publisher.last.valueText, '1500');

    now = DateTime(2026, 10, 22, 0, 1);
    container(tester).read(todayProvider.notifier).refresh();
    await settle(tester);

    expect(publisher.last.dateKey, '2026-10-22');
    expect(publisher.last.valueText, '2000');
    await unmount(tester);
  });

  testWidgets('the default publisher does nothing', (tester) async {
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [clockProvider.overrideWithValue(() => now)],
      ),
    );
    await settle(tester);

    expect(
      container(tester).read(widgetPublisherProvider),
      isA<NoopWidgetPublisher>(),
    );
    await unmount(tester);
  });
}
