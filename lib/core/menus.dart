/// Restaurant menus bundled with the app: reading the bundled file and
/// searching it. Pure Dart.
library;

import 'dart:convert';

import 'nutrition_math.dart';
import 'search.dart';

/// One item on a chain's menu. It is not in the catalog until the user picks
/// it.
class MenuItem {
  const MenuItem({
    required this.id,
    required this.chainId,
    required this.chainName,
    required this.name,
    required this.category,
    required this.perItem,
    this.servingWeightG,
  });

  /// `"<chain id>/<item id>"`. Permanent: catalog foods point at it.
  final String id;
  final String chainId;
  final String chainName;
  final String name;
  final String category;

  /// Values for the item as served. Fiber, sugar and sodium are null when
  /// the chain does not publish them.
  final Macros perItem;

  /// The item's weight in grams, or null when the chain publishes none. It
  /// is then counted in items only.
  final double? servingWeightG;
}

/// One restaurant chain and its menu.
class MenuChain {
  const MenuChain({
    required this.id,
    required this.name,
    required this.source,
    required this.checkedAt,
    required this.items,
  });

  final String id;
  final String name;

  /// Where the values were published.
  final String source;

  /// The day the source was read, as `yyyy-MM-dd`.
  final String checkedAt;

  /// In the file's order.
  final List<MenuItem> items;

  /// The items' categories, in the order they first appear.
  List<String> get categories =>
      {for (final item in items) item.category}.toList();
}

/// Every bundled menu.
class MenuCatalog {
  MenuCatalog({required this.version, required List<MenuChain> chains})
    : chains = List.unmodifiable(chains),
      _byId = {
        for (final chain in chains)
          for (final item in chain.items) item.id: item,
      };

  /// No menus: the feature is hidden.
  static final MenuCatalog empty = MenuCatalog(version: 0, chains: const []);

  /// Raised by one whenever the file's values change.
  final int version;

  /// By name, ignoring case.
  final List<MenuChain> chains;

  final Map<String, MenuItem> _byId;

  MenuItem? itemById(String id) => _byId[id];
}

final _slug = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

/// Reads the bundled menus (the format is in the README, under Restaurant
/// menus). A chain or an item that breaks a rule is skipped, as is a repeated
/// id (the first is kept) and a chain left with no items. Unknown keys are
/// ignored.
///
/// Throws a [FormatException] only when the file as a whole is unusable: not
/// JSON, no positive whole-number `version`, or `chains` is not a list.
MenuCatalog parseMenus(String source) {
  final Object? root = jsonDecode(source);
  if (root is! Map<String, dynamic>) {
    throw const FormatException('The menus file is not a JSON object');
  }
  final version = root['version'];
  if (version is! int || version < 1) {
    throw const FormatException('The menus file has no version');
  }
  final rawChains = root['chains'];
  if (rawChains is! List) {
    throw const FormatException('The menus file has no chains');
  }
  final chains = <MenuChain>[];
  final seen = <String>{};
  for (final raw in rawChains) {
    final chain = _chain(raw);
    if (chain != null && seen.add(chain.id)) chains.add(chain);
  }
  chains.sort((a, b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });
  return MenuCatalog(version: version, chains: chains);
}

MenuChain? _chain(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final id = raw['id'];
  final name = _text(raw['name']);
  final rawItems = raw['items'];
  if (id is! String || !_slug.hasMatch(id) || name == null) return null;
  if (rawItems is! List) return null;
  final items = <MenuItem>[];
  final seen = <String>{};
  for (final rawItem in rawItems) {
    final item = _item(rawItem, chainId: id, chainName: name);
    if (item != null && seen.add(item.id)) items.add(item);
  }
  if (items.isEmpty) return null;
  return MenuChain(
    id: id,
    name: name,
    source: _text(raw['source']) ?? '',
    checkedAt: _text(raw['checkedAt']) ?? '',
    items: List.unmodifiable(items),
  );
}

