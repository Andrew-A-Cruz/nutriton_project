import '../../core/meal_slot.dart';
import '../database/app_database.dart';

/// The log as a CSV file a spreadsheet opens: one row per entry, oldest
/// first, with a header row.
///
/// - Starts with a byte order mark, so Excel reads names such as "Dunkin’"
///   as UTF-8.
/// - Lines end with CRLF and fields are quoted when they need it (RFC 4180).
/// - A nutrient that was not recorded is an empty cell, not 0.
/// - A name that starts with `=`, `+`, `-` or `@` gets a leading `'`, so a
///   spreadsheet shows it as text instead of running it as a formula.
String logCsv(List<FoodLogEntry> entries) {
  final sorted = [...entries]
    ..sort((a, b) {
      final byDate = a.logDate.compareTo(b.logDate);
      if (byDate != 0) return byDate;
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  final out = StringBuffer('﻿');
  void row(List<String> fields) {
    out
      ..write(fields.map(_field).join(','))
      ..write('\r\n');
  }

  row(logCsvHeader);
  for (final e in sorted) {
    final time = e.createdAt.toLocal();
    row([
      e.logDate,
      '${_two(time.hour)}:${_two(time.minute)}',
      MealSlot.fromName(e.mealSlot)?.label ?? 'Other',
      _typeLabel(e.entryType),
      _safeText(e.name),
      _number(e.servings),
      _number(e.calories),
      _number(e.protein),
      _number(e.carbs),
      _number(e.fat),
      _number(e.fiber),
      _number(e.sugar),
      _number(e.sodium),
    ]);
  }
  return out.toString();
}

const logCsvHeader = [
  'Date',
  'Time',
  'Meal',
  'Type',
  'Name',
  'Servings',
  'Calories (kcal)',
  'Protein (g)',
  'Carbs (g)',
  'Fat (g)',
  'Fiber (g)',
  'Sugar (g)',
  'Sodium (mg)',
];

String _typeLabel(String entryType) => switch (entryType) {
  'food' => 'Food',
  'meal' => 'Meal',
  _ => 'One-off',
};

String _two(int n) => n.toString().padLeft(2, '0');

/// Up to one decimal, without a trailing ".0"; empty for null.
String _number(double? value) {
  if (value == null) return '';
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1);
}

String _safeText(String text) =>
    RegExp(r'^[=+\-@]').hasMatch(text) ? "'$text" : text;

String _field(String value) {
  if (!value.contains(RegExp('[",\r\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}
