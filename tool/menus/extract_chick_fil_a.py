"""Chick-fil-A: the nutrition table on chick-fil-a.com/nutrition-allergens.

Save the page (the HTML itself, not a rendered copy) as
tool/menus/sources/cfa.html, then run this file. The page carries its table
as JSON: each menu holds items, and an item with sizes or variants holds
them as sub-items, each with a serving size in grams.
"""

import json
import os
import re
import sys

from menulib import SOURCES, Chain, clean, number

SOURCE = 'https://www.chick-fil-a.com/nutrition-allergens'
CHECKED = sys.argv[1] if len(sys.argv) > 1 else '2026-11-12'

# The page's menu -> the category shown in the app. None leaves it out.
MENUS = {
    'Breakfast': 'Breakfast',
    'Entrées': 'Entrées',
    'Salads': 'Salads',
    'Sides': 'Sides',
    "Kid's Meals (nutrition per entrée only)": 'Kids Meals (entrée only)',
    'Treats': 'Treats',
    'Drinks': 'Drinks',
    'Coffee': 'Drinks',
    'Dipping Sauces': 'Sauces & Dressings',
    'Dressings': 'Sauces & Dressings',
    'Buns': 'Components',
    'Proteins': 'Components',
    'Salad Toppings': 'Components',
    'Sandwich Toppings': 'Components',
    'Soup Toppings': 'Components',
    'Trays': None,
    'Catering Entrées': None,
    'Catering Drinks': None,
}


def main():
    path = os.path.join(SOURCES, 'cfa.html')
    with open(path, encoding='utf-8', errors='replace') as f:
        page = f.read()
    blob = re.search(
        r'<script id="wp-script-module-data-@wordpress/interactivity" '
        r'type="application/json">(.*?)</script>', page, re.S)
    table = json.loads(blob.group(1))['state'][
        'nutrition-allergens-table-store']['tableData']['nutrition']

    chain = Chain(
        'chick-fil-a', 'Chick-fil-A', SOURCE, CHECKED,
        'Extracted by tool/menus/extract_chick_fil_a.py from the table '
        'embedded in the page. Trays, catering and gallon drinks are left '
        'out. An item with sizes or variants is listed as those, not as '
        'the summary row above them.',
    )
    seen = set()
    for menu in table:
        if menu['menu'] not in MENUS:
            raise SystemExit(f"Unknown menu: {menu['menu']}")
        category = MENUS[menu['menu']]
        for parent in menu['items']:
            for item in parent['sub_items'] or [parent]:
                name = clean(item['title']).replace('  ', ' ')
                if category is None:
                    continue
                if name.startswith('Gallon') or name in seen:
                    continue
                fields = {f['label']: f['value'] for f in item['fields']}
                grams = re.fullmatch(r'(\d+(\.\d+)?)g',
                                     str(fields.get('Serving Size')))
                if not grams:
                    chain.skip(name, 'no serving weight in the source')
                    continue
                seen.add(name)
                chain.add(
                    name, category, number(grams[1]),
                    fields['Calories'], fields['Protein (g)'],
                    fields['Carbohydrates (g)'], fields['Fat (g)'],
                    fiber=fields.get('Fiber (g)'),
                    sugar=fields.get('Sugar (g)'),
                    sodium=fields.get('Sodium (mg)'),
                )
    chain.write()


if __name__ == '__main__':
    main()
