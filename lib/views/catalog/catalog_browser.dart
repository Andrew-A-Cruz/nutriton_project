import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
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
        if (widget.showRecent && _search.trim().isEmpty)
          RecentSources(
            onFoodTap: widget.onFoodTap,
            onMealTap: widget.onMealTap,
          ),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final source in sources)
                  CupertinoButton(
                    key: Key(
                      source.food != null
                          ? 'recent-food-${source.id}'
                          : 'recent-meal-${source.id}',
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    onPressed: () {
                      final food = source.food;
                      if (food != null) {
                        widget.onFoodTap(food);
                      } else {
                        widget.onMealTap(source.meal!);
                      }
                    },
                    child: Text(source.name),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
