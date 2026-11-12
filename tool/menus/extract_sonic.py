"""Sonic: the Nutritional Information brochure PDF from sonicdrivein.com.

Save the PDF as tool/menus/sources/sonic.pdf, then run this file.
Sonic publishes no serving weights, so every item is counted in items only.
Columns after the name: calories, total fat, saturated fat, trans fat,
cholesterol, sodium, total carbohydrates, dietary fiber, sugar, protein.
"""

import re
import sys

from menulib import Chain, clean, number, pdf_rows

SOURCE = ('https://assets.ctfassets.net/whnlxz6bna9d/6HIGXI30iOwh14ZFFiNGe4/'
          'a5ae98f9a0fcb3dc66e14ff059852c4a/'
          '61557-2_FEE_1126_NUTBRO_NOVEMBER_FA_cp_WCAG.pdf')
CHECKED = sys.argv[1] if len(sys.argv) > 1 else '2026-11-12'

# Source heading -> the category shown in the app. None leaves it out.
SECTIONS = {
    'LIMITED TIME ONLY': None,
    'BURGERS': 'Burgers',
    'MAKE IT YOURS': 'Make It Yours',
    'WACKY PACK! KIDS MEALS': 'Kids Meals',
    'TOASTER SANDWICHES': 'Sandwiches',
    'CHICKEN': 'Chicken',
    'SANDWICHES': 'Sandwiches',
    'HOT DOGS': 'Hot Dogs',
    'BREAKFAST': 'Breakfast',
    'COFFEE': 'Coffee',
    'SNACKS & SIDES': 'Snacks & Sides',
    'SONIC BLAST': 'Sonic Blast',
    'HAND-MIXED CLASSIC SHAKES': 'Shakes',
    'HAND-MIXED SIGNATURE SHAKES': 'Shakes',
    'SUNDAES': 'Sundaes & Floats',
    'FLOATS': 'Sundaes & Floats',
    'ALL-NATURAL LEMONADE': 'Lemonades & Limeades',
    'SOFT DRINKS': 'Soft Drinks',
    'REFRESHERS': 'Refreshers & Specialty Sips',
    'ICED TEAS': 'Iced Teas & Juices',
    'JUICES': 'Iced Teas & Juices',
    'SIGNATURE LIMEADES': 'Lemonades & Limeades',
    'SPECIALTY SIPS': 'Refreshers & Specialty Sips',
    'DRINK ADD-INS & TOPPINGS': 'Drink Add-ins & Toppings',
    'WATER': 'Soft Drinks',
    'CONDIMENTS & DIPPING SAUCES': 'Condiments & Dipping Sauces',
}

# The brochure prints names in capitals. These keep their spelling.
KEEP = {
    'RT': 'RT', 'BLT': 'BLT', 'BBQ': 'BBQ', 'JR': 'Jr.', 'PC.': 'pc.',
    'OZ.': 'oz.', 'OZ': 'oz', 'FL.': 'fl.', 'WITH': 'with', 'AND': 'and',
    'SUPERSONIC': 'SuperSONIC', 'SONIC': 'SONIC', "'R'": "'R'", 'IN': 'in',
    'M&M': 'M&M', "M&M'S": "M&M's", 'OREO': 'OREO', 'PB': 'PB', 'XL': 'XL',
}
SIZES = ('MINI', 'SMALL', 'MEDIUM', 'LARGE', 'RT 44', 'WACKY PACK!')


def word_case(word):
    if word.upper() in KEEP:
        return KEEP[word.upper()]
    # Capitalise each part of a hyphenated or slashed or bracketed word.
    return re.sub(r"[A-Za-zÀ-ÿ']+",
                  lambda m: KEEP.get(m[0].upper(),
                                     m[0][0].upper() + m[0][1:].lower()),
                  word)


def item_name(raw):
    name = clean(raw).lstrip(' ').strip()
    # The size goes after a comma: "Tots, Medium".
    for size in SIZES:
        if name.upper().endswith(' ' + size) and not name.endswith(','):
            head = name[:-len(size)].rstrip().rstrip(',')
            name = f'{head}, {size}'
            break
    return ' '.join(word_case(w) for w in name.split(' '))


def main():
    chain = Chain(
        'sonic', 'Sonic', SOURCE, CHECKED,
        'Extracted by tool/menus/extract_sonic.py from the PDF. Sonic '
        'publishes no serving weights. Limited time items are left out. '
        'Names are printed in capitals in the source and are re-cased here.',
    )
    section = None
    for page in pdf_rows('sonic.pdf'):
        for row in page:
            first = clean(row[0][1])
            if len(row) == 1 and first.upper() in SECTIONS:
                section = first.upper()
                continue
            if len(row) != 11 or section is None:
                continue
            values = [number(text) for _, text in row[1:]]
            name = item_name(row[0][1])
            if None in values:
                chain.skip(name, 'a figure in its row is not a single '
                                 'number')
                continue
            if SECTIONS[section] is None:
                chain.skip(name, f'in the "{section.title()}" section')
                continue
            calories, fat, _, _, _, sodium, carbs, fiber, sugar, protein = \
                values
            chain.add(name, SECTIONS[section], None, calories, protein,
                      carbs, fat, fiber=fiber, sugar=sugar, sodium=sodium)
    chain.write()


if __name__ == '__main__':
    main()
