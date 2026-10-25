import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/app.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/providers/backup_providers.dart';
import 'package:nutriton_project/providers/infrastructure_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

class FakeBackupFileIo implements BackupFileIo {
  String? pickResult;
  bool saveResult = true;
  final saved = <({String fileName, String contents})>[];
  int picks = 0;

  @override
  Future<bool> save({
    required String fileName,
    required String contents,
    Rect? origin,
  }) async {
    saved.add((fileName: fileName, contents: contents));
    return saveResult;
  }

  @override
  Future<String?> pick() async {
    picks++;
    return pickResult;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late SharedPreferences prefs;
  late FakeBackupFileIo io;
  late String backupJson;

  Future<void> createFood(AppDatabase d, String name) =>
      CatalogRepository(d).createFood(
        name: name,
        perServing: const Macros(calories: 100, protein: 1, carbs: 1, fat: 1),
        servingWeightG: 100,
      );

  setUp(() async {
    prefs = await mockPreferences({
      'onboarding_complete': true,
      'primary_metric': 'calories',
      'tracked_metrics': ['calories'],
      'goal_calories': 2000.0,
    });
    db = AppDatabase(NativeDatabase.memory());
    await createFood(db, 'Current food');
    io = FakeBackupFileIo();

    // A backup of a different state: one food, a 1500 kcal goal.
    final other = AppDatabase(NativeDatabase.memory());
    await createFood(other, 'Backed up food');
    backupJson = await BackupRepository(
      other,
      UserPreferences(prefs),
    ).exportJson();
    backupJson = backupJson.replaceAll('2000.0', '1500.0');
    await other.close();
  });

  tearDown(() async {
    await db.close();
  });

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      backupFileIoProvider.overrideWithValue(io),
    ],
    child: const MyApp(),
  );

  Future<void> openSettingsAndShow(WidgetTester tester, Key target) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.byKey(const Key('settings-button')));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(target),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // Stopping at the edge can leave it under the tab bar.
    await tester.ensureVisible(find.byKey(target));
    await tester.pump();
  }

  Future<List<String>> foodNames() async => [
    for (final f in await db.select(db.foodItems).get()) f.name,
  ];

  testWidgets('export hands the JSON to the file service', (tester) async {
    await openSettingsAndShow(tester, const Key('backup-export'));

    await tester.tap(find.byKey(const Key('backup-export')));
    await settle(tester);

    expect(io.saved, hasLength(1));
    expect(
      io.saved.single.fileName,
      matches(r'^nutriton-backup-\d{4}-\d{2}-\d{2}\.json$'),
    );
    expect(io.saved.single.contents, contains('Current food'));
    expect(find.text('Backup saved.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a cancelled export shows nothing', (tester) async {
    io.saveResult = false;
    await openSettingsAndShow(tester, const Key('backup-export'));

    await tester.tap(find.byKey(const Key('backup-export')));
    await settle(tester);

    expect(find.byKey(const Key('backup-status')), findsNothing);
    expect(find.textContaining('Never backed up'), findsOneWidget);
    expect(prefs.getInt(UserPreferences.lastBackupKey), isNull);
    await unmount(tester);
  });

  testWidgets('import warns, and cancelling changes nothing', (tester) async {
    io.pickResult = backupJson;
    await openSettingsAndShow(tester, const Key('backup-import'));

    await tester.tap(find.byKey(const Key('backup-import')));
    await settle(tester);

    expect(find.text('Replace all data?'), findsOneWidget);
    expect(find.textContaining('0 entries, 1 food, 0 meals'), findsOneWidget);
    expect(find.textContaining('replaces your foods'), findsOneWidget);
    await tester.tap(find.byKey(const Key('import-cancel')));
    await settle(tester);

    expect(await tester.runAsync(foodNames), ['Current food']);
    expect(prefs.getDouble('goal_calories'), 2000);
    await unmount(tester);
  });

  testWidgets('confirming replaces data and settings, then returns to Home', (
    tester,
  ) async {
    io.pickResult = backupJson;
    await openSettingsAndShow(tester, const Key('backup-import'));

    await tester.tap(find.byKey(const Key('backup-import')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('import-confirm')));
    await settle(tester);
    expect(find.text('Backup restored'), findsOneWidget);
    await tester.tap(find.byKey(const Key('import-done')));
    await settle(tester);

    expect(await tester.runAsync(foodNames), ['Backed up food']);
    expect(prefs.getDouble('goal_calories'), 1500);
    expect(find.byKey(const Key('backup-import')), findsNothing);
    expect(find.text('Food Log'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a bad file shows the reason and keeps the data', (tester) async {
    io.pickResult = '{"app": "nutriton", "version": 99}';
    await openSettingsAndShow(tester, const Key('backup-import'));

    await tester.tap(find.byKey(const Key('backup-import')));
    await settle(tester);

    expect(find.text('Replace all data?'), findsNothing);
    expect(find.byKey(const Key('backup-status')), findsOneWidget);
    expect(find.textContaining('newer version'), findsOneWidget);
    expect(await tester.runAsync(foodNames), ['Current food']);
    await unmount(tester);
  });

  testWidgets('cancelling the file picker does nothing', (tester) async {
    io.pickResult = null;
    await openSettingsAndShow(tester, const Key('backup-import'));

    await tester.tap(find.byKey(const Key('backup-import')));
    await settle(tester);

    expect(io.picks, 1);
    expect(find.text('Replace all data?'), findsNothing);
    await unmount(tester);
  });

  testWidgets('shows the last backup day and import leaves it alone', (
    tester,
  ) async {
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    await prefs.setInt(
      UserPreferences.lastBackupKey,
      twoDaysAgo.millisecondsSinceEpoch,
    );
    io.pickResult = backupJson;
    await openSettingsAndShow(tester, const Key('backup-import'));
    expect(find.textContaining('Last backup: 2 days ago'), findsOneWidget);

    await tester.tap(find.byKey(const Key('backup-import')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('import-confirm')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('import-done')));
    await settle(tester);

    expect(
      prefs.getInt(UserPreferences.lastBackupKey),
      twoDaysAgo.millisecondsSinceEpoch,
    );
    await unmount(tester);
  });
}
