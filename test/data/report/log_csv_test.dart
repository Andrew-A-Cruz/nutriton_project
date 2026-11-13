import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/report/log_csv.dart';

FoodLogEntry entry({
  String id = 'e',
  String logDate = '2026-11-12',
  DateTime? createdAt,
  String entryType = 'food',
  String name = 'Rice',
  double calories = 130,
  double protein = 3,
  double carbs = 28,
  double fat = 0.3,
  double? servings,
  String? mealSlot,
  double? fiber,
  double? sugar,
  double? sodium,
}) => FoodLogEntry(
  id: id,
  logDate: logDate,
  createdAt: createdAt ?? DateTime(2026, 11, 12, 8, 5),
  entryType: entryType,
  name: name,
  calories: calories,
  protein: protein,
  carbs: carbs,
  fat: fat,
  servings: servings,
  mealSlot: mealSlot,
  fiber: fiber,
  sugar: sugar,
  sodium: sodium,
);

List<String> lines(String csv) {
  expect(csv, startsWith('﻿'));
  expect(csv, endsWith('\r\n'));
  return csv.substring(1, csv.length - 2).split('\r\n');
}

void main() {
  test('an empty log is the header only', () {
    expect(lines(logCsv(const [])), [logCsvHeader.join(',')]);
  });

  test('one row per entry, with every column', () {
    final rows = lines(
      logCsv([
        entry(
          servings: 1.5,
          mealSlot: 'breakfast',
          fiber: 0.44,
          sugar: 0,
          sodium: 5,
        ),
      ]),
    );
    expect(
      rows[1],
      '2026-11-12,08:05,Breakfast,Food,Rice,1.5,130,3,28,0.3,0.4,0,5',
    );
  });

  test('a nutrient not recorded is empty, not 0', () {
    final row = lines(logCsv([entry(entryType: 'adhoc')]))[1];
    expect(row, '2026-11-12,08:05,Other,One-off,Rice,,130,3,28,0.3,,,');
  });

  test('oldest first, by day then time', () {
    final rows = lines(
      logCsv([
        entry(id: 'c', logDate: '2026-11-12', name: 'Late'),
        entry(
          id: 'b',
          logDate: '2026-11-11',
          name: 'Evening',
          createdAt: DateTime(2026, 11, 11, 19),
        ),
        entry(
          id: 'a',
          logDate: '2026-11-11',
          name: 'Morning',
          createdAt: DateTime(2026, 11, 11, 7),
          entryType: 'meal',
        ),
      ]),
    );
    expect(
      [for (final r in rows.skip(1)) r.split(',')[4]],
      ['Morning', 'Evening', 'Late'],
    );
    expect(rows[1].split(',')[3], 'Meal');
  });

  test('quotes commas, quotes and line breaks', () {
    final row = lines(logCsv([entry(name: 'Burger, "Big"\nDouble')]))[1];
    expect(row, contains('"Burger, ""Big""\nDouble"'));
  });

  test('a name a spreadsheet would run as a formula is kept as text', () {
    for (final name in ['=1+1', '+1', '-2', '@SUM(A1)']) {
      final row = lines(logCsv([entry(name: name)]))[1];
      expect(row.split(',')[4], "'$name");
    }
  });
}
