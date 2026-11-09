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

  testWidgets('Summary lists the top foods by calories and by count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.runAsync(() async {
      final log = LogRepository(db);
      final today = todayKey();
      Future<void> add(String day, String name, double kcal) => log.logAdhoc(
        logDate: day,
        name: name,
        macros: Macros(calories: kcal, protein: 0, carbs: 0, fat: 0),
      );
      await add(today, 'Pizza', 1800);
      await add(today, 'Apple', 100);
      await add(addDays(today, -1), 'Apple', 100);
      await add(addDays(today, -2), 'Apple', 100);
    });
    final prefs = await tester.runAsync(
      () => mockPreferences({
        'onboarding_complete': true,
        'primary_metric': 'calories',
      }),
    );
    await tester.pumpWidget(testApp(db: db, prefs: prefs!));
    await settle(tester);
    await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
    await settle(tester);

    expect(find.text('MOST CALORIES'), findsOneWidget);
    String rowText(String key) => [
      for (final t in tester.widgetList<Text>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
      ))
        t.data ?? t.textSpan!.toPlainText(),
    ].join(' | ');
    expect(rowText('top-amount-0'), 'Pizza | 1800 kcal · 86%');
    expect(rowText('top-count-0'), 'Apple | 3×');
    await unmount(tester);
  });
}
