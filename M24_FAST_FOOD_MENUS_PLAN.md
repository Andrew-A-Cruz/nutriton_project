# M24 — Fast Food Menus: Implementation Plan

Written on 2026-11-12 for the agent who builds this. It assumes you have not seen the conversations that led here. Read [`PRODUCT.md`](./PRODUCT.md) (principles, technical decisions, conventions) and the M24 entry in [`ROADMAP.md`](./ROADMAP.md) first; this file is the detail behind that entry and wins where the two differ.

**Goal:** a user can log a menu item from a common US chain in a few taps, offline, with no typing except a search.

**Done when:** a medium fries from a listed chain can be logged in five taps or fewer (`+` → Restaurants → chain → item → Log), and every item in the file can be traced to a source the chain published.

**Size:** L (1–2 weeks). About a third is code; the rest is gathering and checking data.

---

## 0. Before you start

### 0.1 One decision is still open (D3)

D3 in the roadmap asks where the values come from and whether they may ship in the app. Its **proposed** answer, which this plan assumes, is:

- Values are hand-entered from each chain's own published nutrition information, for a short list of US chains.
- USDA FoodData Central may be used where it covers an item.
- Each item's source and the date it was checked are stored.
- Open Food Facts (ODbL, share-alike) and paid nutrition APIs are **not** used.

The user asked for this plan but has not explicitly accepted D3. **Ask the user to confirm D3 before you gather any data (Phase B).** Phase A (the code, with a tiny hand-made fixture) does not depend on the answer and can start at once.

### 0.2 Rules that are not negotiable

1. **Never write a nutrition value from memory.** Every number in the bundled file must come from a document you fetched or the user supplied in this work, and that document's URL and the date you read it go in the chain's source file. If you cannot fetch a chain's published values, leave the chain out and say so. A missing chain is fine; an invented number is a defect that misleads someone about what they ate.
2. **Names only.** Chain and item names are used to identify the food (nominative use). No logos, no brand colours, no chain artwork, no slogans.
3. **Free.** This feature is free (Principles 3 and 5 in `PRODUCT.md`). It never touches `ProGate`.
4. **Offline and private.** No network call is added. The only outward link is a "report a wrong value" email link.
5. **Edits stay the user's.** A menu food the user has edited is never overwritten by a newer release.
6. **Commit and push only when the user asks.** Work on a branch (`fast-food-menus`); the repo merges feature branches with `git merge --no-ff -m "Merge fast-food-menus"`.

### 0.3 What already exists that you build on

The starter generic foods (shipped November 2026) built most of the plumbing. Read these before writing anything:

| What | Where | Why it matters |
|---|---|---|
| Bundled file reader and in-memory search | `lib/core/bundled_foods.dart` | The pattern to copy: pure Dart, skips bad rows, ranks matches. Reuse `searchWords` from `lib/core/search.dart` |
| Copy a bundled food into the catalog | `CatalogRepository.adoptBundledFood` in `lib/data/repositories/catalog_repository.dart` | Matches by name. M24 needs the same idea keyed by `menu_item_id` |
| Lazy, once-per-session asset load | `genericFoodsSourceProvider`, `genericFoodsProvider` in `lib/providers/catalog_providers.dart` | Copy this shape. Tests override the *source* provider with a short string |
| Bundled results under catalog search | `FoodList.onBundledTap` in `lib/views/catalog/food_list.dart`, `ArchivableList.footer` in `lib/views/common/archivable_list.dart`, `CatalogBrowser.onBundledFoodTap` | Where "search across all chains" plugs in |
| Tap → adopt → servings screen | `_AddFoodViewState._logBundledFood` in `lib/views/add_food/add_food_view.dart` | The flow menu items follow |
| Things watched for the whole session | `_RootGate.build` in `lib/app.dart` | Where the "refresh unedited menu foods" plan is watched |
| Tests to model yours on | `test/core/bundled_foods_test.dart`, `test/data/repositories/bundled_food_test.dart`, `test/views/starter_foods_test.dart` | Same three layers |

