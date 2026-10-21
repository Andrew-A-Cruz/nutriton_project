import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../data/database/app_database.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/infrastructure_providers.dart';
import '../common/archivable_list.dart';
import '../common/form_widgets.dart';

/// Active catalog foods matching [search], by name.
class FoodList extends ConsumerWidget {
  const FoodList({
    super.key,
    required this.search,
    required this.onTap,
    this.archivable = false,
  });

  final String search;
  final ValueChanged<FoodItem> onTap;
  final bool archivable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foods = ref.watch(foodSearchProvider(search));

    return foods.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(child: Text('Could not load foods: $error')),
      data: (rows) {
        if (rows.isEmpty) {
          return CatalogEmptyText(
            search.trim().isEmpty
                ? 'No foods yet. Tap + to add one.'
                : 'No foods match "${search.trim()}".',
          );
        }
        return ArchivableList<FoodItem>(
          items: rows,
          idOf: (food) => food.id,
          onArchive: archivable
              ? (food) => ref
                    .read(catalogRepositoryProvider)
                    .setFoodArchived(food.id, archived: true)
              : null,
          rowBuilder: (context, food) => CupertinoListTile(
            title: Text(food.name),
            subtitle: Text(
              '${Metric.calories.format(food.calories)} kcal per '
              '${formatWeight(food.servingWeightG, _foodUnit(food))}',
            ),
            onTap: () => onTap(food),
          ),
        );
      },
    );
  }
}

/// The food's own display unit (not the user's setting).
WeightUnit _foodUnit(FoodItem food) =>
    WeightUnit.values.asNameMap()[food.displayUnit] ?? WeightUnit.g;

/// Centred hint for an empty catalog list.
class CatalogEmptyText extends StatelessWidget {
  const CatalogEmptyText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
