"""Arby's: the U.S. Nutrition & Allergen Information PDF from arbys.com.

Save the PDF as tool/menus/sources/arbys.pdf, then run this file.
Columns, left to right after the name: serving weight (g), calories,
calories from fat, total fat, saturated fat, trans fat, cholesterol, sodium,
total carbohydrate, dietary fiber, sugars, protein.
"""

import re
import sys

from menulib import FL_OZ_ML, Chain, clean, number, pdf_rows

SOURCE = ('https://assets.ctfassets.net/30q5w5l98nbx/6CplhZeKpu7X9ts2pSE3Lg/'
          '624b24407875e1dbdf6f07f0da28897e/'
          'Arbys_Nutritional_and_Allergen_NOV_2026.pdf')
CHECKED = sys.argv[1] if len(sys.argv) > 1 else '2026-11-12'

# Source heading -> the category shown in the app. None leaves the section
# out.
SECTIONS = {
    'LIMITED TIME OFFERS': None,
    'SLOW ROASTED BEEF': 'Roast Beef',
    "ARBY'S CHEESESTEAKS": 'Cheesesteaks',
    'CRISPY CHICKEN': 'Chicken',
    'CRAFTED SANDWICHES': 'Sandwiches',
    'SIGNATURE SIDES': 'Sides',
    'SHAKES': 'Shakes & Desserts',
    'VALUE MENU': 'Value Menu',
    'KIDS MENU': 'Kids Menu',
    'SMALL DRINKS': 'Drinks',
    'MEDIUM DRINKS': 'Drinks',
    'LARGE DRINKS': 'Drinks',
    'XL DRINKS': 'Drinks',
    'MISCELLANEOUS DRINKS': 'Drinks',
    'BREAKFAST': 'Breakfast',
    'TOPPINGS': 'Sauces & Toppings',
    'OPTIONAL/REGIONAL': None,
}
DRINK_SIZE = {
    'SMALL DRINKS': 'Small',
    'MEDIUM DRINKS': 'Medium',
    'LARGE DRINKS': 'Large',
    'XL DRINKS': 'XL',
}
SIZE_WORDS = {'Small', 'Med', 'Large', 'XL'}

# Rows the document prints with figures that cannot be right. They are left
# out, not corrected.
MISPRINTS = {
    'Mello Yello, Medium': 'printed with 0 g carbohydrate and 54 g sugars',
}


def main():
    chain = Chain(
        'arbys', "Arby's", SOURCE, CHECKED,
        'Extracted by tool/menus/extract_arbys.py from the PDF. Limited time '
        'offers and the optional/regional section are left out. Fountain '
        'drinks are published by size with no weight.',
    )
    section = None
    for page in pdf_rows('arbys.pdf'):
        for row in page:
            first = clean(row[0][1])
            if len(row) == 1 and first.upper() in SECTIONS:
                section = first.upper()
                continue
            values = [number(text) for _, text in row[-11:]]
            if len(row) < 13 or None in values:
                continue
            # The allergen statement sometimes runs on from the name.
            name = re.split(r'\s+Contains:|\s+May contain:', first)[0]
            # Footnote marks: a leading bullet, a trailing portion mark.
            name = re.sub(r'^\W+', '', name)
            name = re.sub(r'\s+u$', '', name).strip()
            name = re.sub(r'\s+-\s*|\s*-\s+', ', ', name)
            if section is None or SECTIONS[section] is None:
                if section is not None:
                    chain.skip(name, f'in the "{section.title()}" section')
                continue
            if section in DRINK_SIZE and DRINK_SIZE[section] not in name:
                name = f'{name}, {DRINK_SIZE[section]}'
            if name in MISPRINTS:
                chain.skip(name, MISPRINTS[name])
                continue
            serving = row[-12][1].strip()
            weight = number(serving)
            ounces = re.fullmatch(r'(\d+(\.\d+)?)\s*oz', serving)
            if ounces:
                # A drink published by volume: 1 ml counts as 1 g.
                weight = round(float(ounces[1]) * FL_OZ_ML)
            if not weight and serving in SIZE_WORDS:
                # A fountain drink sized Small to XL: no weight is published.
                weight = None
            elif not weight:
                chain.skip(name, f'the serving is given as "{serving}"')
                continue
            (calories, _, fat, _, _, _, sodium, carbs, fiber, sugar,
             protein) = values
            chain.add(name, SECTIONS[section], weight, calories, protein,
                      carbs, fat, fiber=fiber, sugar=sugar, sodium=sodium)
    chain.write()


if __name__ == '__main__':
    main()
