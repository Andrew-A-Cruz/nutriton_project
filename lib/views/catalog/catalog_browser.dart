import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/daos/log_dao.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/log_providers.dart';
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
  });

  final ValueChanged<FoodItem> onFoodTap;
  final ValueChanged<Meal> onMealTap;
  final bool archivable;

  /// Shows recently or frequently logged foods and meals above the list (when
  /// not searching).
  final bool showRecent;

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
          child: CupertinoSearchTextField(
            key: const Key('catalog-search'),
            placeholder: 'Search',
            onChanged: (value) => setState(() => _search = value),
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
        Expanded(
          child: switch (_section) {
            CatalogSection.foods => FoodList(
              search: _search,
              onTap: widget.onFoodTap,
              archivable: widget.archivable,
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
