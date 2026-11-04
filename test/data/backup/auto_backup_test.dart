import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/auto_backup.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/backup/auto_backup.dart';
import 'package:nutriton_project/data/backup/auto_backup_store.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auto_backup_store.dart';

void main() {
  late AppDatabase db;
  late UserPreferences prefs;
  late FakeAutoBackupStore store;
  late AutoBackupRunner runner;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    prefs = UserPreferences(await SharedPreferences.getInstance());
    store = FakeAutoBackupStore();
    runner = AutoBackupRunner(
      repository: BackupRepository(db, prefs),
      store: store,
      preferences: prefs,
    );
    await CatalogRepository(db).createFood(
      name: 'Oats',
      perServing: const Macros(calories: 150),
      servingWeightG: 40,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('writes a readable backup when due and remembers when', () async {
    final now = DateTime(2026, 11, 3, 9);
    expect(await runner.runIfDue(now), isTrue);

    final name = autoBackupFileName(now);
    expect(store.files.keys, [name]);
    final data = BackupRepository(db, prefs).readBackup(store.files[name]!);
    expect(data.foodItems.single.name, 'Oats');
    expect(prefs.readLastAutoBackup(), now);
  });

  test('writes at most one a week', () async {
    await runner.runIfDue(DateTime(2026, 11, 3));
    expect(await runner.runIfDue(DateTime(2026, 11, 9)), isFalse);
    expect(await runner.runIfDue(DateTime(2026, 11, 10)), isTrue);
    expect(store.writes, 2);
  });

  test('overlapping triggers write once', () async {
    final now = DateTime(2026, 11, 3);
    final results = await Future.wait([
      runner.runIfDue(now),
      runner.runIfDue(now),
    ]);
    // Both share the one run and its answer.
    expect(results, [true, true]);
    expect(store.writes, 1);
  });

  test('keeps only the newest few', () async {
    for (var week = 0; week < autoBackupsKept + 3; week++) {
      await runner.runIfDue(DateTime(2026, 6, 1).add(Duration(days: 7 * week)));
    }
    final names = await runner.list();
    expect(names, hasLength(autoBackupsKept));
    expect(names.first, autoBackupFileName(DateTime(2026, 7, 20)));
  });

  test('writes nothing when switched off', () async {
    await prefs.writeAutoBackupEnabled(false);
    expect(await runner.runIfDue(DateTime(2026, 11, 3)), isFalse);
    expect(store.files, isEmpty);
  });

  group('DirectoryAutoBackupStore', () {
    late Directory root;
    late DirectoryAutoBackupStore dirStore;

    setUp(() {
      root = Directory.systemTemp.createTempSync('auto_backup');
      dirStore = DirectoryAutoBackupStore(() async => root);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('writes, lists, reads and deletes in a Backups folder', () async {
      await dirStore.write('a.json', '{"x":1}');
      expect(await dirStore.list(), ['a.json']);
      expect(await dirStore.read('a.json'), '{"x":1}');
      expect(
        File(
          '${root.path}${Platform.pathSeparator}Backups'
          '${Platform.pathSeparator}a.json',
        ).existsSync(),
        isTrue,
      );
      await dirStore.delete('a.json');
      expect(await dirStore.list(), isEmpty);
    });

    test('refuses names with a path in them', () async {
      expect(() => dirStore.write('../x.json', ''), throwsArgumentError);
    });
  });
}
