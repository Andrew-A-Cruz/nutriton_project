import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bundled_foods.dart';

import '../data/database/app_database.dart';
import '../data/database/daos/log_dao.dart';
import '../data/database/daos/meal_dao.dart';
import 'infrastructure_providers.dart';

/// Active foods whose name contains [search], by name. Re-emits on every write.
final foodSearchProvider = StreamProvider.family<List<FoodItem>, String>(
  (ref, search) =>
      ref.watch(catalogRepositoryProvider).watchFoods(search: search),
);

/// Active meal templates, by name.
final mealsProvider = StreamProvider<List<Meal>>(
  (ref) => ref.watch(catalogRepositoryProvider).watchMeals(),
);

/// The items of one meal template, in order.
final mealItemsProvider = StreamProvider.family<List<MealItemRow>, String>(
  (ref, mealId) => ref.watch(catalogRepositoryProvider).watchMealItems(mealId),
);

/// Starred active foods, then starred active meals, each by name.
final favoriteSourcesProvider = Provider<List<RecentSource>>((ref) {
  final foods = ref.watch(foodSearchProvider('')).value ?? const [];
  final meals = ref.watch(mealsProvider).value ?? const [];
  return [
    for (final f in foods)
      if (f.favorite) RecentSource.food(f),
    for (final m in meals)
      if (m.favorite) RecentSource.meal(m),
  ];
});

/// A food's named portions, smallest first.
final foodServingsProvider = StreamProvider.family<List<FoodServing>, String>(
  (ref, foodId) => ref.watch(catalogRepositoryProvider).watchServings(foodId),
);

/// Where the starter foods are bundled (made by `tool/make_generic_foods.py`).
const genericFoodsAsset = 'assets/foods/generic_foods.tsv';

/// The text of the bundled starter foods. Tests override it with a few
/// lines.
final genericFoodsSourceProvider = Provider<Future<String> Function()>(
  (ref) =>
      () => rootBundle.loadString(genericFoodsAsset),
);

/// The bundled starter foods, read once, the first time a search needs
/// them, and kept for the session.
final genericFoodsProvider = FutureProvider<List<BundledFood>>((ref) async {
  ref.keepAlive();
  return parseBundledFoods(await ref.watch(genericFoodsSourceProvider)());
});
