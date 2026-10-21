# Food Log App — Implementation Plan

How we get from the current repo to a working v1 of the app described in [`GAME_PLAN.md`](./GAME_PLAN.md).

> Related docs: [`GAME_PLAN.md`](./GAME_PLAN.md) (what the app does) · [`DATA_MODEL.md`](./DATA_MODEL.md) (schema)

---

## Framework Decision: Stay with Flutter

React Native would work, but nothing about this app needs it, and switching would discard working setup.

| Factor | Flutter (current) | React Native |
|---|---|---|
| Work already done | Toolchain, drift schema + generated code, Cupertino shell | Start over |
| Local relational data | `drift`: typed SQL, migrations, reactive `watch()` queries | `expo-sqlite` + Drizzle: comparable, but has to be set up again |
| UI needs (forms, lists, one chart) | Built-in widgets + `fl_chart` | Equivalent |
| Offline-only, no backend | Fine | Fine |
| Future cloud sync (Supabase) | `supabase_flutter` | `supabase-js` |

**When React Native would be worth it:** if you're much more fluent in React/TypeScript than Dart and Flutter is what's slowing you down, or if a web version is planned and you want to share code with it. The existing work would take about a day to redo, so this choice is cheap now and gets expensive after Milestone 3.

---

## Where Things Stand

| Area | State |
|---|---|
| `lib/main.dart`, `lib/app.dart` | `CupertinoApp` with three real tabs: Today (Home), Catalog and Summary |
| `lib/data/database/` | drift tables (split into `tables/`), four DAOs, repositories; database file `food_log`; generated code current |
| `lib/core/` | Pure Dart: `nutrition_math`, `date_key`, `metrics` (formatting), `validation`, `summary_math` (ranges, bucketing, averages) |
| `lib/views/` | Onboarding, Home (date header, totals, log list), Catalog (foods and meals, search, archive), Add Food sheet (catalog by servings or grams, one-off, new food with save & log), meal builder and meal log, Summary (range picker, averages, bar chart), Settings (the onboarding form) |
| `lib/providers/` | Riverpod providers for the database, repositories, preferences, the selected Home date, log entries, catalog lists and the Summary range and report |
| `test/` | Unit tests for `nutrition_math`, `summary_math`, `metrics`, `date_key`, validation; DAO and repository tests on `NativeDatabase.memory()`; widget tests for onboarding, Home, the food and adhoc forms, the catalog, Add Food, the meal flows, Summary, Settings, and a 2x-text / dark-mode layout pass |
| `flutter analyze` | Clean |
| App IDs | `com.nutriton.app` (Android, iOS, macOS, Linux, Windows metadata) |
| State management, preferences | Riverpod (no codegen) and `shared_preferences`, in place |
| Summary view | Done (M7) |
| Settings | Done (M8). Gear on Home opens it; saving applies at once |
| Device build | Done (M8). Release build installed and running on a physical iPhone |

---

## Data Model Changes (do these first)

The current schema has a few problems that will cause bugs once screens are built on it. They're cheap to fix now while nothing depends on the schema and nothing has been migrated.

### 1. Log entries should snapshot their macros

Right now a meal log entry stores only `meal_id`, and a food entry stores `food_item_id` + `servings`; macros are recomputed from the catalog at read time. That causes three problems:

- **Meal adjustments are lost.** GAME_PLAN lets the user add, remove, or re-weigh items before logging a meal, but there's nowhere to store those changes. The entry always points at the unmodified template.
- **History changes.** Editing a food item's calories or a meal's contents silently changes every past day that used it.
- **Summary queries are hard.** `resolved_calories` in the Summary query doesn't exist; computing it means joining across three entry types plus the meal junction table.

**Fix:** every log entry stores its own resolved `calories`, `protein`, `carbs`, `fat`, and `name` at the time it's logged. Catalog references become optional provenance links.

### 2. Normalize weights to grams

`item_ratio = meal_food_items.serving_weight / food_items.serving_weight` ignores units. A food defined as 100 g used in a meal at 4 oz gives a ratio of 0.04 instead of 1.13. Store all weights in grams (`weight_g`) and keep the user's preferred unit only for display. (1 oz = 28.3495 g)

### 3. Store `log_date` as a `yyyy-MM-dd` string

