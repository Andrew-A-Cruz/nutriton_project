import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
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