Architecture rules from `PRODUCT.md` that apply: views → Riverpod providers (no codegen) → repositories → drift DAOs. DAOs hold SQL only. Repositories own rules and transactions. `lib/core/` is pure Dart with no Flutter or drift imports.

---

## 1. Design

### 1.1 The bundled file

`assets/menus/menus.json`, declared under `flutter: assets:` in `pubspec.yaml`. JSON, not TSV, because the data is nested (chains → items) and carries per-chain provenance.

```json
{
  "version": 1,
  "chains": [
    {
      "id": "example-burger",
      "name": "Example Burger",
      "source": "https://example.com/nutrition.pdf",
      "checkedAt": "2026-11-20",
      "items": [
        {
          "id": "fries-medium",
          "name": "French Fries, Medium",
          "category": "Sides",
          "servingWeightG": 114,
          "calories": 320,
          "protein": 5,
          "carbs": 43,
          "fat": 15,
          "fiber": 4,
          "sugar": 0,
          "sodium": 260
        }
      ]
    }
  ]
}
```

Rules:

- `version` is a whole number, raised by one every time the file's values change. It drives the refresh in 1.5.
- A chain `id` and an item `id` are lower-case slugs (`a-z`, `0-9`, `-`). They are **permanent**: once shipped, an id is never renamed or reused for a different food, because catalog foods point at them. The full id stored on a catalog food is `"<chain id>/<item id>"`, e.g. `example-burger/fries-medium`.
- Values are **per item as served**. Each size is its own item ("French Fries, Small", "French Fries, Medium").
- `calories`, `protein`, `carbs`, `fat` are required. `fiber`, `sugar` (grams) and `sodium` (milligrams) are optional; leave the key out when the chain does not publish it. Absent means "not recorded", which the app treats differently from 0 (see "Null nutrient" in `PRODUCT.md`).
- `servingWeightG` is required and `> 0`, because `food_items.serving_weight_g` must be positive and logging by weight divides by it. For a drink published by volume, convert at 1 ml = 1 g (1 US fl oz = 29.57 ml). An item whose source gives neither a weight nor a volume is left out; record it in the chain's source file under `skipped` with the reason.
- `category` is free text shown as a section header ("Burgers", "Sides", "Drinks"). Keep each chain to a handful of categories, in the order they should appear (the parser keeps first-seen order).
- `checkedAt` is `yyyy-MM-dd`, the day the source was read.
- Item names are 2–100 characters (the `food_items.name` limit).

### 1.2 Schema v14

Two new nullable columns on `food_items`:

| Column | Type | Notes |
|---|---|---|
| `menu_item_id` | TEXT, nullable, indexed (`food_items_menu_item_id`) | `"<chain id>/<item id>"` of the bundled item this food was copied from. Null for every other food |
| `menu_version` | INT, nullable | The `menus.json` `version` this food's values match. Null means "not a menu food" or "the user edited it": never refreshed |

The roadmap's entry names only `menu_item_id`. The second column is this plan's addition: without it there is no way to tell an edited menu food from an untouched one after the bundled file changes, so "edits stay the user's" could not be honoured. Update the roadmap entry and `DATA_MODEL.md` to say v14 adds both.

Steps (the convention is in `PRODUCT.md` > Conventions):