drift stores `DateTime` as a Unix timestamp. "Which day is this?" then depends on time zone, and grouping by day needs date math in SQL. A plain `'2026-10-20'` text key groups, sorts, and filters correctly with no conversion.

### 4. Smaller fixes

- `serving_weight` check should be `> 0`, not `>= 0`, because it's a divisor.
- Add an `entry_type` column (`'food' | 'meal' | 'adhoc'`) instead of inferring the type from which columns are null.
- Replace `onDelete: restrict` on catalog items with an `archived` flag. Users will want to delete foods they've logged before; with snapshots, past entries don't need the row to exist.
- Add `created_at` to log entries so items within a day have a stable order.
- Rename the database file from `my_database` to `food_log`.
- Add `// ignore_for_file: recursive_getters` to the table file (drift's recommended fix for the analyzer infos).

### Revised schema

```
food_items
  id               TEXT PK (uuid)
  name             TEXT
  calories         REAL  ≥ 0        -- per 1 serving
  protein          REAL  ≥ 0
  carbs            REAL  ≥ 0
  fat              REAL  ≥ 0
  serving_weight_g REAL  > 0
  display_unit     TEXT  'g' | 'oz'
  archived         BOOL  default false

meals
  id               TEXT PK
  name             TEXT
  archived         BOOL  default false

meal_food_items
  id               TEXT PK
  meal_id          → meals.id (cascade)
  food_item_id     → food_items.id
  weight_g         REAL  > 0
  sort_order       INT

food_log_entries
  id               TEXT PK
  log_date         TEXT  'yyyy-MM-dd'  (indexed)
  created_at       DATETIME
  entry_type       TEXT  'food' | 'meal' | 'adhoc'
  name             TEXT              -- snapshot
  calories         REAL  ≥ 0         -- snapshot, resolved totals
  protein          REAL  ≥ 0
  carbs            REAL  ≥ 0
  fat              REAL  ≥ 0
  food_item_id     → food_items.id  nullable  (provenance)
  meal_id          → meals.id       nullable  (provenance)
  servings         REAL  nullable    -- food entries only

food_log_entry_items      -- breakdown of a logged meal, as adjusted
  id               TEXT PK
  entry_id         → food_log_entries.id (cascade)
  food_item_id     → food_items.id nullable
  name             TEXT
  weight_g         REAL
  calories, protein, carbs, fat  REAL
```

The macro math from DATA_MODEL.md still applies; it just runs once, when the entry is saved, instead of on every read. The Summary query becomes:

```sql
SELECT AVG(day_cal), AVG(day_pro), AVG(day_carb), AVG(day_fat), COUNT(*) AS days_logged
FROM (
  SELECT log_date, SUM(calories) day_cal, SUM(protein) day_pro,
         SUM(carbs) day_carb, SUM(fat) day_fat
  FROM food_log_entries
  WHERE log_date BETWEEN :start AND :end
  GROUP BY log_date
);
```

Note the off-by-one in DATA_MODEL.md: `BETWEEN today-7 AND today` covers **8** days. A 7-day window starts at `today - 6`.

DATA_MODEL.md has been updated to match these changes.

---

## Architecture

### Packages

| Purpose | Package | Status |
|---|---|---|
| Database | `drift`, `drift_flutter`, `drift_dev`, `build_runner` | Installed |
| State management | `flutter_riverpod` | Installed |
| Preferences | `shared_preferences` | Installed |
| IDs | `uuid` | Installed |
| Date formatting | `intl` | Installed |
| Summary charts | `fl_chart` | Installed (Milestone 7, `^1.2.0`) |

**Why Riverpod:** drift's `watch()` queries return `Stream`s, and a Riverpod `StreamProvider` turns each one into a widget that rebuilds when the data changes. Logging a food on the Add sheet updates the Home list and totals with no manual refresh. Start without Riverpod code generation to keep `build_runner` limited to drift.

### Layers

```
UI (views/widgets)  →  providers (Riverpod)  →  repositories  →  drift DAOs / SharedPreferences
                                                      ↑
                                         nutrition_math.dart (pure Dart, unit-tested)
```

- **DAOs** hold the SQL only.
- **Repositories** own the business rules: resolving macros, unit conversion, building meal snapshots, and wrapping multi-table writes in transactions.
- **`nutrition_math.dart`** is plain functions (scale by servings, scale by weight, sum a meal, g↔oz). It has no Flutter or drift imports, so it's trivial to test.

### Folder structure

```
lib/
├── main.dart
├── app.dart                         # CupertinoApp, theme, onboarding gate
├── core/
│   ├── nutrition_math.dart
│   ├── date_key.dart                # DateTime ↔ 'yyyy-MM-dd'
│   └── metrics.dart                 # enum Metric { calories, protein, carbs, fat }
├── data/
│   ├── database/
│   │   ├── app_database.dart
│   │   ├── tables/…
│   │   └── daos/ (food_dao, meal_dao, log_dao, summary_dao)
│   ├── preferences/user_preferences.dart
│   └── repositories/ (catalog_repository, log_repository, summary_repository)
├── providers/
└── views/
    ├── onboarding/
    ├── home/
    ├── add_food/
    ├── catalog/
    ├── summary/
    └── settings/
```

### Navigation

- `CupertinoTabScaffold` with three tabs: **Today**, **Catalog**, **Summary**. Each tab gets its own `CupertinoTabView` so it keeps its own navigation stack.
- **Add Food** opens as a modal sheet from a `+` button in the Home nav bar. `CupertinoTabBar` items are tabs, so a "button" tab doesn't fit well.
- **Settings** is a gear icon in the Home nav bar and reuses the onboarding form.
- On launch, if `onboarding_complete` isn't set in preferences, show Onboarding instead of the tab scaffold.

> The app is Cupertino-only, so it will look like iOS on Android too. That's fine if it's intentional. If Android matters, it's easier to decide now than to retrofit `Material` later.

---

## Milestones

Each milestone ends with something runnable and its tests passing.

### M0 — Cleanup
- [x] Replace the failing counter test with a smoke test that pumps `MyApp`
- [x] Silence `recursive_getters` in the table file; `flutter analyze` is clean
- [x] Rename placeholder tabs; replace the README boilerplate with a short description and setup steps (`flutter pub get`, `dart run build_runner build`)
- [x] Change the app ID / bundle ID from `com.example.*` (much harder to change after any store upload)
- [x] Fix "three entry methods" → four in GAME_PLAN.md

### M1 — Data layer
- [x] Apply the schema changes above; split tables into `data/database/tables/`
- [x] `nutrition_math.dart` + unit tests (servings scaling, weight scaling, meal sum, g↔oz, zero/rounding edge cases)
- [x] DAOs: food items (CRUD, search by name, archive), meals (CRUD with items), log (watch entries for date, insert, update, delete), summary (averages for a range)
- [x] Repositories with transactions for meal create/update and meal logging
- [x] DAO tests against an in-memory database (`NativeDatabase.memory()`)

**Done when:** every create/log/summary path in the data model is exercised by a test, with no UI involved.

### M2 — Preferences, onboarding, app shell
- [x] `UserPreferences` wrapper over `shared_preferences` (primary metric, secondary metrics as a list, daily goal, display unit, `onboarding_complete`)
- [x] Riverpod setup: `ProviderScope`, providers for database, repositories, and preferences
- [x] Onboarding screen: pick primary metric, toggle secondaries, enter goal, choose g/oz
- [x] Tab scaffold with three empty tabs; onboarding gate on launch

### M3 — Home view
- [x] Date header: `Today` / `Yesterday` / `Mon, Oct 20` (`Mon, Oct 20, 2025` outside the current year), with ‹ › arrows (tap the title to jump back to today)
- [x] Macro summary: primary metric large with progress toward goal, secondaries below
- [x] Log list driven by `watchEntriesForDate`; swipe to delete; tap to edit servings (food entries) or view the breakdown (meal entries)
- [x] Empty state for days with nothing logged

### M4 — Food catalog
- [x] Catalog tab: segmented control for Foods / Meals, search field (literal substring match: `%` and `_` are escaped, not LIKE wildcards)
- [x] Food item form: name, the four macros per serving, serving weight + unit; validation (required fields, non-negative, weight > 0)
- [x] Edit and archive food items

### M5 — Add Food sheet
- [x] **From catalog:** search → pick → enter servings (with a live macro preview) → log
- [x] **Adhoc:** name + macros → log (never written to the catalog)
- [x] **New catalog item:** reuses the M4 form, with a "save & log" option
- [x] All paths log to Home's active date, not necessarily today

### M6 — Meals
- [x] Meal builder: name, add items from the catalog, set each item's weight, reorder/remove, running totals
- [x] Log meal: pick a meal → editable copy of its items (add, remove, re-weigh) → confirm writes one entry + `food_log_entry_items` snapshot, leaving the template unchanged
- [x] Optional "update meal template with these changes" toggle

### M7 — Summary view
- [x] Segmented control: Day / Week / Month / 6M / Year
- [x] Averages for each tracked metric, plus "days logged: n of N"
- [x] Bar chart of the primary metric across the range, with the goal as a reference line (`fl_chart`); 6M plots weekly averages and Year plots monthly averages. Week and Month plot one bar per day. Day has no chart, since a single bar adds nothing to the averages.

Logic lives in `core/summary_math.dart` (window, bucketing, averaging), with unit tests in `test/core/summary_math_test.dart`. Week and 6M buckets are counted back from today, so the newest bar is always complete. Year buckets are calendar months.

### M8 — Settings & polish
- [x] Settings screen (reuses the onboarding form; saving pops back to Home)
- [x] Number formatting and rounding rules: whole calories, one decimal for macros, applied through `Metric.format` and the shared `formatMacroLine`. Values that round to zero never show as `-0`.
- [x] Dark mode and 2x text checked in widget tests (`test/views/large_text_dark_mode_test.dart`), covering Home, Summary, Settings and onboarding. Keyboard: every form list (preferences, food, adhoc, meal builder and log, entry edit sheet) dismisses the keyboard on drag. Fixed layout overflows at 2x text on Home's macro summary and the Summary averages.
- [x] App icon and name: `Nutriton` is the display name on Android, iOS, web (`manifest.json`, page title) and the desktop binaries (macOS `PRODUCT_NAME`, Windows and Linux `BINARY_NAME` and window titles); the icon is generated from `assets/icon/app_icon.png` with `flutter_launcher_icons`.
- [x] Release build on a physical device: `flutter run --release` installed and ran on an iPhone, signed with a free Apple ID (Apple Development certificate, personal team). Free-account builds expire after 7 days; reinstalling renews them. The device needs Developer Mode on and the developer certificate trusted under Settings > General > VPN & Device Management.

---

## Testing Strategy

| Layer | Approach |
|---|---|
| `nutrition_math`, `date_key` | Plain unit tests: the most value per line |
| DAOs / repositories | In-memory drift database, one fresh DB per test |
| Screens | Widget tests for forms (validation) and Home (shows entries for the date, totals update) with providers overridden |
| Migrations | Once v1 has shipped, any schema change bumps `schemaVersion` and gets a drift migration test (`drift_dev schema dump` / `schema steps`) |

Run `flutter analyze && flutter test` before each push.

---

## Open Questions

All five are decided. The reasoning is recorded so it isn't reopened by accident:

1. **Goals for non-calorie metrics.** *Decided:* a goal per tracked metric, stored as optional `goal_<metric>` preferences. The primary metric needs a goal in onboarding; secondary goals may be left blank. The Home progress bars and the Summary goal line use the goal for the metric shown.
2. **Summary averaging.** *Decided:* average over days with at least one entry. Skipped days do not count, and "days logged: n of N" shows the basis. Day totals are summed first, then averaged. Each chart bar is the per-logged-day average within its bucket.
3. **Logging by weight.** *Decided and implemented in M5:* a catalog food can be logged by servings or by weight. The weight is typed in the user's display unit (g or oz), converted to grams and then to servings with `servingsForWeight`, and the entry stores the resulting snapshot. Meal item weights also use the display unit.
4. **Android look.** *Decided:* Cupertino everywhere, including Android. Adaptive widgets are not planned for v1.
5. **Fiber, sugar, sodium.** *Decided:* out of scope for v1. Adding one later means a new `Metric` value and a column. The onboarding picker and the Summary both iterate `Metric.values`, so they pick it up without other changes.

---

## After v1

- **Scheduling.** Planned meals for future days, as described in GAME_PLAN.md (`scheduled_meals` table, suggestions on Home that the user confirms)
- **Barcode / food lookup.** Open Food Facts API to prefill the food item form
- **Backup.** Export/import the SQLite file or JSON; later, Supabase sync (the schema maps directly to Postgres)
- **Quick re-log.** "Copy yesterday" and recent/frequent items at the top of the Add sheet
