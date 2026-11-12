import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/menus.dart';
import '../../core/metrics.dart';
import '../../providers/menu_providers.dart';
import '../../providers/preferences_providers.dart';
import '../catalog/food_list.dart';
import '../common/error_feedback.dart';
import '../common/form_widgets.dart';

/// Where wrong menu values are reported.
const menuReportEmail = 'logbite.app@gmail.com';

/// The restaurant chains with a bundled menu. Typing searches the items of
/// every chain. [onItemTap] is called with the item picked, here or on a
/// chain's menu.
class RestaurantsView extends ConsumerStatefulWidget {
  const RestaurantsView({super.key, required this.onItemTap});

  final ValueChanged<MenuItem> onItemTap;

  @override
  ConsumerState<RestaurantsView> createState() => _RestaurantsViewState();
}

class _RestaurantsViewState extends ConsumerState<RestaurantsView> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final menus = ref.watch(menusProvider);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Restaurants')),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: CupertinoSearchTextField(
                key: const Key('restaurants-search'),
                placeholder: 'Search all restaurants',
                onChanged: (value) => setState(() => _search = value),
              ),
            ),
            Expanded(
              child: menus.when(
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (error, stack) => LoadErrorText(
                  failed: 'Could not load the restaurants',
                  error: error,
                  stack: stack,
                ),
                data: (menus) => _search.trim().isEmpty
                    ? _ChainList(menus: menus, onItemTap: widget.onItemTap)
                    : _ItemResults(
                        items: searchMenuItems(menus, _search, limit: 50),
                        search: _search,
                        onItemTap: widget.onItemTap,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChainList extends StatelessWidget {
  const _ChainList({required this.menus, required this.onItemTap});

  final MenuCatalog menus;
  final ValueChanged<MenuItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    if (menus.chains.isEmpty) {
      return const CatalogEmptyText('No restaurant menus are available.');
    }
    return ListView.builder(
      itemCount: menus.chains.length,
      itemBuilder: (context, i) {
        final chain = menus.chains[i];
        return CupertinoListTile(
          key: Key('chain-${chain.id}'),
          title: Text(chain.name),
          trailing: const CupertinoListTileChevron(),
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => ChainMenuView(chain: chain, onItemTap: onItemTap),
            ),
          ),
        );
      },
    );
  }
}

/// Items found across every chain, each with its chain beneath.
class _ItemResults extends StatelessWidget {
  const _ItemResults({
    required this.items,
    required this.search,
    required this.onItemTap,
  });

  final List<MenuItem> items;
  final String search;
  final ValueChanged<MenuItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return CatalogEmptyText('No menu items match "${search.trim()}".');
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return CupertinoListTile(
          key: Key('menu-result-$i'),
          title: Text(item.name),
          subtitle: Text(
            '${item.chainName} · '
            '${Metric.calories.format(item.perItem.calories)} kcal',
          ),
          trailing: const Icon(CupertinoIcons.add_circled),
          onTap: () => onItemTap(item),
        );
      },
    );
  }
}

/// One chain's menu, grouped by category, with a search within it and where
/// the values come from.
class ChainMenuView extends ConsumerStatefulWidget {
  const ChainMenuView({
    super.key,
    required this.chain,
    required this.onItemTap,
  });

  final MenuChain chain;
  final ValueChanged<MenuItem> onItemTap;

  @override
  ConsumerState<ChainMenuView> createState() => _ChainMenuViewState();
}

class _ChainMenuViewState extends ConsumerState<ChainMenuView> {
  String _search = '';

  Future<void> _report() async {
    final chain = widget.chain;
    final url = Uri(
      scheme: 'mailto',
      path: menuReportEmail,
      query:
          'subject=${Uri.encodeComponent('Wrong menu value: ${chain.name}')}',
    );
    try {
      await ref.read(linkOpenerProvider)(url);
    } catch (e, stack) {
      if (!mounted) return;
      reportError(ref, e, stack, 'Could not open Mail');
      await showErrorDialog(
        context,
        'Could not open Mail. Write to $menuReportEmail.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chain = widget.chain;
    final unit = ref.watch(preferencesProvider.select((s) => s.displayUnit));
    final searching = _search.trim().isNotEmpty;
    final found = searching
        ? {
            for (final item in searchMenuItems(
              ref.watch(menusProvider).value ?? MenuCatalog.empty,
              _search,
              chainId: chain.id,
              limit: chain.items.length,
            ))
              item.id,
          }
        : null;
    final items = found == null
        ? chain.items
        : [
            for (final item in chain.items)
              if (found.contains(item.id)) item,
          ];
    // Category headers and items, flattened so the list builds lazily.
    final rows = <Widget>[];
    for (final category in chain.categories) {
      final inCategory = [
        for (final item in items)
          if (item.category == category) item,
      ];
      if (inCategory.isEmpty) continue;
      rows.add(_CategoryHeader(category));
      for (final item in inCategory) {
        rows.add(
          CupertinoListTile(
            key: Key('menu-item-${item.id.split('/').last}'),
            title: Text(item.name),
            subtitle: Text(
              [
                '${Metric.calories.format(item.perItem.calories)} kcal',
                if (item.servingWeightG case final grams?)
                  formatWeight(grams, unit),
              ].join(' · '),
            ),
            trailing: const Icon(CupertinoIcons.add_circled),
            onTap: () => widget.onItemTap(item),
          ),
        );
      }
    }
    if (rows.isEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No items match "${_search.trim()}".',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
      );
    }
    rows.add(_Attribution(chain: chain, onReport: _report));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(chain.name)),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: CupertinoSearchTextField(
                key: const Key('chain-search'),
                placeholder: 'Search ${chain.name}',
                onChanged: (value) => setState(() => _search = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                key: const Key('chain-menu-list'),
                itemCount: rows.length,
                itemBuilder: (context, i) => rows[i],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader(this.category);

  final String category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

/// Where the chain's values come from and when they were read, with a way
/// to report a wrong one.
class _Attribution extends StatelessWidget {
  const _Attribution({required this.chain, required this.onReport});

  final MenuChain chain;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Values from ${chain.name}, checked '
            '${checkedMonthLabel(chain.checkedAt)}. Recipes change.',
            key: const Key('menu-attribution'),
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          CupertinoButton(
            key: const Key('report-menu-value'),
            padding: EdgeInsets.zero,
            onPressed: onReport,
            child: const Text(
              'Report a wrong value',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
