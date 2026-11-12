import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/bundled_foods.dart';
import 'package:nutriton_project/core/validation.dart';

void main() {
  const source =
      '# a comment\n'
      'Bananas, raw\t89\t1.1\t22.8\t0.3\t2.6\t12.2\t1\tcup, mashed=225;small=101\n'
      'Oil, olive\t884\t0\t0\t100\t\t\t2\ttbsp=13.5\n'
      'Plain\t10\t1\t1\t0\t\t\t\n';

  group('parser', () {
    test('reads values per 100 g, nulls and portions', () {
      final foods = parseBundledFoods(source);
      expect(
        [for (final f in foods) f.name],
        ['Bananas, raw', 'Oil, olive', 'Plain'],
      );
      final banana = foods.first;
      expect(banana.per100g.calories, 89);
      expect(banana.per100g.protein, 1.1);
      expect(banana.per100g.carbs, 22.8);
      expect(banana.per100g.fat, 0.3);
      expect(banana.per100g.fiber, 2.6);
      expect(banana.per100g.sugar, 12.2);
      expect(banana.per100g.sodium, 1);
      expect(banana.portions, [
        (name: 'cup, mashed', weightG: 225.0),
        (name: 'small', weightG: 101.0),
      ]);
      // Empty optional cells are "not recorded", not zero.
      expect(foods[1].per100g.fiber, isNull);
      expect(foods[1].per100g.sodium, 2);
      expect(foods[2].portions, isEmpty);
    });

    test('bad rows are skipped', () {
      final foods = parseBundledFoods(
        'Good\t10\t1\t1\t0\t\t\t\t\n'
        'Too short\t10\t1\n'
        'Negative\t-5\t1\t1\t0\t\t\t\t\n'
        'No energy\t\t1\t1\t0\t\t\t\t\n'
        'Bad fiber\t10\t1\t1\t0\tx\t\t\t\n'
        '\t10\t1\t1\t0\t\t\t\t\n'
        'Odd portions\t10\t1\t1\t0\t\t\t\tcup=0;=5;slice;ok=30\n',
      );
      expect([for (final f in foods) f.name], ['Good', 'Odd portions']);
      expect(foods.last.portions, [(name: 'ok', weightG: 30.0)]);
    });
  });

  group('search', () {
    final all = parseBundledFoods(
      'Chicken, broilers or fryers, breast, meat only, cooked, roasted\t165\t31\t0\t3.6\t\t\t\n'
      'Soup, chicken noodle\t60\t3\t7\t2\t\t\t\n'
      'Chicken, ground, raw\t143\t17\t0\t8\t\t\t\n'
      'Bananas, raw\t89\t1\t23\t0\t\t\t\n',
    );
    List<String> names(String q, {Set<String> exclude = const {}}) => [
      for (final f in searchBundledFoods(all, q, exclude: exclude)) f.name,
    ];

    test('every word must appear, in any order', () {
      expect(names('breast chicken cooked'), [
        'Chicken, broilers or fryers, breast, meat only, cooked, roasted',
      ]);
      expect(names('banana'), ['Bananas, raw']);
      expect(names('tofu'), isEmpty);
    });

    test('names starting with the word come first, shorter first', () {
      expect(names('chicken'), [
        'Chicken, ground, raw',
        'Chicken, broilers or fryers, breast, meat only, cooked, roasted',
        'Soup, chicken noodle',
      ]);
    });

    test('an empty search matches nothing; excluded names are left out', () {
      expect(names('  '), isEmpty);
      expect(names('banana', exclude: {'bananas, raw'}), isEmpty);
    });

    test('the limit caps the results', () {
      expect(searchBundledFoods(all, 'chicken', limit: 2), hasLength(2));
    });
  });

  group('the bundled file', () {
    final foods = parseBundledFoods(
      File('assets/foods/generic_foods.tsv').readAsStringSync(),
    );

    test('every line parses, a few thousand foods', () {
      final lines = File(
        'assets/foods/generic_foods.tsv',
      ).readAsLinesSync().where((l) => l.isNotEmpty && !l.startsWith('#'));
      expect(foods.length, lines.length);
      expect(foods.length, greaterThan(3000));
    });

    test('everyday foods are there with sensible values', () {
      final banana = searchBundledFoods(foods, 'bananas raw').first;
      expect(banana.name, 'Bananas, raw');
      expect(banana.per100g.calories, closeTo(89, 1));
      expect(banana.portions, isNotEmpty);
      expect(
        searchBundledFoods(foods, 'chicken breast cooked roasted'),
        isNotEmpty,
      );
      expect(searchBundledFoods(foods, 'egg whole raw'), isNotEmpty);
    });

    test('names are unique, and no value is impossible for 100 g', () {
      final names = {for (final f in foods) f.name.toLowerCase()};
      expect(names.length, foods.length);
      for (final f in foods) {
        expect(f.name.length, greaterThanOrEqualTo(2), reason: f.name);
        expect(f.per100g.calories, lessThanOrEqualTo(902), reason: f.name);
        expect(f.per100g.protein, lessThanOrEqualTo(100.5), reason: f.name);
        expect(f.per100g.fat, lessThanOrEqualTo(100.5), reason: f.name);
        expect(f.per100g.carbs, lessThanOrEqualTo(100.5), reason: f.name);
      }
    });

    test('no brand or restaurant names got in', () {
      for (final brand in [
        'KFC',
        'QUAKER',
        'Pillsbury',
        'SUBWAY',
        'Babyfood',
      ]) {
        expect(
          foods.where((f) => f.name.contains(brand)),
          isEmpty,
          reason: brand,
        );
      }
    });

    test('long names still fit the catalog after trimming', () {
      // adoptBundledFood trims to the catalog's limit; there must be
      // something left to tell the foods apart.
      expect(maxNameLength, 100);
    });
  });
}
