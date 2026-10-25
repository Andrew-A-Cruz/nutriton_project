import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/body_weight.dart';
import 'package:nutriton_project/data/backup/backup_codec.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:nutriton_project/data/repositories/body_weight_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backups and the body weight table and unit added in M15. The backup format
/// version stays at 1: `body_weights` and `bodyWeightUnit` are optional on
/// read.
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
    final weights = BodyWeightRepository(source);
    await weights.setWeight('2026-10-20', 80.5);
    await weights.setWeight('2026-10-21', 80.1);
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<Map<String, dynamic>> export() async =>
      jsonDecode(await sourceRepo.exportJson()) as Map<String, dynamic>;

  Future<Map<String, double>> readings(AppDatabase db) async => {
    for (final r in await db.select(db.bodyWeights).get())
      r.logDate: r.weightKg,
  };

  test('the file carries body_weights and the unit; version stays 1', () async {
    final json = await export();
    expect(json['version'], 1);
    expect(json['body_weights'], hasLength(2));
    expect((json['preferences'] as Map)['bodyWeightUnit'], 'kg');
  });

  test('round trip restores readings and the unit', () async {
    await prefs.write(
      UserSettings(onboardingComplete: true, bodyWeightUnit: BodyWeightUnit.lb),
    );
    final text = await sourceRepo.exportJson();

    final settings = await targetRepo.importJson(text);

    expect(settings.bodyWeightUnit, BodyWeightUnit.lb);
    expect(await readings(target), {'2026-10-20': 80.5, '2026-10-21': 80.1});
  });

  test('import replaces existing readings', () async {
    await BodyWeightRepository(target).setWeight('2026-09-01', 99);
    await BodyWeightRepository(target).setWeight('2026-10-20', 70);

    await targetRepo.importJson(await sourceRepo.exportJson());

    expect(await readings(target), {'2026-10-20': 80.5, '2026-10-21': 80.1});
  });

  test('a file without body weight keys imports with none, as kg', () async {
    final json = await export();
    json.remove('body_weights');
    (json['preferences'] as Map).remove('bodyWeightUnit');
    await BodyWeightRepository(target).setWeight('2026-09-01', 99);

    final settings = await targetRepo.importJson(jsonEncode(json));

    expect(settings.bodyWeightUnit, BodyWeightUnit.kg);
    // A restore replaces everything, so the old reading goes too.
    expect(await readings(target), isEmpty);
  });

  test('the real version 1 fixture still imports', () async {
    final text = File(
      'test/data/backup/fixtures/backup_v1.json',
    ).readAsStringSync();

    final settings = await targetRepo.importJson(text);

    expect(settings.bodyWeightUnit, BodyWeightUnit.kg);
    expect(await readings(target), isEmpty);
    expect(await target.select(target.foodItems).get(), isNotEmpty);
  });

  test('an unknown unit or a malformed row is rejected', () async {
    final badUnit = await export();
    (badUnit['preferences'] as Map)['bodyWeightUnit'] = 'stone';
    expect(
      () => const BackupCodec().decode(jsonEncode(badUnit)),
      throwsA(isA<BackupException>()),
    );

    final badRows = await export();
    badRows['body_weights'] = ['nope'];
    expect(
      () => const BackupCodec().decode(jsonEncode(badRows)),
      throwsA(isA<BackupException>()),
    );
  });

  test('a non-positive weight fails the import and changes nothing', () async {
    final json = await export();
    (json['body_weights'] as List).first['weightKg'] = 0;
    await BodyWeightRepository(target).setWeight('2026-09-01', 99);

    await expectLater(
      targetRepo.importJson(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
    expect(await readings(target), {'2026-09-01': 99});
  });
}
