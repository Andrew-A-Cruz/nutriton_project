import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../core/reminder.dart';
import '../database/app_database.dart';
import '../preferences/user_preferences.dart';

/// Version written by [BackupCodec.encode]. Bump when the file layout changes;
/// files with a higher version are rejected, lower ones are upgraded on read
/// (see [_upgrades]).
const backupFormatVersion = 1;

/// Rewrites the raw JSON map of a version N backup into the version N + 1
/// layout. Must not mutate its input.
typedef BackupUpgrade =
    Map<String, dynamic> Function(Map<String, dynamic> root);

/// Upgrade steps keyed by the version they upgrade FROM. Version 1 is the
/// current format, so there are none yet.
///
/// To change the layout: bump [backupFormatVersion], add one function that
/// turns version N into N + 1, and register it here as `N: _upgradeV1ToV2`.
/// The runner sets `version` itself. When a table gained a column, the step
/// must write that column's default into every row of the old file, using the
/// same default the database migration used, so `fromJson` sees a complete
/// row. For example:
///
/// ```
/// Map<String, dynamic> _upgradeV1ToV2(Map<String, dynamic> root) => {
///   ...root,
///   'meals': [
///     for (final r in root['meals'] as List)
///       {...(r as Map<String, dynamic>), 'color': 0},
///   ],
/// };
/// ```
///
/// A missing nullable column needs no step: drift reads it as null.
const _upgrades = <int, BackupUpgrade>{};

/// Runs the steps from [fromVersion] up to [toVersion], setting `version` after
/// each one. Throws [BackupException] if a step is missing. [upgrades] and
/// [toVersion] are overridable so tests can use a fake registry.
@visibleForTesting
Map<String, dynamic> upgradeBackupJson(
  Map<String, dynamic> root, {
  required int fromVersion,
  int toVersion = backupFormatVersion,
  Map<int, BackupUpgrade> upgrades = _upgrades,
}) {
  var current = root;
  for (var v = fromVersion; v < toVersion; v++) {
    final step = upgrades[v];
    if (step == null) {
      throw BackupException('This backup (format $v) can no longer be read.');
    }
    current = {...step(current), 'version': v + 1};
  }
  return current;
}

/// The file is not a usable backup (malformed, wrong shape, or too new). The
/// [message] is safe to show to the user.
class BackupException implements Exception {
  BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

/// Everything in a backup, as plain objects.
class BackupData {
  const BackupData({
    this.foodItems = const [],
    this.meals = const [],
    this.mealFoodItems = const [],
    this.logEntries = const [],
    this.logEntryItems = const [],
    this.scheduledMeals = const [],
    this.scheduledMealOutcomes = const [],
    required this.settings,
    this.exportedAt,
  });

  final List<FoodItem> foodItems;
  final List<Meal> meals;
  final List<MealFoodItem> mealFoodItems;
  final List<FoodLogEntry> logEntries;
  final List<FoodLogEntryItem> logEntryItems;
  final List<ScheduledMeal> scheduledMeals;
  final List<ScheduledMealOutcome> scheduledMealOutcomes;
  final UserSettings settings;

  /// When the file was written. Null for data not read from a file, or when the
  /// file's timestamp is missing or unreadable.
  final DateTime? exportedAt;
}

/// Pure-Dart JSON (de)serializer for [BackupData]. No Flutter, no database
/// access. Layout:
///
/// ```
/// { "app": "nutriton", "version": 1, "exportedAt": "...Z",
///   "food_items": [...], "meals": [...], "meal_food_items": [...],
///   "food_log_entries": [...], "food_log_entry_items": [...],
///   "scheduled_meals": [...], "scheduled_meal_outcomes": [...],
///   "preferences": {...} }
/// ```
///
/// Rows use drift's generated JSON (camelCase keys, DateTime as epoch ms).
/// Referential integrity and CHECK rules are enforced by the database during
/// import.
class BackupCodec {
  /// [currentVersion] and [upgrades] are overridable so tests can exercise the
  /// upgrade pipeline with a fake newer format.
  const BackupCodec({
    this.currentVersion = backupFormatVersion,
    this.upgrades = _upgrades,
  });

  final int currentVersion;
  final Map<int, BackupUpgrade> upgrades;

  static const appId = 'nutriton';

