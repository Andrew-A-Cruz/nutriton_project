import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/menus.dart';

import '../support/menu_fixture.dart';

/// A file with one chain holding [items] (and one good item, so the chain
/// survives).
String _file(List<Map<String, Object?>> items) => jsonEncode({
  'version': 3,
  'chains': [
    {
      'id': 'c',
      'name': 'Chain',
      'source': 'https://example.com',
      'checkedAt': '2026-11-20',
      'items': [_item('good'), ...items],
    },
  ],
});

Map<String, Object?> _item(
  String id, [
  Map<String, Object?> changes = const {},
]) {
  final item = <String, Object?>{
    'id': id,
    'name': 'Item $id',
    'category': 'Sides',
    'servingWeightG': 100,
    'calories': 200,
    'protein': 5,
    'carbs': 30,
    'fat': 7,
    ...changes,
  };
  item.removeWhere((key, value) => value == #absent);
  return item;
}

List<String> _ids(String source) => [
  for (final chain in parseMenus(source).chains)
    for (final item in chain.items) item.id,
];

void main() {
  group('parseMenus', () {
    test('reads chains by name and items in file order', () {
      final menus = parseMenus(menuFixture(version: 4));

      expect(menus.version, 4);
      expect(
        [for (final c in menus.chains) c.name],
        ['Example Burger', "Sample's Chicken"],
      );
      final burger = menus.chains.first;
      expect(burger.source, 'https://example.com/nutrition.pdf');
      expect(burger.checkedAt, '2026-11-20');
      expect(burger.categories, ['Burgers', 'Sides', 'Drinks']);
      final fries = burger.items[1];
      expect(fries.id, 'example-burger/fries-medium');
      expect(fries.chainId, 'example-burger');
      expect(fries.chainName, 'Example Burger');
      expect(fries.name, 'French Fries, Medium');
      expect(fries.category, 'Sides');
      expect(fries.servingWeightG, 114);
      expect(fries.perItem.calories, 320);
      expect(fries.perItem.protein, 5);
      expect(fries.perItem.carbs, 43);
      expect(fries.perItem.fat, 15);
      expect(fries.perItem.fiber, 4);
      expect(fries.perItem.sugar, 0);
      expect(fries.perItem.sodium, 260);
      expect(menus.itemById('example-burger/fries-medium'), same(fries));
      expect(menus.itemById('example-burger/nope'), isNull);
    });

    test('a nutrient left out is not recorded, which is not zero', () {
      final cola = parseMenus(
        menuFixture(),
      ).itemById('example-burger/cola-medium')!;
      expect(cola.perItem.fiber, isNull);
      expect(cola.perItem.sugar, isNull);
      expect(cola.perItem.sodium, isNull);
      expect(cola.perItem.fat, 0);
    });

    test('numbers may be whole or decimal; unknown keys are ignored', () {
      final source = _file([
        _item('a', {
          'calories': 12.5,
          'fat': 0.5,
          'allergens': ['milk'],
        }),
      ]);
      final item = parseMenus(source).itemById('c/a')!;
      expect(item.perItem.calories, 12.5);
      expect(item.perItem.fat, 0.5);
    });

    test('an item with no serving weight is kept, with none', () {
      final source = _file([
        _item('a', {'servingWeightG': #absent}),
      ]);
      expect(parseMenus(source).itemById('c/a')!.servingWeightG, isNull);
      expect(
        parseMenus(
          menuFixture(),
        ).itemById('sample-chicken/lemonade-large')!.servingWeightG,
        isNull,
      );
    });

    test('a zero calorie item is kept', () {
      expect(
        _ids(
          _file([
            _item('water', {'calories': 0, 'carbs': 0}),
          ]),
        ),
        contains('c/water'),
      );
    });

    for (final (why, changes) in <(String, Map<String, Object?>)>[
      ('a malformed id', {'id': 'Not A Slug'}),
      ('a one letter name', {'name': 'x'}),
      ('a name over 100 characters', {'name': 'x' * 101}),
      ('no name', {'name': #absent}),
      ('no category', {'category': #absent}),
      ('an empty category', {'category': '  '}),
      ('no calories', {'calories': #absent}),
      ('negative calories', {'calories': -1}),
      ('calories as text', {'calories': '200'}),
      ('no protein', {'protein': #absent}),
      ('no carbs', {'carbs': #absent}),
      ('no fat', {'fat': #absent}),
      ('negative fat', {'fat': -0.5}),
      ('a zero serving weight', {'servingWeightG': 0}),
      ('a serving weight as text', {'servingWeightG': '100'}),
      ('fiber as text', {'fiber': 'two'}),
      ('negative sugar', {'sugar': -1}),
      ('negative sodium', {'sodium': -5}),
    ]) {
      test('skips an item with $why', () {
        expect(_ids(_file([_item('bad', changes)])), ['c/good']);
      });
    }

    test('a repeated item id keeps the first', () {
      final menus = parseMenus(
        _file([
          _item('twice', {'name': 'First'}),
          _item('twice', {'name': 'Second'}),
        ]),
      );
      expect(menus.itemById('c/twice')!.name, 'First');
      expect(menus.chains.single.items, hasLength(2));
    });

    test('skips a chain with a bad id, no name or no surviving item', () {
      Map<String, Object?> chain(
        Object? id,
        Object? name,
        List<Object?> items,
      ) => {'id': id, 'name': name, 'items': items};
      final source = jsonEncode({
        'version': 1,
        'chains': [
          chain('Bad Id', 'A', [_item('a')]),
          chain('no-name', null, [_item('a')]),
          chain('empty', 'Empty', [
            _item('a', {'calories': #absent}),
          ]),
          chain('no-items', 'None', []),
          'not a chain',
          chain('kept', 'Kept', [_item('a')]),
          chain('kept', 'Kept again', [_item('b')]),
        ],
      });
      final menus = parseMenus(source);
      expect([for (final c in menus.chains) c.name], ['Kept']);
      expect(_ids(source), ['kept/a']);
    });

    test('throws when the file as a whole is unusable', () {
      for (final source in [
        'not json',
        '[]',
        '{"chains": []}',
        '{"version": 0, "chains": []}',
        '{"version": 1.5, "chains": []}',
        '{"version": "1", "chains": []}',
        '{"version": 1}',
        '{"version": 1, "chains": {}}',
      ]) {
        expect(() => parseMenus(source), throwsFormatException, reason: source);
      }
    });

    test('a file with no chains is valid and empty', () {
      final menus = parseMenus('{"version": 2, "chains": []}');
      expect(menus.version, 2);
      expect(menus.chains, isEmpty);
      expect(MenuCatalog.empty.chains, isEmpty);
    });
  });

  group('searchMenuItems', () {
    final menus = parseMenus(menuFixture());
    List<String> names(String query, {String? chainId, int limit = 25}) => [
      for (final item in searchMenuItems(
        menus,
        query,
        chainId: chainId,
        limit: limit,
      ))
        item.name,
    ];

    test('an empty search finds nothing', () {
      expect(names(''), isEmpty);
      expect(names('   '), isEmpty);
    });

    test('every word must appear, in any order, ignoring case', () {
      expect(names('FRIES medium'), ['French Fries, Medium']);
      expect(names('medium fries'), ['French Fries, Medium']);
      expect(names('fries'), ['French Fries, Medium', 'Seasoned Fries, Large']);
      expect(names('fries pizza'), isEmpty);
    });

    test('a word may match the chain name', () {
      expect(names('example fries'), ['French Fries, Medium']);
      expect(names('sample'), [
        'Lemonade, Large',
        'Chicken Tenders (3)',
        'Seasoned Fries, Large',
      ]);
    });

    test('apostrophes are ignored on both sides', () {
      expect(names('samples tenders'), ['Chicken Tenders (3)']);
      expect(names("sample's tenders"), ['Chicken Tenders (3)']);
    });

    test('a name starting with the first word comes first', () {
      // "French Fries" has "ch" too, but later in the name.
      expect(names('ch').take(2), ['Cheeseburger', 'Chicken Tenders (3)']);
      expect(names('ch'), contains('French Fries, Medium'));
      // "Cola" starts with the word; "Chicken Tenders" merely has an "o".
      expect(names('co').first, 'Cola, Medium');
    });

    test('can be limited to one chain and to a number of results', () {
      expect(names('fries', chainId: 'sample-chicken'), [
        'Seasoned Fries, Large',
      ]);
      expect(names('e', limit: 2), hasLength(2));
    });
  });

  test('checkedMonthLabel names the month', () {
    expect(checkedMonthLabel('2026-11-20'), 'November 2026');
    expect(checkedMonthLabel('2027-01-03'), 'January 2027');
    expect(checkedMonthLabel('2026-13-01'), '2026-13-01');
    expect(checkedMonthLabel('soon'), 'soon');
    expect(checkedMonthLabel(''), '');
  });

  group('the bundled menus', () {
    final source = File('assets/menus/menus.json').readAsStringSync();
    final raw = jsonDecode(source) as Map<String, dynamic>;
    final rawChains = (raw['chains'] as List).cast<Map<String, dynamic>>();
    final menus = parseMenus(source);

    test('every chain and item is read: none is skipped', () {
      expect(menus.chains, hasLength(rawChains.length));
      expect(menus.chains, isNotEmpty);
      for (final rawChain in rawChains) {
        final chain = menus.chains.singleWhere((c) => c.id == rawChain['id']);
        expect(
          chain.items,
          hasLength((rawChain['items'] as List).length),
          reason: chain.name,
        );
        expect(chain.source, startsWith('https://'), reason: chain.name);
        expect(
          checkedMonthLabel(chain.checkedAt),
          isNot(chain.checkedAt),
          reason: chain.name,
        );
      }
    });

    test('each chain file matches what is bundled', () {
      for (final chain in menus.chains) {
        final file = File('tool/menus/chains/${chain.id}.json');
        expect(file.existsSync(), isTrue, reason: chain.id);
        final items =
            ((jsonDecode(file.readAsStringSync()) as Map)['items'] as List)
                .cast<Map<String, dynamic>>();
        expect(items, hasLength(chain.items.length), reason: chain.id);
        for (final item in items) {
          final bundled = menus.itemById('${chain.id}/${item['id']}')!;
          expect(bundled.name, item['name']);
          expect(bundled.perItem.calories, item['calories']);
          expect(bundled.perItem.protein, item['protein']);
          expect(bundled.perItem.carbs, item['carbs']);
          expect(bundled.perItem.fat, item['fat']);
          expect(bundled.perItem.sodium, item['sodium']);
          expect(bundled.servingWeightG, item['servingWeightG']);
        }
      }
    });
  });
}
