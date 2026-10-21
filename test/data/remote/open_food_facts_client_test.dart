import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutriton_project/data/remote/open_food_facts_client.dart';
import 'package:nutriton_project/data/repositories/food_lookup_repository.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('parseOffProduct', () {
    test('scales per-100g nutriments to serving_quantity', () {
      final r = parseOffProduct({
        'code': '123',
        'product_name': 'Granola',
        'brands': 'Acme, Other',
        'serving_quantity': 40,
        'nutriments': {
          'energy-kcal_100g': 450,
          'proteins_100g': 10,
          'carbohydrates_100g': 60,
          'fat_100g': 15,
        },
      })!;
      expect(r.name, 'Granola');
      expect(r.brand, 'Acme');
      expect(r.servingWeightG, 40);
      expect(r.hasServingSize, isTrue);
      expect(r.perServing.calories, 180);
      expect(r.perServing.protein, 4);
      expect(r.perServing.carbs, 24);
      expect(r.perServing.fat, 6);
    });

    test('uses 100 g when serving_quantity is missing, zero or junk', () {
      for (final q in [null, 0, '', 'abc', -5]) {
        final r = parseOffProduct({
          'product_name': 'Rice',
          'serving_quantity': q,
          'nutriments': {'energy-kcal_100g': 130},
        })!;
        expect(r.servingWeightG, 100, reason: '$q');
        expect(r.hasServingSize, isFalse);
        expect(r.perServing.calories, 130);
      }
    });

    test('accepts numbers sent as strings, including a decimal comma', () {
      final r = parseOffProduct({
        'product_name': 'Yogurt',
        'serving_quantity': '125',
        'nutriments': {
          'energy-kcal_100g': '60',
          'proteins_100g': '3,5',
          'fat_100g': '2.0',
        },
      })!;
      expect(r.servingWeightG, 125);
      expect(r.perServing.calories, 75);
      expect(r.perServing.protein, 4.4);
      expect(r.perServing.fat, 2.5);
    });

    test('falls back to kJ when kcal is missing', () {
      final r = parseOffProduct({
        'product_name': 'Bar',
        'nutriments': {'energy_100g': 418.4},
      })!;
      expect(r.perServing.calories, 100);
    });

    test('missing nutrients are zero; no nutriments at all is flagged', () {
      final partial = parseOffProduct({
        'product_name': 'Water+',
        'nutriments': {'carbohydrates_100g': 5},
      })!;
      expect(partial.hasNutrition, isTrue);
      expect(partial.perServing.calories, 0);
      expect(partial.perServing.carbs, 5);

      final none = parseOffProduct({'product_name': 'Mystery'})!;
      expect(none.hasNutrition, isFalse);
      expect(none.perServing.calories, 0);

      final wrongType = parseOffProduct({
        'product_name': 'Odd',
        'nutriments': 'nope',
      })!;
      expect(wrongType.hasNutrition, isFalse);
    });

    test('negative values count as missing', () {
      final r = parseOffProduct({
        'product_name': 'Odd',
        'nutriments': {'fat_100g': -3},
      })!;
      expect(r.hasNutrition, isFalse);
      expect(r.perServing.fat, 0);
    });

    test('uses generic_name when product_name is blank; null with no name', () {
      expect(
        parseOffProduct({'product_name': '  ', 'generic_name': 'Oats'})!.name,
        'Oats',
      );
      expect(parseOffProduct({'product_name': ''}), isNull);
      expect(parseOffProduct({}), isNull);
    });

    test('falls back to the looked-up barcode', () {
      final r = parseOffProduct({
        'product_name': 'X',
      }, fallbackBarcode: '99999999')!;
      expect(r.barcode, '99999999');
    });
  });

  group('OpenFoodFactsClient', () {
    test('lookupBarcode sends User-Agent and parses the product', () async {
      late http.Request seen;
      final client = OpenFoodFactsClient(
        MockClient((req) async {
          seen = req;
          return _json({
            'status': 1,
            'product': {
              'code': '3017620422003',
              'product_name': 'Spread',
              'nutriments': {'energy-kcal_100g': 539},
            },
          });
        }),
      );
      final r = await client.lookupBarcode('3017620422003');
      expect(r!.name, 'Spread');
      expect(seen.url.host, 'world.openfoodfacts.org');
      expect(seen.url.path, '/api/v2/product/3017620422003.json');
      expect(seen.headers['User-Agent'], offUserAgent);
      expect(offUserAgent, contains('NutritonFoodLog'));
    });

    test('unknown barcode is null (status 0 or HTTP 404)', () async {
      final zero = OpenFoodFactsClient(
        MockClient((_) async => _json({'status': 0})),
      );
      expect(await zero.lookupBarcode('12345678'), isNull);
      final nf = OpenFoodFactsClient(
        MockClient((_) async => _json({'status': 0}, 404)),
      );
      expect(await nf.lookupBarcode('12345678'), isNull);
    });

    test(
      'searchByName skips nameless products and tolerates no list',
      () async {
        late http.Request seen;
        final client = OpenFoodFactsClient(
          MockClient((req) async {
            seen = req;
            return _json({
              'products': [
                {'product_name': 'Oat milk'},
                {'product_name': ''},
                'garbage',
                {'product_name': 'Oat bar'},
              ],
            });
          }),
        );
        final r = await client.searchByName('oat');
        expect(r.map((e) => e.name), ['Oat milk', 'Oat bar']);
        expect(seen.url.queryParameters['search_terms'], 'oat');
        expect(seen.headers['User-Agent'], offUserAgent);

        final none = OpenFoodFactsClient(MockClient((_) async => _json({})));
        expect(await none.searchByName('oat'), isEmpty);
      },
    );

    test('errors become FoodLookupException', () async {
      Future<void> expectFails(MockClient mock) => expectLater(
        OpenFoodFactsClient(mock).searchByName('oat'),
        throwsA(isA<FoodLookupException>()),
      );
      await expectFails(MockClient((_) async => _json({}, 500)));
      await expectFails(MockClient((_) async => http.Response('<html>', 200)));
      await expectFails(
        MockClient((_) async => throw http.ClientException('x')),
      );
      await expectLater(
        OpenFoodFactsClient(
          MockClient((_) => Completer<http.Response>().future),
          timeout: const Duration(milliseconds: 10),
        ).lookupBarcode('12345678'),
        throwsA(isA<FoodLookupException>()),
      );
    });
  });

  group('FoodLookupRepository', () {
    test('normalizeBarcode', () {
      expect(
        FoodLookupRepository.normalizeBarcode(' 3017 6204-22003 '),
        '3017620422003',
      );
      expect(FoodLookupRepository.normalizeBarcode('1234567'), isNull);
      expect(FoodLookupRepository.normalizeBarcode('abc12345678'), isNull);
      expect(FoodLookupRepository.normalizeBarcode('123456789012345'), isNull);
    });

    test('rejects bad input without calling the network', () async {
      var calls = 0;
      final repo = FoodLookupRepository(
        OpenFoodFactsClient(
          MockClient((_) async {
            calls++;
            return _json({});
          }),
        ),
      );
      await expectLater(
        repo.findByBarcode('12'),
        throwsA(isA<FoodLookupException>()),
      );
      await expectLater(
        repo.searchByName(' a '),
        throwsA(isA<FoodLookupException>()),
      );
      expect(calls, 0);
    });
  });
}