  String encode(BackupData data, {DateTime? exportedAt}) {
    final map = <String, Object?>{
      'app': appId,
      'version': currentVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'food_items': [for (final r in data.foodItems) r.toJson()],
      'meals': [for (final r in data.meals) r.toJson()],
      'meal_food_items': [for (final r in data.mealFoodItems) r.toJson()],
      'food_log_entries': [for (final r in data.logEntries) r.toJson()],
      'food_log_entry_items': [for (final r in data.logEntryItems) r.toJson()],
      'scheduled_meals': [for (final r in data.scheduledMeals) r.toJson()],
      'scheduled_meal_outcomes': [
        for (final r in data.scheduledMealOutcomes) r.toJson(),
      ],
      'preferences': _encodeSettings(data.settings),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Parses and validates [source]. Throws [BackupException] on any problem.
  BackupData decode(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException {
      throw BackupException('This file is not valid JSON.');
    }
    if (root is! Map<String, dynamic> || root['app'] != appId) {
      throw BackupException('This file is not a Nutriton backup.');
    }
    final version = root['version'];
    if (version is! int || version < 1) {
      throw BackupException('The backup has no valid version number.');
    }
    if (version > currentVersion) {
      throw BackupException(
        'This backup was made by a newer version of the app '
        '(format $version). Update the app to restore it.',
      );
    }
    try {
      final current = upgradeBackupJson(
        root,
        fromVersion: version,
        toVersion: currentVersion,
        upgrades: upgrades,
      );
      return BackupData(
        foodItems: _rows(current, 'food_items', FoodItem.fromJson),
        meals: _rows(current, 'meals', Meal.fromJson),
        mealFoodItems: _rows(current, 'meal_food_items', MealFoodItem.fromJson),
        logEntries: _rows(current, 'food_log_entries', FoodLogEntry.fromJson),
        logEntryItems: _rows(
          current,
          'food_log_entry_items',
          FoodLogEntryItem.fromJson,
        ),
        scheduledMeals: _rows(
          current,
          'scheduled_meals',
          ScheduledMeal.fromJson,
        ),
        scheduledMealOutcomes: _rows(
          current,
          'scheduled_meal_outcomes',
          ScheduledMealOutcome.fromJson,
        ),
        settings: _decodeSettings(current['preferences']),
        exportedAt: _decodeExportedAt(current['exportedAt']),
      );
    } on BackupException {
      rethrow;
    } catch (_) {
      // Wrong types inside a row surface as TypeError.
      throw BackupException('The backup is damaged or has unexpected data.');
    }
  }

  DateTime? _decodeExportedAt(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

  List<T> _rows<T>(
    Map<String, dynamic> root,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final value = root[key];
    if (value is! List) {
      throw BackupException('The backup is missing "$key".');
    }
    return [
      for (final row in value)
        if (row is Map<String, dynamic>)
          fromJson(row)
        else
          throw BackupException('The backup has a malformed row in "$key".'),
    ];
  }

  Map<String, Object?> _encodeSettings(UserSettings s) => {
    'onboardingComplete': s.onboardingComplete,
    'primaryMetric': s.primaryMetric.name,
    'trackedMetrics': [for (final m in s.trackedMetrics) m.name],
    'displayUnit': s.displayUnit.name,
    'goals': {for (final e in s.goals.entries) e.key.name: e.value},
    'reminders': [
      for (final r in s.reminders) {'enabled': r.enabled, 'minutes': r.minutes},
    ],
  };

  /// Absent in backups made before reminders existed: all off, default times.
  List<Reminder> _decodeReminders(Object? raw) {
    if (raw == null) return Reminder.defaults;
    if (raw is! List) {
      throw BackupException('The backup has invalid reminders.');
    }
    return [
      for (var i = 0; i < raw.length && i < reminderSlots; i++)
        switch (raw[i]) {
          {'enabled': final bool enabled, 'minutes': final int minutes}
              when minutes >= 0 && minutes < 24 * 60 =>
            Reminder(minutes: minutes, enabled: enabled),
          _ => throw BackupException('The backup has invalid reminders.'),
        },
    ];
  }

  UserSettings _decodeSettings(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw BackupException('The backup is missing "preferences".');
    }
    final metrics = Metric.values.asNameMap();
    final primary = metrics[raw['primaryMetric']];
    final unit = WeightUnit.values.asNameMap()[raw['displayUnit']];
    final onboarding = raw['onboardingComplete'];
    final tracked = raw['trackedMetrics'];
    final goals = raw['goals'];
    if (primary == null ||
        unit == null ||
        onboarding is! bool ||
        tracked is! List ||
        goals is! Map) {
      throw BackupException('The backup has invalid preferences.');
    }
    final goalMap = <Metric, double>{};
    for (final e in goals.entries) {
      final metric = metrics[e.key];
      if (metric == null) continue; // from a newer build; ignore
      final v = e.value;
      if (v is! num || !v.isFinite || v <= 0) {
        throw BackupException('The backup has an invalid goal.');
      }
      goalMap[metric] = v.toDouble();
    }
    return UserSettings(
      onboardingComplete: onboarding,
      primaryMetric: primary,
      trackedMetrics: {
        for (final n in tracked)
          if (metrics[n] case final Metric m) m,
      },
      goals: goalMap,
      displayUnit: unit,
      reminders: _decodeReminders(raw['reminders']),
    );
  }
}