1. Add both columns to `lib/data/database/tables/food_items.dart` and a second `@TableIndex(name: 'food_items_menu_item_id', columns: {#menuItemId})`.
2. In `lib/data/database/app_database.dart`: `schemaVersion => 14`, and a `from13To14` step that calls `m.addColumn` for each column and `m.create(schema.foodItemsMenuItemId)`. Copy the shape of `from5To6` (barcode: column plus index).
3. `dart run drift_dev make-migrations` then `dart run build_runner build --delete-conflicting-outputs`. Both write generated files that are committed; CI fails if they are stale.
4. In `test/drift/app_database/migration_test.dart`: replace `reopens as v13`, `starts at v13` and `expect(await userVersion(db), 13)` with 14 throughout, and add a `group('v13 to v14', ...)` modelled on `'v12 to v13'`: start from `verifier.schemaAt(13)` with one food inserted by raw SQL, open `AppDatabase`, check the food survived with both new columns null, that a `menu_item_id` can be stored and found, and `db.validateDatabaseSchema()`.
5. Check the raw-SQL helpers near the top of that test file (`foodsOf`) still map old rows: they default `favorite`; nullable columns need nothing.

### 1.3 Pure core: `lib/core/menus.dart`

No Flutter or drift imports. Suggested shape:

```dart
class MenuItem {
  final String id;        // "<chain id>/<item id>"
  final String chainId;
  final String chainName;
  final String name;
  final String category;
  final Macros perItem;   // from core/nutrition_math.dart; fiber/sugar/sodium nullable
  final double servingWeightG;
}

class MenuChain {
  final String id;
  final String name;
  final String source;
  final String checkedAt;      // yyyy-MM-dd
  final List<MenuItem> items;  // file order
  List<String> get categories; // first-seen order
}

class MenuCatalog {
  final int version;
  final List<MenuChain> chains; // sorted by name, ignoring case
  MenuItem? itemById(String id);
  static const empty = ...;
}

/// Throws FormatException only when the file as a whole is unusable
/// (not JSON, no positive whole-number version, chains not a list).
MenuCatalog parseMenus(String source);

/// Every word of [query] must appear in the item name or the chain name
/// (searchWords from core/search.dart). Optional [chainId] limits it to one
/// chain. Empty query returns nothing. Ranked like searchBundledFoods.
List<MenuItem> searchMenuItems(MenuCatalog menus, String query,
    {String? chainId, int limit = 25});

/// "November 2026" from "2026-11-20", for the attribution line.
String checkedMonthLabel(String checkedAt);
```

Parser rules, each with a test:

- A chain is skipped when its `id` or `name` is missing or malformed, or when none of its items survive.
- An item is skipped when: `id` or `name` is missing or malformed; the name is outside 2–100 characters; any of calories, protein, carbs, fat is missing, not a finite number or negative; calories is absent ("no calories" in the roadmap means the key is missing, a genuine 0 kcal drink is allowed); an optional nutrient is present but not a finite non-negative number; `servingWeightG` is missing or `<= 0`; `category` is missing or empty.
- A duplicate chain id, or a duplicate item id within a chain, keeps the first and skips the rest.
- Unknown keys are ignored, so a later file format can add fields.
- Numbers may be JSON ints or doubles.

### 1.4 Data layer

**DAO** (`lib/data/database/daos/food_dao.dart`), SQL only:

- `Future<FoodItem?> findByMenuItemId(String menuItemId)`: any food with that id, archived or not; if several (should not happen), non-archived first.
- `Future<List<FoodItem>> findMenuFoodsBelowVersion(int version)`: `menu_item_id IS NOT NULL AND menu_version IS NOT NULL AND menu_version < ?`.

**Repository** (`CatalogRepository`):

