#!/usr/bin/env python3
"""Builds assets/menus/menus.json from the chain files in tool/menus/chains/.

Usage:
    python3 tool/make_menus.py            # check, and write with the next version
    python3 tool/make_menus.py --check    # check only, write nothing
    python3 tool/make_menus.py --version 7

Each chain file is the source of truth for one restaurant chain: the values
its own published nutrition document gives, with the document's address and
the day it was read. Never edit assets/menus/menus.json by hand, and never
put a value in a chain file that did not come from the chain's document.

The version goes up by one on every build whose output differs from the
bundled file. The app uses it to refresh restaurant foods a user has not
edited, so a change shipped without a new version never reaches them.

Every rule the app's reader has (lib/core/menus.dart) is checked here, so
the bundled file never holds a row the app would skip. On top of those:

  * the energy check: calories must be within 20% or 40 kcal (whichever is
    larger) of 4 x protein + 4 x carbs + 9 x fat. It catches swapped columns
    and typos. An item that fails for a real reason (sugar alcohols, alcohol,
    rounding on a tiny serving) carries "energyCheck": false and a "note"
    saying why;
  * sugar and fiber may not exceed carbs (by more than 1 g of rounding).
"""

import argparse
import datetime
import glob
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHAINS = os.path.join(ROOT, 'tool', 'menus', 'chains')
OUT = os.path.join(ROOT, 'assets', 'menus', 'menus.json')

SLUG = re.compile(r'^[a-z0-9]+(-[a-z0-9]+)*$')
REQUIRED = ('calories', 'protein', 'carbs', 'fat')
OPTIONAL = ('fiber', 'sugar', 'sodium')


def is_number(value):
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(value))


def tidy(value):
    """Whole numbers as ints, so the file is smaller and stable."""
    return int(value) if float(value) == int(value) else value


def check_item(item, errors, where):
    def fail(message):
        errors.append(f'{where}: {message}')

    name = item.get('name')
    if not isinstance(name, str) or not 2 <= len(name.strip()) <= 100:
        fail('the name must be 2 to 100 characters')
    if not isinstance(item.get('category'), str) or not item['category'].strip():
        fail('no category')
    for key in REQUIRED:
        if not is_number(item.get(key)) or item[key] < 0:
            fail(f'{key} must be a number >= 0')
    for key in OPTIONAL:
        if key in item and (not is_number(item[key]) or item[key] < 0):
            fail(f'{key} must be a number >= 0 when present')
    if 'servingWeightG' in item:
        weight = item['servingWeightG']
        if not is_number(weight) or weight <= 0:
            fail('servingWeightG must be a number > 0 when present')
    if errors and errors[-1].startswith(where):
        return
    carbs = item['carbs']
    for key in ('sugar', 'fiber'):
        if key in item and item[key] > carbs + 1:
            fail(f'{key} {item[key]} is more than carbs {carbs}')
    if item.get('energyCheck') is False:
        if not item.get('note'):
            fail('"energyCheck": false needs a "note" saying why')
        return
    calories = item['calories']
    computed = 4 * item['protein'] + 4 * carbs + 9 * item['fat']
    off = abs(calories - computed)
    if off > max(0.2 * calories, 40):
        fail(f'energy mismatch: {calories} kcal published, '
             f'{computed:g} from the macros')


def load_chain(path, errors):
    with open(path, encoding='utf-8') as f:
        chain = json.load(f)
    file_id = os.path.splitext(os.path.basename(path))[0]
    cid = chain.get('id')
    where = f'{file_id}'
    if cid != file_id or not SLUG.match(str(cid)):
        errors.append(f'{where}: the id must be a slug equal to the file name')
    if not isinstance(chain.get('name'), str) or not chain['name'].strip():
        errors.append(f'{where}: no name')
    if not str(chain.get('source', '')).startswith('https://'):
        errors.append(f'{where}: no source address')
    try:
        datetime.date.fromisoformat(str(chain.get('checkedAt')))
    except ValueError:
        errors.append(f'{where}: checkedAt must be yyyy-MM-dd')
    items = chain.get('items')
    if not isinstance(items, list) or not items:
        errors.append(f'{where}: no items')
        return None
    seen = set()
    out_items = []
    for item in items:
        iid = item.get('id')
        item_where = f'{where}/{iid} ({item.get("name")})'
        if not isinstance(iid, str) or not SLUG.match(iid):
            errors.append(f'{item_where}: the id is not a slug')
            continue
        if iid in seen:
            errors.append(f'{item_where}: duplicate id')
            continue
        seen.add(iid)
        check_item(item, errors, item_where)
        out = {
            'id': iid,
            'name': item['name'].strip() if isinstance(item.get('name'), str)
            else item.get('name'),
            'category': item.get('category'),
        }
        for key in ('servingWeightG',) + REQUIRED + OPTIONAL:
            if key in item:
                out[key] = item[key]
        out_items.append(out)
    return {
        'id': cid,
        'name': chain.get('name'),
        'source': chain.get('source'),
        'checkedAt': chain.get('checkedAt'),
        'items': out_items,
    }, len(chain.get('skipped', []))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--check', action='store_true',
                        help='check the chain files and write nothing')
    parser.add_argument('--version', type=int,
                        help='the version to write (default: the next one)')
    args = parser.parse_args()

    errors = []
    chains = []
    summary = []
    for path in sorted(glob.glob(os.path.join(CHAINS, '*.json'))):
        loaded = load_chain(path, errors)
        if loaded is None:
            continue
        chain, skipped = loaded
        chains.append(chain)
        summary.append((chain['name'], len(chain['items']), skipped))
    if not chains:
        errors.append('no chain files in tool/menus/chains/')
    ids = [c['id'] for c in chains]
    if len(set(ids)) != len(ids):
        errors.append('two chain files share an id')

    if errors:
        for error in errors:
            print(f'ERROR {error}', file=sys.stderr)
        print(f'{len(errors)} problem(s); nothing written.', file=sys.stderr)
        return 1

    for chain in chains:
        for item in chain['items']:
            for key in ('servingWeightG',) + REQUIRED + OPTIONAL:
                if key in item:
                    item[key] = tidy(item[key])

    old_version = 0
    old_chains = None
    if os.path.exists(OUT):
        with open(OUT, encoding='utf-8') as f:
            old = json.load(f)
        old_version = old.get('version', 0)
        old_chains = old.get('chains')

    for name, count, skipped in summary:
        print(f'{name}: {count} items, {skipped} skipped')
    total = sum(count for _, count, _ in summary)
    print(f'{len(chains)} chains, {total} items')

    if args.check:
        print('Check passed; nothing written.')
        return 0
    if args.version is not None:
        version = args.version
    elif old_chains == chains:
        print(f'No change; still version {old_version}.')
        return 0
    else:
        version = old_version + 1 if old_chains else max(old_version, 1)
    if version < 1:
        print('ERROR the version must be 1 or more', file=sys.stderr)
        return 1
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump({'version': version, 'chains': chains}, f,
                  ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    size = os.path.getsize(OUT) / 1024
    print(f'Wrote {os.path.relpath(OUT, ROOT)} version {version} '
          f'({size:.0f} KB)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
