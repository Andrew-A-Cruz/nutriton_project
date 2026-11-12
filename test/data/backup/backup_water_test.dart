import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/water.dart';
import 'package:nutriton_project/data/backup/backup_codec.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:nutriton_project/data/repositories/water_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backups and the water table and settings (schema v12). The backup format
/// version stays at 1: `water_log` and `water` are optional on read.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase source;
  late AppDatabase target;
  late UserPreferences prefs;
  late BackupRepository sourceRepo;
  late BackupRepository targetRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = UserPreferences(await SharedPreferences.getInstance());
    source = AppDatabase(NativeDatabase.memory());
    target = AppDatabase(NativeDatabase.memory());
    sourceRepo = BackupRepository(source, prefs);
    targetRepo = BackupRepository(target, prefs);
    final water = WaterRepository(source);
    await water.add('2026-11-10', 1500);
    await water.add('2026-11-11', 750);
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<Map<String, dynamic>> export() async =>
      jsonDecode(await sourceRepo.exportJson()) as Map<String, dynamic>;

  Future<Map<String, double>> days(AppDatabase db) async => {
    for (final r in await db.select(db.waterLog).get()) r.logDate: r.amountMl,
  };

  test(
    'the file carries water_log and the settings; version stays 1',
    () async {
      final json = await export();
      expect(json['version'], 1);
      expect(json['water_log'], hasLength(2));
      expect((json['preferences'] as Map)['water'], {
        'enabled': true,
        'unit': 'glasses',
      });
    },
  );

  test('round trip restores the days and the settings', () async {
    await prefs.write(
      UserSettings(
        onboardingComplete: true,
        water: const WaterSettings(unit: WaterUnit.ml, goalMl: 2000),
      ),
    );

    final settings = await targetRepo.importJson(await sourceRepo.exportJson());

    expect(
      settings.water,
      const WaterSettings(unit: WaterUnit.ml, goalMl: 2000),
    );
    expect(await days(target), {'2026-11-10': 1500, '2026-11-11': 750});
  });

  test('import replaces existing days', () async {
    await WaterRepository(target).add('2026-09-01', 250);

    await targetRepo.importJson(await sourceRepo.exportJson());

    expect(await days(target), {'2026-11-10': 1500, '2026-11-11': 750});
  });

  test('a file without water imports with none and the defaults', () async {
    final json = await export();
    json.remove('water_log');
    (json['preferences'] as Map).remove('water');
    await WaterRepository(target).add('2026-09-01', 250);

    final settings = await targetRepo.importJson(jsonEncode(json));

    expect(settings.water, const WaterSettings());
    expect(await days(target), isEmpty);
  });

  test('the real version 1 fixture still imports', () async {
    final text = File(
      'test/data/backup/fixtures/backup_v1.json',
    ).readAsStringSync();

    final settings = await targetRepo.importJson(text);

    expect(settings.water, const WaterSettings());
    expect(await days(target), isEmpty);
  });

  test('bad water settings or rows are rejected', () async {
    for (final bad in [
      {'enabled': true, 'unit': 'buckets'},
      {'enabled': 'yes', 'unit': 'ml'},
      {'enabled': true, 'unit': 'ml', 'goalMl': -1},
      'nope',
    ]) {
      final json = await export();
      (json['preferences'] as Map)['water'] = bad;
      expect(
        () => const BackupCodec().decode(jsonEncode(json)),
        throwsA(isA<BackupException>()),
        reason: '$bad',
      );
    }
    final badRows = await export();
    badRows['water_log'] = ['nope'];
    expect(
      () => const BackupCodec().decode(jsonEncode(badRows)),
      throwsA(isA<BackupException>()),
    );
  });

  test('a zero amount fails the import and changes nothing', () async {
    final json = await export();
    ((json['water_log'] as List).first as Map)['amountMl'] = 0;
    await WaterRepository(target).add('2026-09-01', 250);

    await expectLater(
      targetRepo.importJson(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
    expect(await days(target), {'2026-09-01': 250});
  });
}
