# Food Log App — Data Model

---

## Overview

| Property | Decision |
|---|---|
| Storage | Local SQLite via `drift`, database file `food_log`, schema version 2 |
| User preferences | `shared_preferences` (separate from SQLite) |
| ID format | UUID v4 via `uuid` (`TEXT` primary keys) |
| Weights | Stored in grams (`*_g`). Users pick g or oz for display only; 1 oz = 28.3495 g |
| Dates | `log_date` is a `yyyy-MM-dd` text key (calendar day, no time zone) |
| Macro storage | Log entries store their own resolved macros (snapshots). Catalog links are provenance only |

---

## Tables

### `food_items`

Saved catalog foods. Macros are stored per 1 serving, where 1 serving is `serving_weight_g` grams.

| Column | Type | Nullable | Constraints / Notes |
|---|---|---|---|
| `id` | TEXT | No | Primary key (UUID) |
| `name` | TEXT | No | 2–100 characters |
| `calories` | REAL | No | `>= 0`, per 1 serving |
| `protein` | REAL | No | `>= 0`, per 1 serving |
| `carbs` | REAL | No | `>= 0`, per 1 serving |
| `fat` | REAL | No | `>= 0`, per 1 serving |
| `serving_weight_g` | REAL | No | `> 0` (used as a divisor) |
| `display_unit` | TEXT | No | `'g'` or `'oz'`, default `'g'`. Display only. This is the food's own unit: the catalog list and food form show the serving weight in it. Logging inputs (weight entry, meal items) use the user's display-unit setting instead |
| `archived` | BOOL | No | Default `false`. Archived foods leave search but remain referenced by past entries |

---

### `meals`

Named meal templates in the catalog. Items live in `meal_food_items`.

| Column | Type | Nullable | Constraints / Notes |
|---|---|---|---|
| `id` | TEXT | No | Primary key (UUID) |
| `name` | TEXT | No | 2–100 characters |
| `archived` | BOOL | No | Default `false` |

---

### `meal_food_items`

Junction table: the foods in a meal template and how much of each. Editing a logged meal does not change this table unless the user opts to update the template.

| Column | Type | Nullable | Constraints / Notes |
|---|---|---|---|
| `id` | TEXT | No | Primary key (UUID) |
| `meal_id` | TEXT | No | FK → `meals.id`, `ON DELETE CASCADE` |
| `food_item_id` | TEXT | No | FK → `food_items.id`, `ON DELETE RESTRICT` |
| `weight_g` | REAL | No | `> 0` |
| `sort_order` | INT | No | Display order within the meal, default `0` |

---

### `food_log_entries`

The daily log. One row per logged item: a catalog food, a meal, or an adhoc entry. Every row stores its own resolved macros, taken when it was logged.

| Column | Type | Nullable | Constraints / Notes |
|---|---|---|---|
| `id` | TEXT | No | Primary key (UUID) |
| `log_date` | TEXT | No | `yyyy-MM-dd`. Indexed (`food_log_entries_log_date`) |
| `created_at` | DATETIME | No | Set on insert; gives a stable order within a day |
| `entry_type` | TEXT | No | `'food'`, `'meal'` or `'adhoc'` |
| `name` | TEXT | No | Snapshot of the food, meal or adhoc name |
| `calories` | REAL | No | `>= 0`, resolved total for this entry |
| `protein` | REAL | No | `>= 0`, resolved total |
| `carbs` | REAL | No | `>= 0`, resolved total |
| `fat` | REAL | No | `>= 0`, resolved total |
| `food_item_id` | TEXT | Yes | FK → `food_items.id`, `ON DELETE SET NULL` (provenance) |
| `meal_id` | TEXT | Yes | FK → `meals.id`, `ON DELETE SET NULL` (provenance) |
| `servings` | REAL | Yes | Food entries only, `> 0` |

**Entry type reference:**

| Entry type | `food_item_id` | `meal_id` | `servings` | Breakdown rows in `food_log_entry_items` |
|---|---|---|---|---|
| `food` (from catalog) | ✅ | null | ✅ | none |
| `meal` (from catalog) | null | ✅ | null | ✅ one per item eaten |
| `adhoc` | null | null | null | none |

> **Note:** Adhoc entries are self-contained and never written to `food_items`, so the catalog stays clean.

---

### `food_log_entry_items`

The breakdown of a logged meal, as it was actually eaten. This can differ from the template: items may have been added, removed or re-weighed. Values are snapshots.

