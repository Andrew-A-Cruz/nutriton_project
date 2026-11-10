import 'package:flutter_riverpod/flutter_riverpod.dart';

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
