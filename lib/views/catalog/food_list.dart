import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bundled_foods.dart';
import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../data/database/app_database.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/infrastructure_providers.dart';
import '../common/archivable_list.dart';
import '../common/error_feedback.dart';
import '../common/form_widgets.dart';

/// Active catalog foods matching [search], by name.
class FoodList extends ConsumerWidget {
  const FoodList({
    super.key,
    required this.search,
    required this.onTap,
    this.archivable = false,
    this.onBundledTap,
  });

  /// Shows matching starter foods under the catalog's own while searching,
  /// when set. Called with the one tapped.
  final ValueChanged<BundledFood>? onBundledTap;

  final String search;
  final ValueChanged<FoodItem> onTap;
  final bool archivable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foods = ref.watch(foodSearchProvider(search));

    return foods.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, stack) => LoadErrorText(
        failed: 'Could not load foods',
        error: error,
        stack: stack,
      ),
      data: (rows) {
        final bundledTap = onBundledTap;
        final bundled = bundledTap == null || search.trim().isEmpty
            ? const <BundledFood>[]
            : searchBundledFoods(
                ref.watch(genericFoodsProvider).value ?? const [],
                search,
                // A starter food already copied in shows once, as the
                // catalog's own.
                exclude: {for (final f in rows) f.name.toLowerCase()},
              );
        final footer = [
          if (bundled.isNotEmpty) const _BundledHeader(),
          for (final (i, food) in bundled.indexed)
            CupertinoListTile(
              key: Key('bundled-food-$i'),
              title: Text(food.name),
              subtitle: Text(
                '${Metric.calories.format(food.per100g.calories)} kcal per '
                '100 g',
              ),
              trailing: const Icon(CupertinoIcons.add_circled),
              onTap: () => bundledTap!(food),
            ),
        ];
        if (rows.isEmpty && footer.isEmpty) {
          return CatalogEmptyText(
            search.trim().isEmpty
                ? 'No foods yet. Tap + to add one.'
                : 'No foods match "${search.trim()}".',
          );
        }
        return ArchivableList<FoodItem>(
          items: rows,
          idOf: (food) => food.id,
          footer: footer,
          onArchive: archivable
              ? (food) => ref
                    .read(catalogRepositoryProvider)
                    .setFoodArchived(food.id, archived: true)
              : null,
          rowBuilder: (context, food) => CupertinoListTile(
            title: Text(food.name),
            subtitle: Text(
              [
                ?food.brand,
                '${Metric.calories.format(food.calories)} kcal per '
                    '${formatWeight(food.servingWeightG, _foodUnit(food))}',
              ].join(' · '),
            ),
            trailing: FavoriteButton(
              key: Key('favorite-food-${food.id}'),
              favorite: food.favorite,
              onPressed: () => ref
                  .read(catalogRepositoryProvider)
                  .setFoodFavorite(food.id, favorite: !food.favorite),
            ),
            onTap: () => onTap(food),
          ),
        );
      },
    );
  }
}

/// The heading above the starter foods, with where they come from.
class _BundledHeader extends StatelessWidget {
  const _BundledHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        'COMMON FOODS (USDA FoodData Central)',
        key: const Key('bundled-foods-header'),
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

/// The food's own display unit (not the user's setting).
WeightUnit _foodUnit(FoodItem food) =>
    WeightUnit.values.asNameMap()[food.displayUnit] ?? WeightUnit.g;

/// A star that pins a food or meal to the top of Add Food.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.favorite,
    required this.onPressed,
  });

  final bool favorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: favorite ? 'Remove from favorites' : 'Add to favorites',
      button: true,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(44),
        onPressed: onPressed,
        child: Icon(
          favorite ? CupertinoIcons.star_fill : CupertinoIcons.star,
          color: favorite
              ? CupertinoColors.systemYellow.resolveFrom(context)
              : CupertinoColors.tertiaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

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