- `Future<FoodItem> adoptMenuItem(MenuItem item, {required int version})`, in one transaction:
  - If a food with that `menu_item_id` exists: un-archive it if archived, and return it **as it is** (the user's edits and their copy win). Never create a second.
  - Otherwise create a food with `name: item.name`, `brand: item.chainName`, `perServing: item.perItem`, `servingWeightG: item.servingWeightG`, `menuItemId: item.id`, `menuVersion: version`. Setting the brand makes the chain show beside the name in lists and makes catalog search match the chain (search already covers brand). `createFood` needs two new optional parameters for the menu columns; keep them out of the public form path.
- `Future<int> refreshMenuFoods(MenuCatalog menus)`, in one transaction: for each food from `findMenuFoodsBelowVersion(menus.version)`, look up `menus.itemById`. If found, write the item's name, seven nutrients and serving weight and set `menu_version` to `menus.version`; leave brand, favorite, archived, barcode and display unit alone. If the item is gone from the file, leave the food untouched. Return how many were updated. Log entries are snapshots and are never touched.
- `updateFood` (called by the food form's Save): when the food has a `menu_item_id`, also write `menuVersion: Value(null)`. That is what marks it "edited". Saving the form without changing anything still counts as an edit; that is acceptable and simpler than diffing. `setFoodFavorite` and `setFoodArchived` must **not** clear it.
- Duplicating a food (`FoodFormView(template: ...)`) goes through `createFood`, so the copy has no menu columns. Leave that as is: a variant is the user's own food.

**Providers** (new `lib/providers/menu_providers.dart`), copying the generic foods pair:

- `menusSourceProvider`: `Provider<Future<String> Function()>` reading `rootBundle.loadString('assets/menus/menus.json')`.
- `menusProvider`: `FutureProvider<MenuCatalog>` with `ref.keepAlive()`, parsing the source; on a `FormatException` record it in the error log (`errorLogProvider`) and return `MenuCatalog.empty`, so a bad file hides the feature instead of breaking Add Food.
- `menuRefreshPlanProvider`: `Provider<void>` watched from `_RootGate.build` in `lib/app.dart`, beside the other plan providers. When `menusProvider` has a value, call `refreshMenuFoods` once, `unawaited`, with failures sent to the error log. Model it on `autoBackupPlanProvider` in `lib/providers/backup_providers.dart`. It runs every launch; the query returns nothing unless the file's version went up, so it is cheap.

There is no separate `MenuRepository` class: the roadmap names one, but the parser is pure and the catalog writes belong in `CatalogRepository`. Note this in the roadmap entry when you close it.

### 1.5 Backup

`BackupCodec` (`lib/data/backup/backup_codec.dart`) serialises `FoodItem` rows with drift's generated JSON. A missing nullable column reads as null, so old backups import unchanged and the backup format version stays 1. Add `test/data/backup/backup_menu_test.dart`, modelled on `backup_barcode_test.dart` or `backup_water_test.dart`:

- A round trip keeps `menuItemId` and `menuVersion`.
- A file without those keys imports with both null.
- `test/data/backup/fixtures/backup_v1.json` still imports.

After a restore, the next launch's refresh brings any unedited menu foods from an older backup up to the current file. Add a test for that in the repository tests.

### 1.6 Screens

All Cupertino, like the rest of the app. New files under `lib/views/restaurants/`.

**Entry point.** In Add Food's Catalog mode (`lib/views/add_food/add_food_view.dart` → `CatalogBrowser`), a row labelled "Restaurants" with a chevron, key `restaurants-entry`, shown in the Foods section when the search field is empty and the menus have at least one chain. Add it to `CatalogBrowser` as an optional `onRestaurants` callback, placed after the favorites and recent strips and before the list, the same way `onSearchOnline` adds its row. The Catalog tab does not pass it.

**Search across all chains.** While searching foods in Add Food, matching menu items appear in their own section under the starter foods, headed "RESTAURANTS", at most 15, each row showing the item name with "<chain> · <kcal> kcal" beneath, keys `menu-food-0`…. Extend `FoodList` with an `onMenuTap` parameter beside `onBundledTap`, and leave out items whose `menu_item_id` is already on a catalog food in the results (the catalog's own row covers it; compare ids, not names). Both sections go into `ArchivableList.footer`.

**`RestaurantsView`** (pushed from the entry row): a search field (`restaurants-search`) and the chains by name (`chain-<id>`). Typing searches items across every chain and replaces the chain list with results. Empty state when the file has no chains.

**`ChainMenuView`** (pushed from a chain): the chain name as the title, a search field (`chain-search`) that filters within the chain, and items grouped under category headers, each row "name" with "<kcal> kcal · <weight>" beneath (use `formatWeight` from `lib/views/common/form_widgets.dart` with the user's display unit), keys `menu-item-<item id>`. At the bottom, the attribution:

> Values from <chain>, checked <Month Year>. Recipes change.

and a "Report a wrong value" link (`report-menu-value`) that opens `mailto:logbite.app@gmail.com` with the chain name in the subject, through `url_launcher` (already a dependency; see `_LinkButton` in `lib/views/paywall/paywall_view.dart`). To keep it testable, read the launcher from a small provider that tests override, rather than calling `launchUrl` directly.

**Tapping an item** anywhere: `adoptMenuItem`, then the existing servings screen, exactly as `_logBundledFood` does for starter foods. Pass the tap handler down from `AddFoodView` so the restaurant screens do not know about logging. Errors go through `reportError` and `showErrorDialog` (`lib/views/common/error_feedback.dart`).

The roadmap says "the first log saves the item as a catalog food". This plan copies it on **tap**, as starter foods do, so the servings screen can stay a plain catalog-food screen with its portions and "last servings" behaviour. The cost is that a tapped but un-logged item stays in the catalog. Record that as a known limit in What's Built.

**Wide layout.** On an iPad, Add Food is a pane with its own `Navigator` (`_AddFoodPane` in `lib/views/home/home_view.dart`). Pushing the restaurant screens with `Navigator.of(context)` keeps them inside the pane; do not use `rootNavigator: true`. `LogFoodView` pops to the first route after logging, which is the pane's Add Food root.

**Text size and dark mode.** Add the two new screens to `test/views/large_text_dark_mode_test.dart` (2x text, dark, phone size); a `RenderFlex` overflow fails the test.

---

## 2. Phase A — Code, against a fixture

Do this first. Use a hand-written `menus.json` with one obviously fake chain (as in 1.1) so no real data is needed, and keep that fixture as the tests' source string.

Suggested order, each step ending with `flutter analyze && flutter test`:

1. `lib/core/menus.dart` and `test/core/menus_test.dart` (parser rules in 1.3, search, the month label).
2. Schema v14, migration and migration test (1.2).
3. DAO and repository methods and `test/data/repositories/menu_food_test.dart`:
   - first adopt creates one food with the chain as brand, the item's values and both menu columns;
   - second adopt returns the same food and creates nothing;
   - adopting an archived menu food un-archives and reuses it;
   - an edited food (`updateFood`) has a null `menu_version` and keeps its `menu_item_id`;
   - `refreshMenuFoods` with a higher version updates an unedited food and its `menu_version`, leaves an edited food alone, leaves a food whose item left the file alone, does not touch non-menu foods, and does not change any log entry;
   - favorite and archive do not clear `menu_version`.
4. Backup test (1.5).
5. Providers and the refresh plan; a provider test that a higher-version source updates an unedited food at launch (see `test/providers/today_providers_test.dart` for a provider-level test, or do it as a widget test with `testApp`).
6. Screens and `test/views/restaurants_test.dart`:
   - the Restaurants row shows in Add Food with an empty search, not in the Catalog tab, and not when the file has no chains;
   - the full flow: `+` → Restaurants → chain → item → Log writes one entry with the item's name and calories and one catalog food; count the taps in the test's comments against the "five taps" bar;
   - search within a chain; search across chains from `RestaurantsView`; the RESTAURANTS section in Add Food's catalog search, and that an item already in the catalog shows once;
   - the attribution line and that the report link calls the launcher with a `mailto:` URL;
   - logging the same item twice makes two entries and one catalog food.
7. Wide layout: one test in `test/views/wide_layout_test.dart` that the restaurant screens open inside the pane (the weigh-in row on the left is still on screen).
8. Large text and dark mode (1.6).

### Test gotchas in this repo

- Use the helpers in `test/support/test_app.dart`: `testApp`, `mockPreferences`, `settle` (lets drift streams deliver) and `unmount` at the end of every `testWidgets`.
- **A widget test that fails before `unmount` can hang the whole `flutter test` run** rather than exit. Run with a time limit while developing, for example `perl -e 'alarm 420; exec @ARGV' flutter test`, and look at the first failure, not the hang.
- Flutter's test window is 800 x 600, which would count as a wide screen. `test/flutter_test_config.dart` turns the two-pane layout off for all tests; a test that wants it sets `wideLayoutMinWidth = defaultWideLayoutMinWidth` in `setUp` and restores `double.infinity` in `tearDown` (see `wide_layout_test.dart`).
- Lists build lazily. If a finder cannot see a row that should exist, give the test a taller window (`tester.view.physicalSize`, `devicePixelRatio = 1`, `addTearDown(tester.view.reset)`) or scroll to it.
- Override `menusSourceProvider` with an inline string in view tests. Do not rely on `rootBundle` inside `testWidgets`.
- Lints in `analysis_options.yaml` are strict (`unawaited_futures`, `prefer_const_constructors`, `prefer_final_locals`, `avoid_dynamic_calls`). `flutter analyze` must report no issues.
- Run `dart format lib test` before finishing.

---

## 3. Phase B — Data

Needs D3 confirmed (0.1). This is most of the work.

### 3.1 Source files and the build script

Keep one hand-edited file per chain as the source of truth, and generate the bundled file from them, as `tool/make_generic_foods.py` does for starter foods:

```
tool/menus/chains/<chain-id>.json   one per chain: the chain object from 1.1, plus
                                    "retrievedAt", "notes" and "skipped": [{"name", "reason"}]
tool/make_menus.py                  validates every chain file, writes assets/menus/menus.json
```

`tool/make_menus.py` must fail loudly (non-zero exit, naming the chain and item) on:

- any parser rule in 1.3 (the bundled file should never contain a row the app would skip);
- a duplicate id, or an id that does not match `^[a-z0-9]+(-[a-z0-9]+)*$`;
- a missing `source` URL or `checkedAt`;
- **an energy mismatch:** `|calories − (4·protein + 4·carbs + 9·fat)|` greater than both 20% of calories and 40 kcal. This catches transposed columns and typos. Some real items legitimately fail (alcohol, sugar alcohols, very high fiber); allow a per-item `"energyCheck": false` with a `"note"` saying why, and keep such exceptions rare;
- sugar greater than carbs, or fiber greater than carbs.

It takes the version as an argument or reads and increments the existing file's, and prints a summary (chains, items, skipped). Add `test/core/menus_test.dart` cases that read the real `assets/menus/menus.json`: every row parses (the count in equals the count out), ids are unique, and a spot check of two or three items against the values in their chain file.

Raising `version` is required whenever any value changes; forgetting it means unedited foods on users' phones never refresh.

### 3.2 Which chains

The roadmap says the 15–20 largest US chains. A reasonable candidate list, by US sales: McDonald's, Starbucks, Chick-fil-A, Taco Bell, Wendy's, Dunkin', Burger King, Subway, Chipotle, Domino's, Panera Bread, Pizza Hut, Panda Express, Popeyes, KFC, Sonic, Dairy Queen, Arby's, Jack in the Box, Little Caesars. Confirm the list with the user; it is theirs to choose.

**Ship in two steps.** First three or four chains with fixed menus (burger and chicken chains are the simplest), end to end, so the user can try the feature. Then the rest. Build-your-own chains (Subway, Chipotle, pizza by the slice and topping) do not fit "one item, one row": list their published components and standard builds only, or leave them for later and say so.

Per chain, cover the standing menu: each main item, each size of sides and drinks that carry calories, breakfast, desserts. Skip limited-time items, regional items and customisations. Roughly 40–120 items per chain.

### 3.3 How to gather a chain

1. Find the chain's own published US nutrition document (usually a PDF or a nutrition page on its site). Fetch it in this session. Record the URL as `source` and today's date as `checkedAt` and `retrievedAt`.
2. If the site blocks automated fetching or renders only through an app, **stop for that chain** and ask the user to download the PDF into `tool/menus/sources/` (git-ignored; do not commit the chains' documents). Do not fall back to third-party nutrition sites, Open Food Facts or memory.
3. Enter the items. Use the chain's own item names, with the size after a comma ("French Fries, Medium"). Units: energy in kcal, protein, carbs, fat, fiber and sugar in grams, sodium in milligrams, weight in grams.
4. Run `tool/make_menus.py`. Fix every failure by re-reading the source, never by adjusting a number to pass.
5. Re-read a sample against the source: every item in the smallest chain files, and at least one item in five in larger ones, chosen across categories. Record in `notes` what was checked.
6. Tell the user, per chain, how many items were entered, how many skipped and why.

### 3.4 Keeping it current

Chains change recipes. The roadmap asks for a re-check a few times a year. When values change: update the chain file and its `checkedAt`, re-run the script with the next `version`, and ship with an app release. Add a line to the roadmap's open questions noting when the data was last checked.

---

## 4. Phase C — Finish

1. `flutter analyze && flutter test`, both clean. `dart run build_runner build --delete-conflicting-outputs` leaves no diff under `lib` or `test`.
2. Build both platforms: `flutter build ios --simulator --debug --no-codesign` and `flutter build apk --debug`. Check the app size change from the JSON (expect well under 1 MB).
3. Try it: on the iOS simulator or the "Logbite Test API 33" Android emulator, log a medium fries and count the taps.
4. Docs, in the same change:
   - `ROADMAP.md`: delete the M24 entry and its At a Glance row, renumber the ranks, remove D3 from Decisions and from the "D1–D8" references, set "v15 is next", and add the data re-check note.
   - `PRODUCT.md`: a What's Built row (what it does, which chains, the known limits: copied on tap, fixed menus only, values as of the checked date), "schema v14" in the What's Built intro, and a line in the free column of the Free vs Pro table.
   - `DATA_MODEL.md`: the two `food_items` columns, the schema history row for v14 (replace the "14 (planned)" row), and the schema version in the overview table.
   - `README.md`: a short "Restaurant menus" section beside "Starter foods" explaining `tool/menus/` and `tool/make_menus.py`.
   - `docs/privacy.md`: no change is needed (no new network call); the report link is covered by "Opening links". Confirm that is still true of what you built.
   - Delete this plan file, or move its still-useful parts (the file format and the data rules) into the README section. Finished plans do not stay in the repo; `PRODUCT.md` records that earlier ones were folded in and removed.
5. Tell the user what was built, what was not (chains left out and why), and what has not been run on a real phone.

---

## 5. Risks and open points

| Risk | What to do |
|---|---|
| A chain's nutrition data cannot be fetched | Leave the chain out and report it (3.3 step 2). Do not guess |
| Wrong values shipped | The energy check, the sample re-read, the source and date on every chain, and the in-app report link |
| Trademark or terms-of-use concern from a chain | Names only, no logos, values attributed to the chain with a date. This is the user's risk to accept under D3; flag anything in a chain's terms that forbids reuse of its nutrition data |
| The file's `version` is not raised after a change | The build script owns the version; never edit `menus.json` by hand |
| Item ids change between releases | Ids are permanent. A renamed product keeps its id; a discontinued one is removed from the file and existing catalog foods simply stop refreshing |
| A user's edited food looks out of date | By design. The food form could later offer "Reset to the restaurant's values"; out of scope here |
| Calorie-only users see chain items without weights logged by grams wrongly | `servingWeightG` is required, so every item has a real weight or volume |

Things the user may want to decide, none of which block Phase A: the final chain list (3.2); whether build-your-own chains are in the first release; whether to copy on tap (this plan) or on first log (the roadmap's wording).
