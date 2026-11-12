#!/usr/bin/env python3
"""Builds assets/foods/generic_foods.tsv, the starter foods bundled with the
app, from USDA FoodData Central's SR Legacy release (public domain).

Download and unzip
  https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip
then run from the repository root:
  python3 tool/make_generic_foods.py <unzipped folder>

One line per food, tab separated, values per 100 g:
  name, kcal, protein g, carbs g, fat g, fiber g, sugar g, sodium mg, portions
Fiber, sugar and sodium are empty when USDA has no figure. Portions are
"name=grams" pairs joined by ";". Lines starting with # are comments. The
format is read by lib/core/bundled_foods.dart.

Left out: brand-name, restaurant, fast food and baby food items, which are
dated (2018) and not generic, and foods with no energy figure.
"""
import csv
import os
import re
import sys
from collections import defaultdict

OUT = "assets/foods/generic_foods.tsv"
# Baby Foods, Fast Foods, American Indian/Alaska Native Foods, Restaurant
# Foods, Branded, Quality Control.
SKIP_CATEGORIES = {"3", "21", "24", "25", "26", "27"}
# Brand names are written in capitals in SR Legacy ("QUAKER", "KFC").
CAPS_WORD = re.compile(r"\b[A-Z][A-Z'&.\-]{2,}\b")
NOT_BRANDS = {"UHT", "NFS", "USA", "BBQ"}
# Brands SR Legacy writes in mixed case.
MIXED_CASE_BRANDS = (
    "Pillsbury", "Kraft", "Campbell", "George Weston", "Archway", "Keebler",
    "Nabisco", "Kellogg", "General Mills", "Martha White", "Mission Foods",
    "Interstate Bakeries", "Continental Mills", "Heinz", "Hormel", "Oscar Mayer",
    "Louis Rich", "Butterball", "Carl Buddig", "Health Valley", "Uncle Ben",
    "Ralston", "Sun Country", "McKee", "Glutino", "Udi's", "Rudi's", "Van's",
    "Schar", "Andrea's", "Pepperidge Farm", "Toll House", "Betty Crocker",
    "Lean Pockets", "Hot Pockets", "Stouffer", "Lean Cuisine", "Chef Boyardee",
    "Banquet", "Marie Callender", "Healthy Choice", "Amy's", "Tyson",
    "Morningstar", "Gardenburger", "Worthington", "Loma Linda", "Clif",
    "Power Bar", "Balance Bar", "Nutri-Grain", "Slim-Fast", "Ensure",
)
ENERGY, PROTEIN, FAT, CARBS, FIBER, SUGAR, SODIUM = (
    "1008", "1003", "1004", "1005", "1079", "2000", "1093",
)
MAX_PORTIONS = 3
MAX_PORTION_NAME = 40


def num(value, places):
    text = f"{round(float(value), places):.{places}f}"
    return text.rstrip("0").rstrip(".") if "." in text else text


def is_brand(description):
    if description.startswith(MIXED_CASE_BRANDS):
        return True
    return any(w not in NOT_BRANDS for w in CAPS_WORD.findall(description))


def portion_name(row):
    name = (row["modifier"] or row["portion_description"]).strip()
    name = re.sub(r"\s+", " ", name).replace(";", ",").replace("=", " ")
    return name[:MAX_PORTION_NAME].strip()


def main(folder):
    def rows(name):
        with open(os.path.join(folder, name), newline="", encoding="utf-8") as f:
            yield from csv.DictReader(f)

    foods = {
        r["fdc_id"]: r["description"].strip()
        for r in rows("food.csv")
        if r["food_category_id"] not in SKIP_CATEGORIES
        and not is_brand(r["description"])
        and "\t" not in r["description"]
    }
    wanted = {ENERGY, PROTEIN, FAT, CARBS, FIBER, SUGAR, SODIUM}
    nutrients = defaultdict(dict)
    for r in rows("food_nutrient.csv"):
        if r["fdc_id"] in foods and r["nutrient_id"] in wanted:
            nutrients[r["fdc_id"]][r["nutrient_id"]] = r["amount"]
    portions = defaultdict(list)
    for r in sorted(rows("food_portion.csv"), key=lambda r: int(r["seq_num"] or 0)):
        fid = r["fdc_id"]
        if fid not in foods or len(portions[fid]) >= MAX_PORTIONS:
            continue
        try:
            grams = float(r["gram_weight"]) / (float(r["amount"]) or 1)
        except ValueError:
            continue
        name = portion_name(r)
        if not name or grams <= 0 or any(p[0] == name for p in portions[fid]):
            continue
        portions[fid].append((name, num(grams, 1)))

    lines = []
    seen = set()
    for fid, name in foods.items():
        n = nutrients[fid]
        if ENERGY not in n or name.lower() in seen:
            continue
        seen.add(name.lower())
        lines.append("\t".join([
            name,
            num(n[ENERGY], 0),
            num(n.get(PROTEIN, 0), 1),
            num(n.get(CARBS, 0), 1),
            num(n.get(FAT, 0), 1),
            num(n[FIBER], 1) if FIBER in n else "",
            num(n[SUGAR], 1) if SUGAR in n else "",
            num(n[SODIUM], 0) if SODIUM in n else "",
            ";".join(f"{p}={g}" for p, g in portions[fid]),
        ]))
    lines.sort(key=str.lower)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("# USDA FoodData Central, SR Legacy (April 2018). Public domain.\n")
        f.write("# Made by tool/make_generic_foods.py. Values per 100 g.\n")
        f.write("\n".join(lines) + "\n")
    print(f"wrote {len(lines)} foods to {OUT}")


if __name__ == "__main__":
    main(sys.argv[1])