MenuItem? _item(
  Object? raw, {
  required String chainId,
  required String chainName,
}) {
  if (raw is! Map<String, dynamic>) return null;
  final id = raw['id'];
  final name = _text(raw['name']);
  final category = _text(raw['category']);
  if (id is! String || !_slug.hasMatch(id)) return null;
  if (name == null || name.length < 2 || name.length > 100) return null;
  if (category == null) return null;
  final calories = _nonNegative(raw['calories']);
  final protein = _nonNegative(raw['protein']);
  final carbs = _nonNegative(raw['carbs']);
  final fat = _nonNegative(raw['fat']);
  final weight = _nonNegative(raw['servingWeightG']);
  if (calories == null || protein == null || carbs == null || fat == null) {
    return null;
  }
  // Absent means the chain publishes no weight; present must be positive.
  if (raw.containsKey('servingWeightG') && (weight == null || weight <= 0)) {
    return null;
  }
  // Absent means not recorded; present must be a valid number.
  for (final key in const ['fiber', 'sugar', 'sodium']) {
    if (raw.containsKey(key) && _nonNegative(raw[key]) == null) return null;
  }
  return MenuItem(
    id: '$chainId/$id',
    chainId: chainId,
    chainName: chainName,
    name: name,
    category: category,
    perItem: Macros(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: _nonNegative(raw['fiber']),
      sugar: _nonNegative(raw['sugar']),
      sodium: _nonNegative(raw['sodium']),
    ),
    servingWeightG: weight,
  );
}

/// [value] trimmed, or null when it is not a string or is empty.
String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _nonNegative(Object? value) {
  if (value is! num) return null;
  final v = value.toDouble();
  return !v.isFinite || v < 0 ? null : v;
}

/// The items whose name and chain name together have every word of [query]
/// (see [searchWords]), best first, at most [limit]: "wendys fries" finds
/// the fries at Wendy's. Apostrophes are ignored on both sides. [chainId]
/// limits the search to one chain. An item whose name starts with the first
/// word comes before the rest, and shorter names come first within each. An
/// empty query matches nothing.
List<MenuItem> searchMenuItems(
  MenuCatalog menus,
  String query, {
  String? chainId,
  int limit = 25,
}) {
  final words = searchWords(_plain(query));
  if (words.isEmpty) return const [];
  final matches = <({MenuItem item, int rank})>[];
  for (final chain in menus.chains) {
    if (chainId != null && chain.id != chainId) continue;
    final chainName = _plain(chain.name).toLowerCase();
    for (final item in chain.items) {
      final name = _plain(item.name).toLowerCase();
      final haystack = '$name $chainName';
      if (!words.every(haystack.contains)) continue;
      matches.add((item: item, rank: name.startsWith(words.first) ? 0 : 1));
    }
  }
  matches.sort((a, b) {
    final byRank = a.rank.compareTo(b.rank);
    if (byRank != 0) return byRank;
    final byLength = a.item.name.length.compareTo(b.item.name.length);
    if (byLength != 0) return byLength;
    final byName = a.item.name.compareTo(b.item.name);
    return byName != 0 ? byName : a.item.id.compareTo(b.item.id);
  });
  return [for (final m in matches.take(limit)) m.item];
}

/// Without apostrophes, so "mcdonalds" finds "McDonald's".
String _plain(String text) => text.replaceAll(RegExp("['’]"), '');

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "November 2026" from "2026-11-20", for the attribution line. Returns
/// [checkedAt] as it is when it is not a date.
String checkedMonthLabel(String checkedAt) {
  final match = RegExp(r'^(\d{4})-(\d{2})-\d{2}$').firstMatch(checkedAt);
  final month = match == null ? null : int.parse(match[2]!);
  if (match == null || month == null || month < 1 || month > 12) {
    return checkedAt;
  }
  return '${_months[month - 1]} ${match[1]}';
}
