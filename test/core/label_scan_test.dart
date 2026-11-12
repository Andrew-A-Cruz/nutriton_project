import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/label_scan.dart';

/// The fixtures are what Apple Vision returned for rendered sample labels
/// (the same request as `recognizeLabelText` in AppDelegate.swift), so the
/// pieces arrive split and ordered as they do on a phone.
List<OcrLine> fixture(String name) => [
  for (final m
      in jsonDecode(File('test/fixtures/labels/$name.json').readAsStringSync())
          as List)
    OcrLine.fromMap(m)!,
];

LabelScan scanFixture(String name) =>
    parseNutritionLabel(rowsFromLines(fixture(name)));

/// A label typed as rows, for the cases no fixture covers.
LabelScan scanRows(List<String> rows) => parseNutritionLabel([
  for (final r in rows) [r],
]);

void main() {
  group('saved recognizer output', () {
    test('a US label: one column per serving, with the serving weight', () {
      final scan = scanFixture('us_cereal');
      final s = scan.perServing!;
      expect(scan.per100, isNull);
      expect(scan.servingWeightG, 55);
      expect(s.calories, 230);
      expect(s.fat, 8);
      expect(s.carbs, 37);
      expect(s.protein, 3);
      expect(s.fiber, 4);
      // Total sugars, not the 10 g of added sugars.
      expect(s.sugar, 12);
      expect(s.sodiumMg, 160);
    });

    test('a photo tilted by 4 degrees still lines its rows up', () {
      final rows = rowsFromLines(fixture('us_yogurt_tilted'));
      expect(rows, contains(equals(['Calories', '100'])));
      expect(rows, contains(equals(['Serving size', '1 container (170g)'])));

      final scan = parseNutritionLabel(rows);
      final s = scan.perServing!;
      expect(scan.servingWeightG, 170);
      expect(s.calories, 100);
      expect(s.fat, 0);
      expect(s.carbs, 6);
      expect(s.protein, 17.5);
      expect(s.sugar, 4);
      expect(s.sodiumMg, 65);
    });

    test('an EU table: per 100 g and per serving, kJ and kcal', () {
      final scan = scanFixture('eu_two_columns');
      final p = scan.per100!;
      final s = scan.perServing!;
      // kcal is used when both units are printed.
      expect(p.calories, 372);
      expect(p.fat, 7);
      expect(p.carbs, 60);
      expect(p.sugar, 1.1);
      expect(p.fiber, 9);
      expect(p.protein, 13);
      // 0.02 g salt is 8 mg sodium.
      expect(p.sodiumMg, 8);
      expect(scan.servingWeightG, 30);
      expect(s.calories, 112);
      expect(s.fat, 2.1);
      expect(s.carbs, 18);
      expect(s.protein, 3.9);
    });

    test('a German label with decimal commas, per 100 g only', () {
      final scan = scanFixture('eu_per_100_comma');
      final p = scan.per100!;
      expect(scan.perServing, isNull);
      expect(p.calories, 250);
      expect(p.fat, 9.5);
      expect(p.carbs, 31);
      expect(p.sugar, 4.2);
      expect(p.fiber, 2.8);
      expect(p.protein, 8.7);
      expect(p.sodiumMg, 480);
    });

    test('energy in kJ only is converted to kcal; ml counts as grams', () {
      final scan = scanFixture('uk_kj_only');
      expect(scan.per100!.calories, 43); // 180 kJ
      expect(scan.perServing!.calories, 108); // 450 kJ
      expect(scan.servingWeightG, 250);
      expect(scan.perServing!.carbs, 27);
      expect(scan.per100!.fiber, isNull);
    });
  });

  group('rows', () {
    OcrLine at(String text, double x, double y, {double w = 100}) =>
        OcrLine(text: text, x1: x, y1: y, x2: x + w, y2: y, height: 20);

    test('pieces at the same height join left to right', () {
      final rows = rowsFromLines([
        at('8g', 300, 101),
        at('Protein', 20, 140),
        at('Fat', 20, 100),
        at('3g', 300, 139),
      ]);
      expect(rows, [
        ['Fat', '8g'],
        ['Protein', '3g'],
      ]);
    });

    test('empty text and nothing at all give no rows', () {
      expect(rowsFromLines(const []), isEmpty);
      expect(rowsFromLines([at('  ', 0, 0)]), isEmpty);
    });

    test('a malformed line from the channel is dropped', () {
      expect(OcrLine.fromMap('nope'), isNull);
      expect(OcrLine.fromMap({'text': 'Fat', 'x1': 1}), isNull);
      expect(
        OcrLine.fromMap({
          'text': 'Fat',
          'x1': 1,
          'y1': 2,
          'x2': 3,
          'y2': 2,
          'height': 5,
        })!.text,
        'Fat',
      );
    });
  });

  group('typed rows', () {
    test('parts of a nutrient are not the nutrient', () {
      final s = scanRows([
        'Calories 150',
        'Calories from Fat 70',
        'Saturated Fat 5g',
        'Trans Fat 0g',
        'Total Fat 8g 12%',
        'Includes 9g Added Sugars',
        'Sugars 10g',
      ]).perServing!;
      expect(s.calories, 150);
      expect(s.fat, 8);
      expect(s.sugar, 10);
    });

    test('percent daily values and micrograms are not amounts', () {
      final s = scanRows(['Protein 12%', 'Fiber 20mcg']).perServing!;
      expect(s.protein, isNull);
      expect(s.fiber, isNull);
    });

    test('a zero read as the letter O is a zero', () {
      final s = scanRows(['Total Fat Og', 'Protein O g']).perServing!;
      expect(s.fat, 0);
      expect(s.protein, 0);
    });

    test('sodium in grams becomes milligrams; sodium wins over salt', () {
      expect(scanRows(['Sodium 0.4 g']).perServing!.sodiumMg, 400);
      expect(scanRows(['Salt 1 g', 'Sodium 300 mg']).perServing!.sodiumMg, 300);
    });

    test('"unsalted" is not salt', () {
      expect(scanRows(['Unsalted butter 10 g']).perServing!.sodiumMg, isNull);
    });

    test('a per-serving column with no size keeps the serving size row', () {
      final scan = scanRows([
        'per 100 g per serving',
        'Serving size 40 g',
        'Energy 400 kcal 160 kcal',
        'Protein 10 g 4 g',
      ]);
      expect(scan.per100!.calories, 400);
      expect(scan.perServing!.calories, 160);
      expect(scan.perServing!.protein, 4);
      expect(scan.servingWeightG, 40);
    });

    test('text that is not a label reads as empty', () {
      expect(
        scanRows(['Best before 12 2027', 'Keep refrigerated']).isEmpty,
        isTrue,
      );
      expect(parseNutritionLabel(const []).isEmpty, isTrue);
    });
  });

  group('what fills the form', () {
    const full = LabelNutrients(calories: 100, protein: 5, carbs: 10, fat: 2);

    test('a serving with a weight is preferred', () {
      final fill = labelFill(
        const LabelScan(
          perServing: full,
          servingWeightG: 30,
          per100: LabelNutrients(calories: 333),
        ),
      )!;
      expect(fill.per100, isFalse);
      expect(fill.servingWeightG, 30);
      expect(fill.nutrients.calories, 100);
      expect(fill.missing, isEmpty);
    });

    test('a serving with no weight gives way to per 100 g', () {
      final fill = labelFill(const LabelScan(perServing: full, per100: full))!;
      expect(fill.per100, isTrue);
      expect(fill.servingWeightG, 100);
    });

    test('a serving with no weight and no other column asks for it', () {
      final fill = labelFill(const LabelScan(perServing: full))!;
      expect(fill.servingWeightG, isNull);
      expect(fill.missing, ['serving weight']);
    });

    test('the fuller column wins when the serving one is patchy', () {
      final fill = labelFill(
        const LabelScan(
          perServing: LabelNutrients(calories: 100),
          servingWeightG: 30,
          per100: full,
        ),
      )!;
      expect(fill.per100, isTrue);
    });

    test('missing main values are named', () {
      final fill = labelFill(
        const LabelScan(per100: LabelNutrients(calories: 100, carbs: 10)),
      )!;
      expect(fill.missing, ['protein', 'fat']);
    });

    test('an empty scan fills nothing', () {
      expect(labelFill(const LabelScan()), isNull);
      expect(labelFill(const LabelScan(perServing: LabelNutrients())), isNull);
    });
  });
}
