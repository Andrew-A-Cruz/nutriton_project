import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/nutrition_math.dart';

/// A product from Open Food Facts, already converted to the app's per-serving
/// model. [perServing] covers one serving of [servingWeightG] grams.
class FoodLookupResult {
  const FoodLookupResult({
    required this.name,
    this.brand,
    this.barcode,
    required this.perServing,
    required this.servingWeightG,
    required this.hasServingSize,
    required this.hasNutrition,
  });

  final String name;
  final String? brand;
  final String? barcode;
  final Macros perServing;
  final double servingWeightG;

  /// False when the product had no serving size, so 100 g was assumed.
  final bool hasServingSize;

  /// False when the product listed no nutriments at all (macros are zero).
  final bool hasNutrition;
}

/// The lookup failed for a reason other than "not found" (network, server,
/// unreadable response). [message] is fit to show the user.
class FoodLookupException implements Exception {
  const FoodLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sent with every request; Open Food Facts asks apps to identify themselves.
const offUserAgent =
    'NutritonFoodLog/1.0 (https://github.com/Andrew-A-Cruz/nutriton_project)';

const _fields =
    'code,product_name,generic_name,brands,nutriments,serving_quantity,'
    'serving_size';

/// Thin Open Food Facts client. The [http.Client] is injected so tests can use
/// a `MockClient` and never touch the network.
class OpenFoodFactsClient {
  OpenFoodFactsClient(
    this._http, {
    this.host = 'world.openfoodfacts.org',
    this.timeout = const Duration(seconds: 15),
  });

  final http.Client _http;
  final String host;
  final Duration timeout;

  /// The product with [barcode], or null when Open Food Facts has none (or it
  /// has no usable name).
  Future<FoodLookupResult?> lookupBarcode(String barcode) async {
    final uri = Uri.https(host, '/api/v2/product/$barcode.json', {
      'fields': _fields,
    });
    final response = await _get(uri, allowNotFound: true);
    if (response == null) return null;
    final json = _decode(response.body);
    if (json['status'] != 1 && json['status'] != '1') return null;
    final product = json['product'];
    if (product is! Map<String, dynamic>) return null;
    return parseOffProduct(product, fallbackBarcode: barcode);
  }

  /// Products matching [query], best first. Products without a name are
  /// skipped.
  Future<List<FoodLookupResult>> searchByName(
    String query, {
    int limit = 20,
  }) async {
    final uri = Uri.https(host, '/cgi/search.pl', {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '$limit',
      'fields': _fields,
    });
    final response = await _get(uri);
    final json = _decode(response!.body);
    final products = json['products'];
    if (products is! List) return const [];
    return [
      for (final p in products)
        if (p is Map<String, dynamic>) ?parseOffProduct(p),
    ];
  }

  Future<http.Response?> _get(Uri uri, {bool allowNotFound = false}) async {
    final http.Response response;
    try {
      response = await _http
          .get(
            uri,
            headers: {'User-Agent': offUserAgent, 'Accept': 'application/json'},
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const FoodLookupException('The lookup timed out. Try again.');
    } catch (_) {
      throw const FoodLookupException(
        'Could not reach Open Food Facts. Check your connection.',
      );
    }
    // The v2 endpoint answers 404 with a JSON body for unknown barcodes.
    if (allowNotFound && response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw FoodLookupException(
        'Open Food Facts returned an error (${response.statusCode}).',
      );
    }
    return response;
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) return json;
    } on FormatException {
      // Falls through to the error below.
    }
    throw const FoodLookupException(
      'Open Food Facts sent an unreadable reply.',
    );
  }
}

/// Converts one Open Food Facts product map. Returns null when it has no name.
/// Nutriments are per 100 g; they are scaled to `serving_quantity` grams when
/// that is present and positive, otherwise to 100 g. Missing energy and macros
/// are 0. Missing fiber, sugar and sodium are null (not recorded). Sodium comes
/// in grams and is converted to mg; with only `salt_100g`, sodium is salt / 2.5.
FoodLookupResult? parseOffProduct(
  Map<String, dynamic> product, {
  String? fallbackBarcode,
}) {
  final name = _text(product['product_name']) ?? _text(product['generic_name']);
  if (name == null) return null;
  final brand = _text(product['brands'])?.split(',').first.trim();

  final nutriments = product['nutriments'];
  final n = nutriments is Map<String, dynamic>
      ? nutriments
      : const <String, dynamic>{};

  final kcal =
      _number(n['energy-kcal_100g']) ??
      _kjToKcal(_number(n['energy-kj_100g'])) ??
      _kjToKcal(_number(n['energy_100g']));
  final protein = _number(n['proteins_100g']);
  final carbs = _number(n['carbohydrates_100g']);
  final fat = _number(n['fat_100g']);
  final hasNutrition = [kcal, protein, carbs, fat].any((v) => v != null);

  final serving = _number(product['serving_quantity']);
  final hasServing = serving != null && serving > 0;
  final grams = hasServing ? serving : 100.0;
  final scale = grams / 100;

  double scaled(double? per100, int places) =>
      roundTo((per100 ?? 0) * scale, places);
  double? scaledOrNull(double? per100, int places) =>
      per100 == null ? null : roundTo(per100 * scale, places);

  final sodiumG =
      _number(n['sodium_100g']) ??
      switch (_number(n['salt_100g'])) {
        final double salt => salt / saltPerSodium,
        null => null,
      };

  return FoodLookupResult(
    name: name,
    brand: brand == null || brand.isEmpty ? null : brand,
    barcode: _text(product['code']) ?? fallbackBarcode,
    perServing: Macros(
      calories: scaled(kcal, 0),
      protein: scaled(protein, 1),
      carbs: scaled(carbs, 1),
      fat: scaled(fat, 1),
      fiber: scaledOrNull(_number(n['fiber_100g']), 1),
      sugar: scaledOrNull(_number(n['sugars_100g']), 1),
      sodium: scaledOrNull(sodiumG == null ? null : sodiumG * 1000, 0),
    ),
    servingWeightG: grams,
    hasServingSize: hasServing,
    hasNutrition: hasNutrition,
  );
}

/// Grams of salt (NaCl) per gram of sodium.
const saltPerSodium = 2.5;

double? _kjToKcal(double? kj) => kj == null ? null : kj / 4.184;

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Open Food Facts sends numbers as numbers or strings; negatives and
/// non-finite values count as missing.
double? _number(Object? value) {
  final parsed = switch (value) {
    num() => value.toDouble(),
    String() => double.tryParse(value.trim().replaceAll(',', '.')),
    _ => null,
  };
  if (parsed == null || !parsed.isFinite || parsed < 0) return null;
  return parsed;
}
