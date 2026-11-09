import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// 150 g protein, 200 g carbs, 67 g fat: 30 / 40 / 30 % of calories.
  Future<void> logDay(WidgetTester tester) => tester.runAsync(
    () => LogRepository(db).logAdhoc(
      logDate: todayKey(),
      name: 'Day',
      macros: const Macros(calories: 2000, protein: 150, carbs: 200, fat: 67),
    ),
  );

  Future<void> open(WidgetTester tester, List<String> tracked) async {
    final prefs = await tester.runAsync(
      () => mockPreferences({
        'onboarding_complete': true,
        'primary_metric': 'calories',
        'tracked_metrics': tracked,
      }),
    );
    await tester.pumpWidget(testApp(db: db, prefs: prefs!));
    await settle(tester);
  }

  final split = find.byKey(const Key('macro-split'));

  testWidgets('Home and Summary show the share of calories per macro', (
    tester,
  ) async {
    await logDay(tester);
    await open(tester, ['calories', 'protein']);

    expect(split, findsOneWidget);
    expect(find.text('Protein 30%'), findsOneWidget);
    expect(find.text('Carbs 40%'), findsOneWidget);
    expect(find.text('Fat 30%'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Protein 30%, carbs 40%, fat 30% of calories'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
    await settle(tester);
    // Home is offstage now, so this is Summary's, on the averages.
    expect(split, findsOneWidget);
    expect(find.text('Protein 30%'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('hidden when only calories are tracked', (tester) async {
    await logDay(tester);
    await open(tester, ['calories']);
    expect(split, findsNothing);
    await unmount(tester);
  });

  testWidgets('hidden on an empty day', (tester) async {
    await open(tester, ['calories', 'protein']);
    expect(split, findsNothing);
    await unmount(tester);
  });
}
