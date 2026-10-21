import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../data/database/app_database.dart';
import '../../data/database/daos/meal_dao.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/infrastructure_providers.dart';
import '../common/archivable_list.dart';
import 'food_list.dart';

/// Active meal templates whose name contains [search] (case-insensitive).
class MealList extends ConsumerWidget {
  const MealList({
    super.key,
    required this.search,
    required this.onTap,
    this.archivable = false,
  });

  final String search;
  final ValueChanged<Meal> onTap;
  final bool archivable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(mealsProvider);
    final query = search.trim().toLowerCase();

    return meals.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(child: Text('Could not load meals: $error')),
      data: (all) {
        final rows = [
          for (final m in all)
            if (query.isEmpty || m.name.toLowerCase().contains(query)) m,
        ];
        if (rows.isEmpty) {
          return CatalogEmptyText(
            query.isEmpty
                ? 'No meals yet. Tap + to build one.'
                : 'No meals match "${search.trim()}".',
          );
        }
        return ArchivableList<Meal>(
          items: rows,
          idOf: (meal) => meal.id,
          onArchive: archivable
              ? (meal) => ref
                    .read(catalogRepositoryProvider)
                    .setMealArchived(meal.id, archived: true)
              : null,
          rowBuilder: (context, meal) =>
              _MealRow(meal: meal, onTap: () => onTap(meal)),
        );
      },
    );
  }
}

/// A meal with its item count and total calories, read from its template.
class _MealRow extends ConsumerWidget {
  const _MealRow({required this.meal, required this.onTap});

  final Meal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(mealItemsProvider(meal.id)).value;
    return CupertinoListTile(
      title: Text(meal.name),
      subtitle: Text(items == null ? '' : _summary(items)),
      onTap: onTap,
    );
  }

  static String _summary(List<MealItemRow> items) {
    if (items.isEmpty) return 'No foods yet';
    final total = sumMacros(
      items.map(
        (row) => CatalogRepository.macrosForWeight(row.food, row.link.weightG),
      ),
    );
    final count = '${items.length} food${items.length == 1 ? '' : 's'}';
    return '$count · ${Metric.calories.format(total.calories)} kcal';
  }
}
