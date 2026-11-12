import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bundled_foods.dart';
import '../../core/menus.dart';
import '../../data/database/app_database.dart';
import '../../data/database/daos/log_dao.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/log_providers.dart';
import '../../providers/menu_providers.dart';
import 'food_list.dart';
import 'meal_list.dart';

enum CatalogSection { foods, meals }

/// Foods / Meals switch, a search field, and the matching list. Shared by the
/// Catalog tab and the Add Food sheet. Expects a bounded height.
class CatalogBrowser extends StatefulWidget {
  const CatalogBrowser({
    super.key,
    required this.onFoodTap,
    required this.onMealTap,
    this.archivable = false,
    this.showRecent = false,
    this.onScan,
    this.onSearchOnline,
    this.onBundledFoodTap,
    this.onRestaurants,
    this.onMenuItemTap,
  });

  /// Shows a "Restaurants" row above the foods when not searching, when set
  /// and there are bundled menus.
  final VoidCallback? onRestaurants;

  /// Lists matching restaurant menu items under the starter foods while
  /// searching foods, when set. Called with the one tapped.
  final ValueChanged<MenuItem>? onMenuItemTap;

  /// Lists matching starter foods under the catalog's own while searching
  /// foods, when set. Called with the one tapped.
  final ValueChanged<BundledFood>? onBundledFoodTap;

  final ValueChanged<FoodItem> onFoodTap;
  final ValueChanged<Meal> onMealTap;
  final bool archivable;

  /// Shows recently or frequently logged foods and meals above the list (when
  /// not searching).
  final bool showRecent;

  /// Shows a scan button beside the search field when set.
  final VoidCallback? onScan;

  /// Shows a "Search Open Food Facts" row while searching foods, when set.
  /// Called with the search text.
  final ValueChanged<String>? onSearchOnline;

  @override
  State<CatalogBrowser> createState() => _CatalogBrowserState();
}

class _CatalogBrowserState extends State<CatalogBrowser> {
  CatalogSection _section = CatalogSection.foods;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: CupertinoSlidingSegmentedControl<CatalogSection>(
            key: const Key('catalog-section'),
            groupValue: _section,
            children: const {
              CatalogSection.foods: Text('Foods'),
              CatalogSection.meals: Text('Meals'),
            },
            onValueChanged: (section) {
              if (section != null) setState(() => _section = section);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: CupertinoSearchTextField(
                  key: const Key('catalog-search'),
                  placeholder: 'Search',
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
              if (widget.onScan != null)
                Semantics(
                  label: 'Scan a barcode',
                  button: true,
                  excludeSemantics: true,
                  child: CupertinoButton(
                    key: const Key('catalog-scan'),
                    padding: const EdgeInsets.only(left: 8),
                    minimumSize: const Size.square(44),
                    onPressed: widget.onScan,
                    child: const Icon(CupertinoIcons.barcode_viewfinder),
                  ),
                ),
            ],
          ),
        ),
        if (widget.showRecent && _search.trim().isEmpty) ...[
          FavoriteSources(
            onFoodTap: widget.onFoodTap,
            onMealTap: widget.onMealTap,
          ),
          RecentSources(
            onFoodTap: widget.onFoodTap,
            onMealTap: widget.onMealTap,
          ),
        ],
        if (widget.onSearchOnline case final searchOnline?
            when _section == CatalogSection.foods && _search.trim().isNotEmpty)
          CupertinoListTile(
            key: const Key('search-online'),
            leading: const Icon(CupertinoIcons.globe),
            title: Text('Search Open Food Facts for "${_search.trim()}"'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => searchOnline(_search.trim()),
          ),
        if (widget.onRestaurants case final openRestaurants?
            when _section == CatalogSection.foods && _search.trim().isEmpty)
          _RestaurantsRow(onTap: openRestaurants),
        Expanded(
          child: switch (_section) {
            CatalogSection.foods => FoodList(
              search: _search,
              onTap: widget.onFoodTap,
              archivable: widget.archivable,
              onBundledTap: widget.onBundledFoodTap,
              onMenuTap: widget.onMenuItemTap,
            ),
            CatalogSection.meals => MealList(
              search: _search,
              onTap: widget.onMealTap,
              archivable: widget.archivable,
            ),
          },
        ),
      ],
    );
  }
}

