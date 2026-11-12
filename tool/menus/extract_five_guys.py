"""Five Guys: the US Nutrition & Allergen Guide PDF from fiveguys.com.

Save the PDF as tool/menus/sources/fiveguys.pdf, then run this file.
Five Guys publishes the parts of an order (patty, bun, toppings, fries,
shake base and mix-ins), not built burgers, so those are what is listed.
Columns after the name: serving size (g), calories, calories from fat,
total fat, saturated fat, trans fat, cholesterol, sodium, carbs, fiber,
sugars, protein.
"""

import sys

from menulib import Chain, clean, number, pdf_rows

SOURCE = ('https://www.fiveguys.com/wp-content/uploads/2026/09/Five-Guys-US-'
          'Nutrition-Allergen-Guide-English-September-2026.pdf')
CHECKED = sys.argv[1] if len(sys.argv) > 1 else '2026-11-12'

# Heading (its first word or two) -> category and what is added to the name.
SECTIONS = [
    ('MEAT', 'Meat', ''),
    ('BUN', 'Buns', ''),
    ('FRIES', 'Fries', ' Fries'),
    ('TOPPINGS', 'Toppings', ''),
    ('MILKSHAKES', 'Milkshakes', ''),
    ('MINI MILKSHAKES', 'Mini Milkshakes', ''),
    ('MIX-INS', None, None),  # belongs to the shake section above it
    ('DRINKS', 'Drinks', ''),
    ('SAUCES', 'Sauces', ''),
    ('PEANUTS', 'Other', ''),
    ('OTHER ITEMS', 'Other', ''),
]


# Rows whose published calories do not match their published macros. The
# figures are entered as printed.
AS_PRINTED = {
    'Mini Patty': 'As printed: 163 kcal with 9 g fat and 9 g protein.',
    'Hamburger Patty': 'As printed: 302 kcal with 17 g fat and 16 g protein.',
}


def heading(text):
    for title, category, suffix in SECTIONS:
        if text == title or text.startswith(title + ' ') and text.isupper() \
                or text.startswith(title + ' ('):
            return title, category, suffix
    return None


def main():
    chain = Chain(
        'five-guys', 'Five Guys', SOURCE, CHECKED,
        'Extracted by tool/menus/extract_five_guys.py from the PDF. Five '
        'Guys publishes components, not built burgers. A figure printed as '
        '"<1" is entered as 0.5.',
    )
    category = suffix = None
    shake = None
    done = False
    for page in pdf_rows('fiveguys.pdf'):
        for row in page:
            first = clean(row[0][1])
            if first == 'INGREDIENT LISTING':
                done = True
            if done:
                break
            found = heading(first) if len(row) == 1 else None
            if found:
                title, new_category, new_suffix = found
                if title == 'MIX-INS':
                    suffix = (' (mini shake mix-in)'
                              if shake == 'MINI MILKSHAKES'
                              else ' (shake mix-in)')
                else:
                    category, suffix = new_category, new_suffix
                    if 'MILKSHAKES' in title:
                        shake = title
                continue
            if category is None or len(row) != 13:
                continue
            name = first + suffix
            values = [number(text) for _, text in row[1:]]
            if None in values:
                chain.skip(name, 'a figure in its row is not a single '
                                 'number')
                continue
            (weight, calories, _, fat, _, _, _, sodium, carbs, fiber, sugar,
             protein) = values
            chain.add(name, category, weight, calories, protein, carbs, fat,
                      fiber=fiber, sugar=sugar, sodium=sodium,
                      energy_note=AS_PRINTED.get(first))
        if done:
            break
    chain.write()


if __name__ == '__main__':
    main()