| Column | Type | Nullable | Constraints / Notes |
|---|---|---|---|
| `id` | TEXT | No | Primary key (UUID) |
| `entry_id` | TEXT | No | FK → `food_log_entries.id`, `ON DELETE CASCADE` |
| `food_item_id` | TEXT | Yes | FK → `food_items.id`, `ON DELETE SET NULL` (provenance) |
| `name` | TEXT | No | Snapshot of the food name |
| `weight_g` | REAL | No | `> 0` |
| `calories` | REAL | No | `>= 0`, resolved for `weight_g` |
| `protein` | REAL | No | `>= 0` |
| `carbs` | REAL | No | `>= 0` |
| `fat` | REAL | No | `>= 0` |

---

### `scheduled_meals`

Planned meals (schema v2). A plan is only a suggestion on Home; it never logs by itself. With `weekdays` null it is a one-off on `start_date`; otherwise it repeats on those weekdays from `start_date` on.

| Column | Type | Nullable | Constraints / Notes |
|---|---|---|---|
| `id` | TEXT | No | Primary key (UUID) |
| `meal_id` | TEXT | No | FK → `meals.id`, `ON DELETE CASCADE` |
| `start_date` | TEXT | No | `yyyy-MM-dd`. The day of a one-off, or the first day of a repeating plan. Indexed (`scheduled_meals_start_date`) |
| `weekdays` | INT | Yes | Bitmask, bit 0 = Monday ... bit 6 = Sunday, `1..127`. Null = one-off. Mon–Fri = `31` |
| `created_at` | DATETIME | No | Set on insert; orders suggestions |

---

### `scheduled_meal_outcomes`

