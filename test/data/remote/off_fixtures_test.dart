import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/remote/open_food_facts_client.dart';

/// The mapper against saved Open Food Facts replies in `test/fixtures/off`.
void main() {
  FoodLookupResult load(String name) {
    final json =
        jsonDecode(File('test/fixtures/off/$name.json').readAsStringSync())
            as Map<String, dynamic>;
    return parseOffProduct(
      json['product'] as Map<String, dynamic>,
      fallbackBarcode: json['code'] as String?,
    )!;
  }

  test('complete: per-serving macros, fiber, sugar and sodium in mg', () {
    final r = load('complete');
    expect(r.name, 'Hazelnut spread');
    expect(r.brand, 'Acme Foods');
    expect(r.barcode, '3017620422003');
    expect(r.hasNutrition, isTrue);
    expect(r.hasServingSize, isTrue);
    expect(r.servingWeightG, 15);
    expect(r.perServing.calories, 81);
    expect(r.perServing.protein, 0.9);
    expect(r.perServing.carbs, 8.6);
    expect(r.perServing.fat, 4.6);
    expect(r.perServing.fiber, 0.5);
    expect(r.perServing.sugar, 8.4);
    // 0.0428 g per 100 g of sodium, 15 g serving: 6.42 mg.
    expect(r.perServing.sodium, 6);
  });

  test('partial: strings parsed, 100 g assumed, missing values', () {
    final r = load('partial');
    expect(r.hasNutrition, isTrue);
    expect(r.hasServingSize, isFalse);
    expect(r.servingWeightG, 100);
    expect(r.perServing.calories, 430);
    expect(r.perServing.protein, 9.5);
    expect(r.perServing.fat, 12);
    expect(r.perServing.carbs, 0);
    expect(r.perServing.fiber, isNull);
    expect(r.perServing.sugar, isNull);
    expect(r.perServing.sodium, isNull);
    expect(r.barcode, '5000000000017');
  });

  test('kJ only: converted at 4.184, sodium derived from salt', () {
    final r = load('kj_only');
    expect(r.servingWeightG, 25);
    // 1632 kJ / 4.184 = 390.06 kcal per 100 g; 25 g serving = 97.5, rounded.
    expect(r.perServing.calories, 98);
    expect(r.perServing.protein, 2);
    expect(r.perServing.carbs, 20);
    // 1.25 g salt / 2.5 = 0.5 g sodium per 100 g; 25 g = 125 mg.
    expect(r.perServing.sodium, 125);
  });

  test('no nutriments: flagged so the UI can say so', () {
    final r = load('no_nutriments');
    expect(r.hasNutrition, isFalse);
    expect(r.perServing.calories, 0);
    expect(r.perServing.fiber, isNull);
  });
}
