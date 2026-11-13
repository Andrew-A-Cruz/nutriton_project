import '../../core/date_key.dart';
import '../../core/meal_slot.dart';
import '../../core/shortcuts.dart';
import '../database/app_database.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/log_repository.dart';
import 'shortcuts_bridge.dart';

/// Logs what Siri was asked to log, on today's date in the slot for the time
/// of day: a saved meal as saved, or a food at the servings last logged (one
/// if never).
class ShortcutLogger {
  ShortcutLogger(this._db);

  final AppDatabase _db;

  /// Logs [request] and returns the name logged, or null when it was too old
  /// (see [shortcutRequestLifetime]) or names nothing that can be logged: a
  /// deleted or archived item, a recipe (which needs a portion), or an empty
  /// meal.
  Future<String?> log(ShortcutRequest request, {required DateTime now}) async {
    final age = now.difference(request.at);
    if (age.isNegative || age > shortcutRequestLifetime) return null;
    final target = ShortcutItem.parseId(request.itemId);
    if (target == null) return null;
    final date = todayKey(now);
    final slot = MealSlot.forTime(now);
    final catalog = CatalogRepository(_db);
    final log = LogRepository(_db);
    switch (target.kind) {
      case ShortcutItemKind.meal:
        final meal = await catalog.findMeal(target.targetId);
        if (meal == null || meal.archived || meal.cookedWeightG != null) {
          return null;
        }
        final rows = await catalog.findMealItems(meal.id);
        if (rows.isEmpty) return null;
        await log.logMeal(
          logDate: date,
          meal: meal,
          mealSlot: slot,
          items: [
            for (final r in rows)
              MealItemInput(foodItemId: r.food.id, weightG: r.link.weightG),
          ],
        );
        return meal.name;
      case ShortcutItemKind.food:
        final food = await catalog.findFood(target.targetId);
        if (food == null || food.archived) return null;
        await log.logFood(
          logDate: date,
          food: food,
          servings: await log.lastServingsFor(food.id) ?? 1,
          mealSlot: slot,
        );
        return food.name;
    }
  }
}
