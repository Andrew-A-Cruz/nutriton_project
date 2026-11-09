import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/providers/entitlement_providers.dart';
import 'package:nutriton_project/providers/report_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

class _FakeSharer implements ReportSharer {
  final shared = <({String fileName, Uint8List bytes})>[];

  @override
  Future<bool> share({
    required String fileName,
    required Uint8List bytes,
    Rect? origin,
  }) async {
    shared.add((fileName: fileName, bytes: bytes));
    return true;
  }
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late _FakeSharer sharer;
  final today = todayKey();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sharer = _FakeSharer();
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories', 'protein'],
      'goal_calories': 2000.0,
    });
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> openSummary(WidgetTester tester, {required bool pro}) async {
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [
          proProvider.overrideWithValue(pro),
          reportSharerProvider.overrideWithValue(sharer),
        ],
      ),
    );
    await settle(tester);
    await tester.tap(find.byIcon(CupertinoIcons.chart_bar_fill));
    await settle(tester);
  }

  Future<void> logToday() => LogRepository(db).logAdhoc(
    logDate: today,
    name: 'Lunch',
    macros: const Macros(calories: 1200, protein: 50, carbs: 100, fat: 40),
  );

  final share = find.byKey(const Key('share-report'));

  testWidgets('Pro shares the week shown as a PDF', (tester) async {
    await tester.runAsync(logToday);
    await openSummary(tester, pro: true);

    await tester.tap(share);
    // Rendering the PDF is real async work.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settle(tester);

    expect(sharer.shared, hasLength(1));
    final start = addDays(today, -6);
    expect(
      sharer.shared.single.fileName,
      'logbite-report-$start-to-$today.pdf',
    );
    expect(String.fromCharCodes(sharer.shared.single.bytes.take(4)), '%PDF');
    await unmount(tester);
  });

  testWidgets('the share button waits for something to be logged', (
    tester,
  ) async {
    await openSummary(tester, pro: true);
    expect(tester.widget<CupertinoButton>(share).onPressed, isNull);
    await unmount(tester);
  });

  testWidgets(
    'without Pro the share button is a lock, and Summary still works',
    (tester) async {
      await tester.runAsync(logToday);
      await openSummary(tester, pro: false);

      expect(share, findsNothing);
      expect(find.text('Days logged: 1 of 7'), findsOneWidget);
      final lock = find.descendant(
        of: find.byType(CupertinoNavigationBar).last,
        matching: find.byKey(const Key('pro-lock')),
      );
      expect(lock, findsOneWidget);
      await tester.tap(lock);
      await settle(tester);
      expect(find.text('Shareable Reports'), findsOneWidget);
      await unmount(tester);
    },
  );
}
