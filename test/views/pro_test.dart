import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/core/pro.dart';
import 'package:nutriton_project/core/widget_snapshot.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/data/store/store_service.dart';
import 'package:nutriton_project/providers/entitlement_providers.dart';
import 'package:nutriton_project/providers/health_providers.dart';
import 'package:nutriton_project/providers/review_providers.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:nutriton_project/providers/widget_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_health_service.dart';
import '../support/fake_store_service.dart';
import '../support/fake_widget_publisher.dart';
import '../support/test_app.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late FakeStoreService store;
  late FakeHealthService health;
  late FakeWidgetPublisher publisher;
  late int reviewRequests;
  final now = DateTime(2026, 10, 21, 8);
  final today = todayKey(now);

  Future<void> setUpPrefs([Map<String, Object> extra = const {}]) async {
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories'],
      'goal_calories': 2000.0,
      ...extra,
    });
  }

  Future<void> logOn(String date) => LogRepository(db).logAdhoc(
    logDate: date,
    name: 'Toast',
    macros: const Macros(calories: 100, protein: 3, carbs: 15, fat: 2),
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = FakeStoreService(now: () => now);
    health = FakeHealthService();
    publisher = FakeWidgetPublisher();
    reviewRequests = 0;
  });

  tearDown(() async {
    await db.close();
  });

  Widget app({StoreService? storeService}) => testApp(
    db: db,
    prefs: prefs,
    overrides: [
      storeServiceProvider.overrideWithValue(storeService ?? store),
      healthServiceProvider.overrideWithValue(health),
      healthSupportedProvider.overrideWithValue(true),
      widgetPublisherProvider.overrideWithValue(publisher),
      clockProvider.overrideWithValue(() => now),
      requestReviewProvider.overrideWithValue(() async => reviewRequests++),
    ],
  );

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await scrollPreferencesTo(tester, target);
    await tester.ensureVisible(target);
    await tester.pump();
  }

  final lock = find.byKey(const Key('pro-lock'));
  final writeSwitch = find.byKey(const Key('health-write-switch'));

  group('without Pro', () {
    testWidgets('Apple Health shows lock badges that open the paywall', (
      tester,
    ) async {
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);

      await scrollTo(tester, find.text('Read body weight'));
      expect(lock, findsNWidgets(2));
      expect(writeSwitch, findsNothing);

      await tester.ensureVisible(lock.first);
      await tester.pump();
      await tester.tap(lock.first, warnIfMissed: true);
      await settle(tester);
      expect(find.text('Home Screen Widget'), findsOneWidget);
      expect(find.text('Apple Health'), findsOneWidget);
      // Unbuilt Pro features are never sold.
      expect(find.text('iCloud Sync'), findsNothing);
      expect(find.text('Shareable Reports'), findsNothing);
      expect(find.text(r'Unlock Pro for $9.99'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the widget shows only the unlock prompt', (tester) async {
      await setUpPrefs();
      await tester.runAsync(() => logOn(today));
      await tester.pumpWidget(app());
      await settle(tester);

      expect(publisher.last, WidgetSnapshot.locked(dateKey: today));
      expect(publisher.last.toMap()['locked'], isTrue);
      await unmount(tester);
    });

    testWidgets('Health sync stays off even when switched on before', (
      tester,
    ) async {
      await setUpPrefs({
        'health_write_nutrition': true,
        'health_read_weight': true,
      });
      await tester.runAsync(() => logOn(today));
      await tester.pumpWidget(app());
      await settle(tester);

      expect(health.writes, isEmpty);
      expect(health.reads, isEmpty);
      // The choice is kept for when Pro comes back.
      expect(prefs.getBool('health_write_nutrition'), isTrue);
      await unmount(tester);
    });

    testWidgets('free features never show a lock', (tester) async {
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);
      expect(lock, findsNothing);
      await tester.tap(find.text('Catalog'));
      await settle(tester);
      expect(lock, findsNothing);
      await tester.tap(find.text('Summary'));
      await settle(tester);
      expect(lock, findsNothing);
      await unmount(tester);
    });

    testWidgets('without a store the paywall says so', (tester) async {
      await setUpPrefs();
      await tester.pumpWidget(app(storeService: const NoopStoreService()));
      await settle(tester);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('pro-row')));
      await tester.tap(find.byKey(const Key('pro-row')));
      await settle(tester);

      expect(find.byKey(const Key('paywall-unavailable')), findsOneWidget);
      expect(find.byKey(const Key('paywall-buy')), findsNothing);
      expect(find.byKey(const Key('paywall-restore')), findsNothing);
      await unmount(tester);
    });
  });

  group('buying', () {
    testWidgets('unlocks Health and the widget, and is cached', (tester) async {
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);
      await scrollTo(tester, find.text('Read body weight'));
      await tester.ensureVisible(lock.first);
      await tester.pump();
      await tester.tap(lock.first, warnIfMissed: true);
      await settle(tester);

      await tester.tap(find.byKey(const Key('paywall-buy')));
      await settle(tester);
      expect(store.bought, [ProProducts.pro]);
      expect(find.byKey(const Key('paywall-owned')), findsOneWidget);
      expect(prefs.getBool('pro_purchased'), isTrue);

      await tester.tap(find.byKey(const Key('paywall-close')));
      await settle(tester);
      expect(lock, findsNothing);
      expect(writeSwitch, findsOneWidget);
      expect(publisher.last.locked, isFalse);
      await unmount(tester);
    });

    testWidgets('a cancelled purchase changes nothing', (tester) async {
      await setUpPrefs();
      store.onBuy = (_) => null;
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('pro-row')));
      await tester.tap(find.byKey(const Key('pro-row')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('paywall-buy')));
      await settle(tester);
      expect(find.byKey(const Key('paywall-owned')), findsNothing);
      expect(find.byKey(const Key('paywall-error')), findsNothing);
      expect(prefs.getBool('pro_purchased'), isNot(isTrue));
      await unmount(tester);
    });

    testWidgets('a failed purchase shows why', (tester) async {
      await setUpPrefs();
      store.onBuy = (_) =>
          throw const StoreException('Could not reach the App Store.');
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('pro-row')));
      await tester.tap(find.byKey(const Key('pro-row')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('paywall-buy')));
      await settle(tester);
      expect(find.text('Could not reach the App Store.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the trial unlocks Pro and is offered only once', (
      tester,
    ) async {
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);
      await scrollTo(tester, find.byKey(const Key('pro-row')));
      await tester.tap(find.byKey(const Key('pro-row')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('paywall-trial')));
      await settle(tester);
      expect(find.text('Your trial has 14 days left.'), findsOneWidget);
      expect(find.byKey(const Key('paywall-trial')), findsNothing);
      expect(find.byKey(const Key('paywall-buy')), findsOneWidget);

      await tester.tap(find.byKey(const Key('paywall-close')));
      await settle(tester);
      expect(find.text('Trial, 14 days left'), findsOneWidget);
      expect(lock, findsNothing);
      await unmount(tester);
    });

    testWidgets('a tip thanks the user and unlocks nothing', (tester) async {
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);
      final tip = find.byKey(const Key('tip-com.nutriton.app.tip.small'));
      await scrollTo(tester, tip);
      expect(find.text(r'$1.99'), findsOneWidget);

      await tester.tap(tip);
      await settle(tester);
      expect(find.text('Thank you for the tip!'), findsOneWidget);
      expect(find.text("See what's included"), findsOneWidget);
      expect(prefs.getBool('pro_purchased'), isNot(isTrue));
      await unmount(tester);
    });
  });

  group('restoring', () {
    testWidgets('finds an earlier purchase', (tester) async {
      await setUpPrefs();
      store.owned = const ProStatus(purchased: true);
      store.offline = true;
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);
      final restore = find.byKey(const Key('restore-purchases'));
      await scrollTo(tester, restore);

      await tester.tap(restore);
      await settle(tester);
      expect(store.restores, 1);
      expect(find.text('Purchases restored.'), findsOneWidget);
      expect(find.text('Unlocked'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('says when there is nothing to restore', (tester) async {
      await setUpPrefs();
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);
      final restore = find.byKey(const Key('restore-purchases'));
      await scrollTo(tester, restore);

      await tester.tap(restore);
      await settle(tester);
      expect(find.text('No earlier Pro purchase was found.'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('cached status', () {
    testWidgets('Pro works offline from the cached purchase', (tester) async {
      await setUpPrefs({'pro_purchased': true});
      store.offline = true;
      await tester.pumpWidget(app());
      await settle(tester);
      await openSettings(tester);
      await scrollTo(tester, writeSwitch);
      expect(lock, findsNothing);
      await unmount(tester);
    });

    testWidgets('a refund locks Pro again and keeps the Health choice', (
      tester,
    ) async {
      await setUpPrefs({'pro_purchased': true, 'health_write_nutrition': true});
      store.owned = const ProStatus(purchased: true);
      await tester.pumpWidget(app());
      await settle(tester);

      store.push(ProStatus.none);
      await settle(tester);
      expect(prefs.getBool('pro_purchased'), isFalse);
      expect(publisher.last.locked, isTrue);
      expect(prefs.getBool('health_write_nutrition'), isTrue);
      await unmount(tester);
    });
  });

  group('trial ended notice', () {
    Map<String, Object> endedTrial() => {
      'pro_trial_started_at': now
          .subtract(const Duration(days: 20))
          .millisecondsSinceEpoch,
    };

    testWidgets('shows once on Home, and OK dismisses it for good', (
      tester,
    ) async {
      await setUpPrefs(endedTrial());
      store.offline = true;
      await tester.pumpWidget(app());
      await settle(tester);
      expect(find.text('Your Pro trial ended'), findsOneWidget);

      await tester.tap(find.byKey(const Key('trial-ended-dismiss')));
      await settle(tester);
      expect(find.text('Your Pro trial ended'), findsNothing);
      expect(prefs.getBool('pro_trial_ended_notice_shown'), isTrue);
      await unmount(tester);

      await tester.pumpWidget(app());
      await settle(tester);
      expect(find.text('Your Pro trial ended'), findsNothing);
      await unmount(tester);
    });

    testWidgets('is not shown during a trial or after buying', (tester) async {
      await setUpPrefs({
        'pro_trial_started_at': now
            .subtract(const Duration(days: 3))
            .millisecondsSinceEpoch,
      });
      store.offline = true;
      await tester.pumpWidget(app());
      await settle(tester);
      expect(find.text('Your Pro trial ended'), findsNothing);
      await unmount(tester);

      await setUpPrefs({...endedTrial(), 'pro_purchased': true});
      await tester.pumpWidget(app());
      await settle(tester);
      expect(find.text('Your Pro trial ended'), findsNothing);
      await unmount(tester);
    });
  });

  group('review prompt', () {
    testWidgets('asks once, after logging on the 7th day', (tester) async {
      await setUpPrefs();
      await tester.runAsync(() async {
        for (var i = 1; i <= 6; i++) {
          await logOn(addDays(today, -i));
        }
      });
      await tester.pumpWidget(app());
      await settle(tester);
      expect(reviewRequests, 0);

      await tester.runAsync(() => logOn(today));
      await settle(tester);
      expect(reviewRequests, 1);
      expect(prefs.getBool('review_prompt_asked'), isTrue);

      await tester.runAsync(() => logOn(today));
      await settle(tester);
      expect(reviewRequests, 1);
      await unmount(tester);
    });

    testWidgets('does not ask before 7 logged days', (tester) async {
      await setUpPrefs();
      await tester.runAsync(() async {
        for (var i = 1; i <= 5; i++) {
          await logOn(addDays(today, -i));
        }
      });
      await tester.pumpWidget(app());
      await settle(tester);

      await tester.runAsync(() => logOn(today));
      await settle(tester);
      expect(reviewRequests, 0);
      await unmount(tester);
    });
  });
}
