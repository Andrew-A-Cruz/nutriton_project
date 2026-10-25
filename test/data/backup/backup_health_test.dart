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

/// Backups and the Apple Health additions of M19: the weight "source" and the
/// two Health switches. The format version stays at 1; all three are optional
/// on read.
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
    await weights.importHealthReadings([(date: '2026-10-21', kg: 80.1)]);
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<Map<String, dynamic>> export() async =>
      jsonDecode(await sourceRepo.exportJson()) as Map<String, dynamic>;

  Future<Map<String, WeightSource>> sources(AppDatabase db) async => {
    for (final r in await db.select(db.bodyWeights).get())
      r.logDate: WeightSource.fromDb(r.source),
  };

  test('the file carries each reading source; version stays 1', () async {
    final json = await export();

    expect(json['version'], 1);
    expect(
      [for (final r in json['body_weights'] as List) r['source']],
      ['manual', 'health'],
    );
  });

  test('round trip restores the sources and the Health switches', () async {
    await prefs.write(
      UserSettings(
        onboardingComplete: true,
        healthWriteNutrition: true,
        healthReadWeight: true,
      ),
    );
    final text = await sourceRepo.exportJson();

    final settings = await targetRepo.importJson(text);

    expect(settings.healthWriteNutrition, isTrue);
    expect(settings.healthReadWeight, isTrue);
    expect(await sources(target), {
      '2026-10-20': WeightSource.manual,
      '2026-10-21': WeightSource.health,
    });
  });

  test(
    'a file without source or Health keys imports as manual and off',
    () async {
      final json = await export();
      for (final row in json['body_weights'] as List) {
        (row as Map).remove('source');
      }
      (json['preferences'] as Map)
        ..remove('healthWriteNutrition')
        ..remove('healthReadWeight');

      final settings = await targetRepo.importJson(jsonEncode(json));

      expect(settings.healthWriteNutrition, isFalse);
      expect(settings.healthReadWeight, isFalse);
      expect(await sources(target), {
        '2026-10-20': WeightSource.manual,
        '2026-10-21': WeightSource.manual,
      });
    },
  );

  test('the real version 1 fixture still imports', () async {
    final text = File(
      'test/data/backup/fixtures/backup_v1.json',
    ).readAsStringSync();

    final settings = await targetRepo.importJson(text);

    expect(settings.healthWriteNutrition, isFalse);
    expect(settings.healthReadWeight, isFalse);
    expect(await target.select(target.foodItems).get(), isNotEmpty);
  });

  test('an invalid Health switch is rejected', () async {
    final json = await export();
    (json['preferences'] as Map)['healthReadWeight'] = 'yes';

    expect(
      () => const BackupCodec().decode(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
  });
}
