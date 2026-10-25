import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/providers/reminder_providers.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_notification_scheduler.dart';
import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late FakeNotificationScheduler scheduler;
  final now = DateTime(2026, 10, 21, 8);

  Future<void> logOn(String date) => LogRepository(db).logAdhoc(
    logDate: date,
    name: 'Toast',
    macros: const Macros(calories: 100, protein: 3, carbs: 15, fat: 2),
  );

  Future<void> setUpPrefs([Map<String, Object> extra = const {}]) async {
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories', 'protein'],
      'goal_calories': 2000.0,
      'goal_protein': 150.0,
      ...extra,
    });
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    scheduler = FakeNotificationScheduler();
  });

  tearDown(() async {
    await db.close();
  });

  Widget app() => testApp(
    db: db,
    prefs: prefs,
    overrides: [
      notificationSchedulerProvider.overrideWithValue(scheduler),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
  }

  Future<void> scrollToSwitch(WidgetTester tester, int i) async {
    final target = find.byKey(Key('reminder-switch-$i'));
    await scrollPreferencesTo(tester, target);
    await tester.ensureVisible(target);
    await tester.pump();
  }

  CupertinoSwitch reminderSwitch(WidgetTester tester, int i) =>
      tester.widget<CupertinoSwitch>(find.byKey(Key('reminder-switch-$i')));

  group('Settings reminders', () {
    testWidgets('are off by default and ask for nothing', (tester) async {
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);

      for (var i = 0; i < 3; i++) {
        await scrollToSwitch(tester, i);
        expect(reminderSwitch(tester, i).value, isFalse);
      }
      expect(scheduler.permissionRequests, 0);
      expect(scheduler.pending, isEmpty);
      await unmount(tester);
    });

    testWidgets('turning one on asks permission, saves and schedules', (
      tester,
    ) async {
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);

      await scrollToSwitch(tester, 0);
      await tester.tap(find.byKey(const Key('reminder-switch-0')));
      await settle(tester);

      expect(scheduler.permissionRequests, 1);
      expect(reminderSwitch(tester, 0).value, isTrue);
      expect(prefs.getBool('reminder_0_enabled'), isTrue);
      expect(prefs.getInt('reminder_0_minutes'), 9 * 60);
      expect(scheduler.pending, hasLength(14));
      expect(scheduler.pendingTimes.first, DateTime(2026, 10, 21, 9));

      // Turning it off again asks nothing and clears the schedule.
      await tester.tap(find.byKey(const Key('reminder-switch-0')));
      await settle(tester);
      expect(scheduler.permissionRequests, 1);
      expect(prefs.getBool('reminder_0_enabled'), isFalse);
      expect(scheduler.pending, isEmpty);
      await unmount(tester);
    });

    testWidgets('a refused permission leaves the reminder off', (tester) async {
      scheduler.granted = false;
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);

      await scrollToSwitch(tester, 1);
      await tester.tap(find.byKey(const Key('reminder-switch-1')));
      await settle(tester);

      expect(scheduler.permissionRequests, 1);
      expect(reminderSwitch(tester, 1).value, isFalse);
      expect(prefs.getBool('reminder_1_enabled'), isNull);
      expect(
        find.textContaining('Notifications are not allowed'),
        findsOneWidget,
      );
      expect(scheduler.pending, isEmpty);
      await unmount(tester);
    });

    testWidgets('reminders survive Save on the form', (tester) async {
      await setUpPrefs({
        'reminder_2_enabled': true,
        'reminder_2_minutes': 1200,
      });
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);

      await scrollToSwitch(tester, 0);
      await tester.tap(find.byKey(const Key('reminder-switch-0')));
      await settle(tester);
      await tapSubmitPreferences(tester);
      await settle(tester);

      expect(prefs.getBool('reminder_0_enabled'), isTrue);
      expect(prefs.getBool('reminder_2_enabled'), isTrue);
      expect(prefs.getInt('reminder_2_minutes'), 1200);
      await unmount(tester);
    });
  });

  group('nothing-logged-yet nudges', () {
    final enabled = <String, Object>{
      'reminder_0_enabled': true,
      'reminder_0_minutes': 9 * 60,
    };

    testWidgets('launch tops up the 14-day window', (tester) async {
      await setUpPrefs(enabled);
      await tester.pumpWidget(app());
      await settle(tester);

      expect(scheduler.pending, hasLength(14));
      await unmount(tester);
    });

    testWidgets('launching with today already logged skips today', (
      tester,
    ) async {
      await setUpPrefs(enabled);
      await tester.runAsync(() => logOn('2026-10-21'));
      await tester.pumpWidget(app());
      await settle(tester);

      expect(scheduler.pending, hasLength(13));
      expect(scheduler.pendingTimes.first, DateTime(2026, 10, 22, 9));
      await unmount(tester);
    });

    testWidgets("logging today's first entry cancels today's", (tester) async {
      await setUpPrefs(enabled);
      await tester.pumpWidget(app());
      await settle(tester);
      expect(scheduler.pending, hasLength(14));

      await tester.runAsync(() => logOn('2026-10-21'));
      await settle(tester);

      expect(scheduler.pending, hasLength(13));
      expect(scheduler.pendingTimes.first, DateTime(2026, 10, 22, 9));
      await unmount(tester);
    });

    testWidgets("an entry on another day does not cancel today's", (
      tester,
    ) async {
      await setUpPrefs(enabled);
      await tester.pumpWidget(app());
      await settle(tester);

      await tester.runAsync(() => logOn('2026-10-20'));
      await settle(tester);

      expect(scheduler.pending, hasLength(14));
      await unmount(tester);
    });
  });

  group('streak badge', () {
    Finder badgeText(String text) => find.descendant(
      of: find.byKey(const Key('streak-badge')),
      matching: find.text(text),
    );

    testWidgets('is hidden with no streak', (tester) async {
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.byKey(const Key('streak-badge')), findsNothing);
      await unmount(tester);
    });

    testWidgets('shows the days, even while today is empty', (tester) async {
      await setUpPrefs();
      await tester.runAsync(() async {
        await logOn('2026-10-20');
        await logOn('2026-10-19');
        await logOn('2026-10-17');
      });
      await tester.pumpWidget(app());
      await settle(tester);
      expect(badgeText('2'), findsOneWidget);

      await tester.runAsync(() => logOn('2026-10-21'));
      await settle(tester);
      expect(badgeText('3'), findsOneWidget);
      await unmount(tester);
    });
  });
}