/// The way into the restaurant menus. Hidden when none are bundled.
class _RestaurantsRow extends ConsumerWidget {
  const _RestaurantsRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chains = ref.watch(menusProvider).value?.chains ?? const [];
    if (chains.isEmpty) return const SizedBox.shrink();
    return CupertinoListTile(
      key: const Key('restaurants-entry'),
      leading: const Icon(CupertinoIcons.building_2_fill),
      title: const Text('Restaurants'),
      trailing: const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }
}

/// Starred foods and meals, as a strip above Recent. Hidden when there are
/// none.
class FavoriteSources extends ConsumerWidget {
  const FavoriteSources({
    super.key,
    required this.onFoodTap,
    required this.onMealTap,
  });

  final ValueChanged<FoodItem> onFoodTap;
  final ValueChanged<Meal> onMealTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(favoriteSourcesProvider);
    if (sources.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('favorite-sources'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            'FAVORITES',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
        _SourceStrip(
          sources: sources,
          keyPrefix: 'pinned',
          onFoodTap: onFoodTap,
          onMealTap: onMealTap,
        ),
      ],
    );
  }
}

/// Logged-before or starred sources as a row of buttons, scrolling sideways.
class _SourceStrip extends StatelessWidget {
  const _SourceStrip({
    required this.sources,
    required this.keyPrefix,
    required this.onFoodTap,
    required this.onMealTap,
  });

  final List<RecentSource> sources;

  /// Each button is keyed '[keyPrefix]-food-ID' or '[keyPrefix]-meal-ID'.
  final String keyPrefix;
  final ValueChanged<FoodItem> onFoodTap;
  final ValueChanged<Meal> onMealTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final source in sources)
            CupertinoButton(
              key: Key(
                source.food != null
                    ? '$keyPrefix-food-${source.id}'
                    : '$keyPrefix-meal-${source.id}',
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              onPressed: () {
                final food = source.food;
                if (food != null) {
                  onFoodTap(food);
                } else {
                  onMealTap(source.meal!);
                }
              },
              child: Text(source.name),
            ),
        ],
      ),
    );
  }
}

enum _SourceRanking { recent, frequent }

/// A horizontal strip of the foods and meals logged before, newest first or
/// most often in the last [frequentWindowDays] days. Hidden until something has
/// been logged.
class RecentSources extends ConsumerStatefulWidget {
  const RecentSources({
    super.key,
    required this.onFoodTap,
    required this.onMealTap,
  });

  final ValueChanged<FoodItem> onFoodTap;
  final ValueChanged<Meal> onMealTap;

  @override
  ConsumerState<RecentSources> createState() => _RecentSourcesState();
}

class _RecentSourcesState extends ConsumerState<RecentSources> {
  _SourceRanking _ranking = _SourceRanking.recent;

  @override
  Widget build(BuildContext context) {
    // Frequent is a subset of recent, so recent being empty means both are.
    final recent = ref.watch(recentSourcesProvider).value ?? const [];
    if (recent.isEmpty) return const SizedBox.shrink();
    final sources = _ranking == _SourceRanking.recent
        ? recent
        : ref.watch(frequentSourcesProvider).value ?? const [];
    return Column(
      key: const Key('recent-foods'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<_SourceRanking>(
              key: const Key('recent-ranking'),
              groupValue: _ranking,
              children: const {
                _SourceRanking.recent: Text('Recent'),
                _SourceRanking.frequent: Text('Frequent'),
              },
              onValueChanged: (ranking) {
                if (ranking != null) setState(() => _ranking = ranking);
              },
            ),
          ),
        ),
        if (sources.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Nothing logged in the last $frequentWindowDays days.',
              key: const Key('recent-empty'),
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          )
        else
          _SourceStrip(
            sources: sources,
            keyPrefix: 'recent',
            onFoodTap: widget.onFoodTap,
            onMealTap: widget.onMealTap,
          ),
      ],
    );
  }
}
