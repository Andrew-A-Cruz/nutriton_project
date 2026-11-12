"""Shared helpers for the per-chain extractors in this folder.

Each extractor reads a chain's own published nutrition document from
`tool/menus/sources/` (git-ignored) and writes `tool/menus/chains/<id>.json`.
Values are copied from the document; nothing is typed from memory.

Reading a PDF needs PyMuPDF (`pip install pymupdf`).
"""

import json
import os
import re
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCES = os.path.join(HERE, 'sources')
CHAINS = os.path.join(HERE, 'chains')

FL_OZ_ML = 29.57


def slugify(text):
    """A lower-case id of a-z, 0-9 and single hyphens."""
    text = unicodedata.normalize('NFKD', text)
    text = text.encode('ascii', 'ignore').decode('ascii').lower()
    text = text.replace('&', ' and ').replace('%', ' percent ')
    text = re.sub(r"['’]", '', text)
    return re.sub(r'[^a-z0-9]+', '-', text).strip('-')


def clean(text):
    """One line of plain text: marks removed, quotes straightened."""
    text = re.sub(r'[®™℠∆†‡*°]', '', text)
    text = text.replace('’', "'").replace('‘', "'")
    text = text.replace('“', '"').replace('”', '"')
    text = text.replace('–', '-').replace('—', '-')
    return re.sub(r'\s+', ' ', text).strip()


def pdf_rows(name, gap=5.0, ytol=2.5):
    """The PDF as pages of rows of cells. A row is the words on one line; a
    cell is a run of words with no horizontal gap wider than [gap] points.
    Each cell is (x, text), x being its left edge."""
    import fitz  # PyMuPDF

    pages = []
    for page in fitz.open(os.path.join(SOURCES, name)):
        words = page.get_text('words')
        words.sort(key=lambda w: ((w[1] + w[3]) / 2, w[0]))
        lines = []
        for w in words:
            yc = (w[1] + w[3]) / 2
            if lines and abs(lines[-1][0] - yc) <= ytol:
                lines[-1][1].append(w)
            else:
                lines.append((yc, [w]))
        rows = []
        for _, line in lines:
            line.sort(key=lambda w: w[0])
            cells = [[line[0]]]
            for w in line[1:]:
                if w[0] - cells[-1][-1][2] > gap:
                    cells.append([w])
                else:
                    cells[-1].append(w)
            rows.append([(c[0][0], ' '.join(w[4] for w in c)) for c in cells])
        pages.append(rows)
    return pages


def number(text):
    """A published figure as a number. "<1" and "< 1" read as 0.5, the
    middle of what they can mean. Returns None for anything else."""
    text = text.strip().replace(',', '')
    if re.fullmatch(r'<\s*1', text):
        return 0.5
    if re.fullmatch(r'\d+(\.\d+)?', text):
        value = float(text)
        return int(value) if value == int(value) else value
    return None


class Chain:
    """Collects a chain's items and writes its source file."""

    def __init__(self, chain_id, name, source, checked_at, notes):
        self.data = {
            'id': chain_id,
            'name': name,
            'source': source,
            'checkedAt': checked_at,
            'retrievedAt': checked_at,
            'notes': notes,
            'items': [],
            'skipped': [],
        }
        self._ids = set()

    def add(self, name, category, weight_g, calories, protein, carbs, fat,
            fiber=None, sugar=None, sodium=None, item_id=None,
            energy_note=None):
        item_id = item_id or slugify(name)
        if item_id in self._ids:
            self.skip(name, 'listed more than once in the source; the first '
                            'is kept')
            return
        self._ids.add(item_id)
        item = {
            'id': item_id,
            'name': name,
            'category': category,
            'calories': calories,
            'protein': protein,
            'carbs': carbs,
            'fat': fat,
        }
        # No weight means the chain publishes none: the item is counted in
        # items only.
        for key, value in (('servingWeightG', weight_g), ('fiber', fiber),
                           ('sugar', sugar), ('sodium', sodium)):
            if value is not None:
                item[key] = value
        if energy_note:
            # The published figures do not add up; say why they stand.
            item['energyCheck'] = False
            item['note'] = energy_note
        self.data['items'].append(item)

    def skip(self, name, reason):
        self.data['skipped'].append({'name': name, 'reason': reason})

    def write(self):
        os.makedirs(CHAINS, exist_ok=True)
        path = os.path.join(CHAINS, self.data['id'] + '.json')
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(self.data, f, indent=1, ensure_ascii=False)
            f.write('\n')
        print(f"{self.data['name']}: {len(self.data['items'])} items, "
              f"{len(self.data['skipped'])} skipped -> {path}")
