import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/auto_backup.dart';
import 'package:nutriton_project/core/date_key.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:nutriton_project/providers/backup_providers.dart';
import 'package:nutriton_project/providers/today_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auto_backup_store.dart';
import 'package:nutriton_project/views/home/undo_banner.dart';

import '../support/test_app.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late SharedPreferences prefs;
  late FakeAutoBackupStore store;
  final now = DateTime(2026, 11, 3, 12);

  setUp(() async {
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories'],
    });
    db = AppDatabase(NativeDatabase.memory());
    store = FakeAutoBackupStore();
  });

  tearDown(() async {
    await db.close();
  });

  Widget app() => testApp(
    db: db,
    prefs: prefs,
    overrides: [
      autoBackupStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  Future<void> logToday() => LogRepository(db).logAdhoc(
    logDate: todayKey(now),
    name: 'Toast',
    macros: const Macros(calories: 90),
  );

  testWidgets('nothing is written while today is empty', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    expect(store.writes, 0);
    await unmount(tester);
  });

  testWidgets('today\'s first entry writes the week\'s backup, once', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.runAsync(logToday);
    await settle(tester);
    expect(store.files.keys, [autoBackupFileName(now)]);

    await tester.runAsync(logToday);
    await settle(tester);
    expect(store.writes, 1);
    expect(UserPreferences(prefs).readLastAutoBackup(), now);
    await unmount(tester);
  });

  testWidgets('switched off in Settings, nothing is written', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    final toggle = find.byKey(const Key('auto-backup-toggle'));
    await scrollPreferencesTo(tester, toggle);
    await tester.ensureVisible(toggle);
    await tester.pump();
    await tester.tap(toggle);
    await settle(tester);
    expect(prefs.getBool('auto_backup_enabled'), isFalse);

    await tester.runAsync(logToday);
    await settle(tester);
    expect(store.writes, 0);
    await unmount(tester);
  });

  testWidgets('an automatic backup can be picked and restored', (tester) async {
    // A backup of another state, written a week ago.
    final other = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      await CatalogRepository(other).createFood(
        name: 'Backed up food',
        perServing: const Macros(calories: 100),
        servingWeightG: 100,
      );
      store.files[autoBackupFileName(DateTime(2026, 10, 27))] =
          await BackupRepository(other, UserPreferences(prefs)).exportJson();
      await other.close();
    });

    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('auto-backup-restore')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('auto-backup-restore')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('auto-backup-restore')));
    await settle(tester);

    expect(find.text('October 27, 2026'), findsOneWidget);
    await tester.tap(find.text('October 27, 2026'));
    await settle(tester);
    expect(find.text('Replace all data?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('import-confirm')));
    await settle(tester);
    await settle(tester);
    hideUndoBanner();

    final foods = await tester.runAsync(() => db.select(db.foodItems).get());
    expect(foods!.single.name, 'Backed up food');
    await unmount(tester);
  });
}
