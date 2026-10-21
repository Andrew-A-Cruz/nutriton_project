import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/remote/open_food_facts_client.dart';
import '../data/repositories/food_lookup_repository.dart';

export '../data/repositories/food_lookup_repository.dart'
    show FoodLookupException, FoodLookupResult;

/// The HTTP client for lookups. Tests override this with a `MockClient`.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final foodLookupRepositoryProvider = Provider<FoodLookupRepository>(
  (ref) =>
      FoodLookupRepository(OpenFoodFactsClient(ref.watch(httpClientProvider))),
);