What happened to a plan on one day. A plan with no row for a day is still a pending suggestion that day. Confirming a suggestion logs the meal through the normal meal-logging path (a snapshot entry with a breakdown, from the meal's current template) and writes a `logged` row; dismissing writes a `dismissed` row.

| Column | Type | Nullable | Constraints / Notes |
|---|---|---|---|
| `id` | TEXT | No | Primary key (UUID) |
| `scheduled_meal_id` | TEXT | No | FK → `scheduled_meals.id`, `ON DELETE CASCADE` |
| `date` | TEXT | No | `yyyy-MM-dd` the suggestion was for. Unique together with `scheduled_meal_id` |
| `status` | TEXT | No | `'logged'` or `'dismissed'` |
| `entry_id` | TEXT | Yes | FK → `food_log_entries.id`, `ON DELETE SET NULL` (provenance, set when `logged`) |

**Pending on date D:** the plan is due (one-off: `start_date = D`; repeating: `start_date <= D` and the weekday bit of D is set in `weekdays`) and has no outcome row for D. "Stop repeating" deletes the plan, which cascades its outcomes.

**Migration:** `schemaVersion` 1 → 2 creates both tables and the index (`onUpgrade` in `app_database.dart`; covered by `test/data/migrations/schema_migration_test.dart`).

---

### `user_preferences`

Stored via `shared_preferences`, not in SQLite. Read on app launch to configure the UI and determine which macros to display.

| Key | Type | Notes |
|---|---|---|
| `primary_metric` | String | e.g. `"calories"` |
| `tracked_metrics` | String list | Metric names, e.g. `["calories", "protein", "fat"]`. Always includes the primary metric; the rest are the secondaries |
| `goal_<metric>` | Float | Daily goal per metric, e.g. `goal_calories`, `goal_protein`. Required for the primary metric, optional otherwise (key absent = no goal) |
| `display_unit` | String | `"g"` or `"oz"`. Logging weights (weight entry, meal items) are typed and shown in this unit and stored in grams. Also the default unit for a new catalog food, which then keeps its own `food_items.display_unit` |
| `onboarding_complete` | Bool | Gate for the onboarding screen |

---

## Relationships

```
food_items      ||--o{  meal_food_items      : "included in"
meals           ||--o{  meal_food_items      : "contains"
meals           ||--o{  food_log_entries     : "provenance of"
food_items      ||--o{  food_log_entries     : "provenance of"
food_log_entries||--o{  food_log_entry_items : "breakdown of"
food_items      ||--o{  food_log_entry_items : "provenance of"
meals           ||--o{  scheduled_meals      : "planned as"
scheduled_meals ||--o{  scheduled_meal_outcomes : "resolved by"
food_log_entries||--o{  scheduled_meal_outcomes : "provenance of"
```

Catalog rows are archived, not deleted, so provenance links normally stay valid. `SET NULL` covers the rare hard delete.

---

## Macro Calculation Rules

Macros are resolved once, when an entry is saved. Nothing is recomputed on read.

**Scaling by weight** (used for catalog foods in a meal)
```
item_ratio = weight_g / food_items.serving_weight_g
item_calories = food_items.calories * item_ratio      (likewise protein, carbs, fat)
```
Example: a food defined per 100 g, eaten at 4 oz (113.398 g), gives `item_ratio` = 1.13398. Dividing grams by grams is what keeps the units consistent.

**Logging a food item (by servings)**
```
entry.calories = food_items.calories * servings      (likewise protein, carbs, fat)
```

**Logging a meal**

Each item in the breakdown is scaled by weight as above. The entry total is the sum of its breakdown rows:
```
entry.calories = SUM(food_log_entry_items.calories)   (likewise protein, carbs, fat)
```

**Logging an adhoc item**
```
entry.calories = user-entered value                  (likewise protein, carbs, fat)
```

**Editing servings on a food entry**

The snapshot is rescaled by the ratio of new to old servings. It does not re-read the catalog, so past values stay put.
```
new_total = old_total * (new_servings / old_servings)
```

---

## Summary View Queries

The Summary View averages over days that have at least one entry. Days with nothing logged are skipped, so they don't pull the averages down. The day totals are taken first, then averaged across days.

```sql
SELECT
  AVG(day_cal)  AS avg_calories,
  AVG(day_pro)  AS avg_protein,
  AVG(day_carb) AS avg_carbs,
  AVG(day_fat)  AS avg_fat,
  COUNT(*)      AS days_logged
FROM (
  SELECT log_date,
         SUM(calories) AS day_cal,
         SUM(protein)  AS day_pro,
         SUM(carbs)    AS day_carb,
         SUM(fat)      AS day_fat
  FROM food_log_entries
  WHERE log_date BETWEEN :start AND :end
  GROUP BY log_date
);
```

`:start` and `:end` are inclusive. A window of N days ending on `:end` starts at `:end - (N - 1)`, so a 7-day week ending today starts six days back.

| Interval | Window length (days) |
|---|---|
| Day | 1 |
| Week | 7 |
| Month | 30 |
| 6 Months | 180 |
| Year | 365 |

---

## Package Stack

| Purpose | Package |
|---|---|
| Main data store | `drift` (+ `drift_flutter`, `drift_dev`, `build_runner`) |
| State management | `flutter_riverpod` |
| User settings | `shared_preferences` |
| Unique IDs | `uuid` |
| Backup file picking | `file_picker` |
| Date formatting | `intl` |

---

## Folder Structure

```
lib/
├── core/
│   ├── nutrition_math.dart          # pure functions: scaling, sums, g <-> oz
│   ├── date_key.dart                # DateTime <-> 'yyyy-MM-dd'
│   ├── weekdays.dart                # weekday bitmasks for scheduled meals
│   └── metrics.dart                 # enum Metric { calories, protein, carbs, fat }
├── data/
│   ├── database/
│   │   ├── app_database.dart        # drift DB definition (file: food_log)
│   │   ├── tables/
│   │   │   ├── food_items.dart
│   │   │   ├── meals.dart
│   │   │   ├── meal_food_items.dart
│   │   │   ├── food_log_entries.dart
│   │   │   ├── food_log_entry_items.dart
│   │   │   └── scheduled_meals.dart       # scheduled_meals + scheduled_meal_outcomes
│   │   └── daos/
│   │       ├── food_dao.dart
│   │       ├── meal_dao.dart
│   │       ├── log_dao.dart
│   │       ├── scheduled_meal_dao.dart
│   │       └── summary_dao.dart
│   ├── preferences/
│   │   └── user_preferences.dart
│   └── repositories/
│       ├── catalog_repository.dart
│       ├── log_repository.dart
│       ├── schedule_repository.dart
│       └── summary_repository.dart
├── providers/
└── views/
    ├── onboarding/
    ├── home/
    ├── add_food/
    ├── catalog/
    ├── summary/
    └── settings/
```

---

## Future Considerations

- **Cloud sync**: the SQLite schema maps cleanly to PostgreSQL (e.g. Supabase) if remote backup or multi-device support is added later.
