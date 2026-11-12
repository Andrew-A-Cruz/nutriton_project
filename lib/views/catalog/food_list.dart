import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bundled_foods.dart';
import '../../core/menus.dart';
import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../data/database/app_database.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/infrastructure_providers.dart';
import '../../providers/menu_providers.dart';
import '../common/archivable_list.dart';
import '../common/error_feedback.dart';
import '../common/form_widgets.dart';

/// How many restaurant menu items a catalog search lists.
const maxMenuResults = 15;

/// Active catalog foods matching [search], by name.
class FoodList extends ConsumerWidget {
  const FoodList({
    super.key,
    required this.search,
    required this.onTap,
    this.archivable = false,
    this.onBundledTap,
    this.onMenuTap,
  });

  /// Shows matching restaurant menu items under the starter foods while
  /// searching, when set. Called with the one tapped.
  final ValueChanged<MenuItem>? onMenuTap;

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
        final menuTap = onMenuTap;
        // An item already copied in shows once, as the catalog's own.
        final adopted = {for (final f in rows) ?f.menuItemId};
        final menuItems = menuTap == null || search.trim().isEmpty
            ? const <MenuItem>[]
            : [
                for (final item in searchMenuItems(
                  ref.watch(menusProvider).value ?? MenuCatalog.empty,
                  search,
                  limit: maxMenuResults + adopted.length,
                ))
                  if (!adopted.contains(item.id)) item,
              ].take(maxMenuResults).toList();
        final footer = [
          if (bundled.isNotEmpty)
            const _FooterHeader(
              'COMMON FOODS (USDA FoodData Central)',
              key: Key('bundled-foods-header'),
            ),
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
          if (menuItems.isNotEmpty)
            const _FooterHeader('RESTAURANTS', key: Key('menu-foods-header')),
          for (final (i, item) in menuItems.indexed)
            CupertinoListTile(
              key: Key('menu-food-$i'),
              title: Text(item.name),
              subtitle: Text(
                '${item.chainName} · '
                '${Metric.calories.format(item.perItem.calories)} kcal',
              ),
              trailing: const Icon(CupertinoIcons.add_circled),
              onTap: () => menuTap!(item),
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
                // A restaurant item with no published weight.
                if (food.weightUnknown)
                  '${Metric.calories.format(food.calories)} kcal per item'
                else
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

/// The heading above a section of bundled foods.
class _FooterHeader extends StatelessWidget {
  const _FooterHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text,
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
