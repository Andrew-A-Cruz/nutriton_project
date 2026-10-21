import '../remote/open_food_facts_client.dart';

export '../remote/open_food_facts_client.dart'
    show FoodLookupException, FoodLookupResult;

/// Food lookup for prefilling the food form. Cleans up input before it reaches
/// the client; no database access, nothing is saved here.
class FoodLookupRepository {
  FoodLookupRepository(this._client);

  final OpenFoodFactsClient _client;

  /// Barcodes are 8 to 14 digits (EAN-8, UPC-A, EAN-13, GTIN-14). Spaces and
  /// dashes are ignored. Null when [input] is not a barcode.
  static String? normalizeBarcode(String input) {
    final digits = input.replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^\d{8,14}$').hasMatch(digits) ? digits : null;
  }

  /// The product for [input], or null when not found. Throws
  /// [FoodLookupException] for a malformed barcode or a failed request.
  Future<FoodLookupResult?> findByBarcode(String input) async {
    final code = normalizeBarcode(input);
    if (code == null) {
      throw const FoodLookupException(
        'Enter the 8 to 14 digits printed under the barcode.',
      );
    }
    return _client.lookupBarcode(code);
  }

  /// Matches for [query]; empty when nothing matched. Throws
  /// [FoodLookupException] for a short query or a failed request.
  Future<List<FoodLookupResult>> searchByName(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      throw const FoodLookupException('Type at least 2 letters to search.');
    }
    return _client.searchByName(trimmed);
  }
}
