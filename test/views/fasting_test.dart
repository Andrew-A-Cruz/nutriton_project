import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/fasting_repository.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:nutriton_project/views/settings/fasting_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 11, 9, 20);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<SharedPreferences> prefsWith({bool fasting = true}) =>
      mockPreferences({
        'onboarding_complete': true,
        'primary_metric': 'calories',
        'tracked_metrics': ['calories'],
        'goal_calories': 2000.0,
        'fasting_enabled': fasting,
      });

  Future<void> pumpApp(WidgetTester tester, SharedPreferences prefs) async {
    await tester.pumpWidget(
      testApp(
        db: db,
        prefs: prefs,
        overrides: [clockProvider.overrideWithValue(() => now)],
      ),
    );
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
  }

  group('Home fasting row', () {
    testWidgets('is hidden until switched on', (tester) async {
      await pumpApp(tester, await prefsWith(fasting: false));
      expect(find.byKey(const Key('fasting-row')), findsNothing);
      await unmount(tester);
    });

    testWidgets('starts a fast and shows the time so far', (tester) async {
      await pumpApp(tester, await prefsWith());
      expect(find.text('Not fasting'), findsOneWidget);
      expect(find.byKey(const Key('fasting-elapsed')), findsNothing);

      await tap(tester, 'fasting-start');

      expect(find.text('Fasting'), findsOneWidget);
      expect(find.text('0m'), findsOneWidget);
      final rows = await db.select(db.fasts).get();
      expect(rows.single.startedAt, now);
      expect(rows.single.endedAt, isNull);
      await unmount(tester);
    });

    testWidgets('shows a running fast and ends it', (tester) async {
      await tester.runAsync(
        () => FastingRepository(
          db,
        ).start(now.subtract(const Duration(hours: 13, minutes: 20))),
      );
      await pumpApp(tester, await prefsWith());

      expect(find.text('13h 20m'), findsOneWidget);
      await tap(tester, 'fasting-end');

      expect(find.text('Not fasting'), findsOneWidget);
      final done = (await db.select(db.fasts).get()).single;
      expect(done.endedAt, now);
      await unmount(tester);
    });

    testWidgets('shows only on today', (tester) async {
      await pumpApp(tester, await prefsWith());
      expect(find.byKey(const Key('fasting-row')), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.chevron_left).first);
      await settle(tester);

      expect(find.byKey(const Key('fasting-row')), findsNothing);
      await unmount(tester);
    });
  });

  group('Settings fasting section', () {
    Future<void> openSection(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('settings-button')));
      await settle(tester);
      await scrollPreferencesTo(
        tester,
        find.byKey(const Key('fasting-enabled')),
      );
      // Scrolling stops with the switch at the screen's edge; centre it.
      await tester.ensureVisible(find.byKey(const Key('fasting-enabled')));
      await settle(tester);
    }

    testWidgets('the switch saves at once and survives Save', (tester) async {
      final prefs = await prefsWith(fasting: false);
      await pumpApp(tester, prefs);
      await openSection(tester);
      expect(find.byKey(const Key('fasting-history')), findsNothing);

      await tap(tester, 'fasting-enabled');
      expect(prefs.getBool('fasting_enabled'), isTrue);
      expect(find.byKey(const Key('fasting-history')), findsOneWidget);

      await tapSubmitPreferences(tester);
      await settle(tester);
      expect(prefs.getBool('fasting_enabled'), isTrue);
      expect(find.byKey(const Key('fasting-row')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('history lists finished fasts and removes one', (tester) async {
      await tester.runAsync(() async {
        final repo = FastingRepository(db);
        await repo.start(DateTime(2026, 11, 9, 20));
        await repo.end(DateTime(2026, 11, 10, 12));
        await repo.start(DateTime(2026, 11, 10, 19));
        await repo.end(DateTime(2026, 11, 10, 21, 30));
      });
      await pumpApp(tester, await prefsWith());
      await openSection(tester);
      await scrollPreferencesTo(
        tester,
        find.byKey(const Key('fasting-history')),
      );
      await tap(tester, 'fasting-history');

      expect(find.text('16h 0m'), findsOneWidget);
      expect(find.text('2h 30m'), findsOneWidget);
      expect(
        find.text('Mon, Nov 9, 8:00 PM – Tue, Nov 10, 12:00 PM'),
        findsOneWidget,
      );
      expect(find.text('Tue, Nov 10, 7:00 PM – 9:30 PM'), findsOneWidget);

      final short = (await db.select(db.fasts).get()).firstWhere(
        (f) => f.startedAt == DateTime(2026, 11, 10, 19),
      );
      await tap(tester, 'fast-remove-${short.id}');
      await tap(tester, 'fast-remove-confirm');

      expect(find.text('2h 30m'), findsNothing);
      expect(await db.select(db.fasts).get(), hasLength(1));
      await unmount(tester);
    });

    testWidgets('history says so when there are no fasts', (tester) async {
      await pumpApp(tester, await prefsWith());
      await openSection(tester);
      await scrollPreferencesTo(
        tester,
        find.byKey(const Key('fasting-history')),
      );
      await tap(tester, 'fasting-history');

      expect(find.byKey(const Key('fasts-empty')), findsOneWidget);
      await unmount(tester);
    });
  });

  test('a span within one day names the day once', () {
    expect(
      describeFastSpan(DateTime(2026, 11, 10, 7), DateTime(2026, 11, 10, 19)),
      'Tue, Nov 10, 7:00 AM – 7:00 PM',
    );
  });
}
