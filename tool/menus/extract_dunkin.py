"""Dunkin': the Nutrition Guide PDF from dunkindonuts.com.

Save the PDF as tool/menus/sources/dunkin-guide.pdf, then run this file.
Dunkin' gives a serving as a size ("Large", "1 Donut"), never a weight, so
every item is counted in items only. The guide opens with limited time
products, which are left out; the permanent products follow.
Columns after the name: serving size, calories, total fat, saturated fat,
trans fat, cholesterol, sodium, total carb, dietary fiber, total sugars,
added sugars, protein, vitamin D, potassium, calcium, iron.
"""

import re
import sys

from menulib import Chain, clean, number, pdf_rows

SOURCE = ('https://assets.ctfassets.net/ubkcphxhphh0/7rROjtYxvOHQdLBTpamhuC/'
          'bbe6e300983a1fb1b5beb76ab4879556/DD_W8_nutrition_guide.pdf')
CHECKED = sys.argv[1] if len(sys.argv) > 1 else '2026-11-12'

# Sections left out: regional items and bags of coffee and tea.
LEFT_OUT = re.compile(r'Regional|Packaged', re.I)


def main():
    chain = Chain(
        'dunkin', "Dunkin'", SOURCE, CHECKED,
        "Extracted by tool/menus/extract_dunkin.py from the PDF. Dunkin' "
        'publishes no serving weights. Limited time products, regional '
        'sections and packaged coffee and tea are left out.',
    )
    permanent = False
    section = None
    last = None  # the item a wrapped name line belongs to
    pending = []
    for page in pdf_rows('dunkin-guide.pdf'):
        for row in page:
            texts = [clean(text) for _, text in row]
            if texts[:2] == ['Permanent', 'Products'] or \
                    texts[0] == 'Permanent Products':
                permanent = True
                continue
            # A section's name sits beside the column headings.
            if len(row) > 3 and 'Total' in texts[1:] and row[0][0] < 70:
                section = texts[0]
                if section.endswith('nutritional significance.'):
                    section = 'Hot Tea'
                last = None
                continue
            if len(row) == 1 and row[0][0] < 70 and last is not None:
                # The rest of a name that wrapped onto a second line.
                last['name'] = f"{last['name']} {texts[0]}"
                continue
            last = None
            if len(row) != 17 or row[0][0] > 70:
                continue
            values = [number(text) for text in texts[2:]]
            item = {'name': texts[0], 'section': section, 'values': values,
                    'permanent': permanent}
            pending.append(item)
            last = item

    for item in pending:
        name = re.sub(r'\s+-\s*|\s*-\s+', ', ', item['name']).strip(' ,')
        section = item['section']
        if not item['permanent']:
            chain.skip(name, 'a limited time product')
            continue
        if section is None or LEFT_OUT.search(section):
            chain.skip(name, f'in the "{section}" section')
            continue
        if None in item['values']:
            chain.skip(name, 'a figure in its row is not a single number')
            continue
        (calories, fat, _, _, _, sodium, carbs, fiber, sugar, _, protein,
         _, _, _, _) = item['values']
        chain.add(name, section, None, calories, protein, carbs, fat,
                  fiber=fiber, sugar=sugar, sodium=sodium)
    chain.write()


if __name__ == '__main__':
    main()
