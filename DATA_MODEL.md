# Food Log App — Data Model

---

## Overview

| Property | Decision |
|---|---|
| Storage | Local SQLite via `drift` |
| User preferences | `shared_preferences` (separate from SQLite) |
| ID format | UUID via `uuid` package |
| Serving definition | 1 serving = entered weight at time of creation |

---

## Tables

### `food_items`

Stores all saved food items in the catalog. Macro values are stored per 1 serving, where 1 serving equals the `serving_weight` entered at creation time.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `id` | UUID | No | Primary key |
| `name` | String | No | Display name |
| `calories` | Float | No | Per 1 serving |
| `protein` | Float | No | Per 1 serving |
| `carbs` | Float | No | Per 1 serving |
| `fat` | Float | No | Per 1 serving |
| `serving_weight` | Float | No | Weight of 1 serving |
| `weight_unit` | String | No | `"oz"` or `"g"` |

---

### `meals`

Stores named meal templates in the catalog. A meal is a collection of food items defined in `meal_food_items`.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `id` | UUID | No | Primary key |
| `name` | String | No | Display name |

---

### `meal_food_items`

Junction table linking meals to their constituent food items. Stores per-item weight so that individual serving sizes can be adjusted when a meal is logged without modifying the underlying meal template.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `id` | UUID | No | Primary key |
| `meal_id` | UUID | No | FK → `meals.id` |
| `food_item_id` | UUID | No | FK → `food_items.id` |
| `serving_weight` | Float | No | Weight of this item within the meal |
| `weight_unit` | String | No | `"oz"` or `"g"` |

---

### `food_log_entries`

The daily log. A single table handles all three entry types: food items, meals, and adhoc entries. The entry type is determined by which columns are populated.

| Column | Type | Nullable | Notes |
|---|---|---|---|
| `id` | UUID | No | Primary key |
| `log_date` | Date | No | The day this entry belongs to |
| `food_item_id` | UUID | Yes | FK → `food_items.id` |
| `meal_id` | UUID | Yes | FK → `meals.id` |
| `servings` | Float | Yes | Multiplier applied to food item macros |
| `adhoc_name` | String | Yes | Adhoc entries only |
| `adhoc_calories` | Float | Yes | Adhoc entries only |
| `adhoc_protein` | Float | Yes | Adhoc entries only |
| `adhoc_carbs` | Float | Yes | Adhoc entries only |
| `adhoc_fat` | Float | Yes | Adhoc entries only |

**Entry type reference:**

| Entry Type | `food_item_id` | `meal_id` | `servings` | `adhoc_*` fields |
|---|---|---|---|---|
| Food item from catalog | ✅ | null | ✅ | null |
| Meal from catalog | null | ✅ | null | null |
| Adhoc food item | null | null | null | ✅ |

> **Note:** Adhoc entries are self-contained within this table and never written to the food catalog, keeping the catalog clean.

---

### `user_preferences`

Stored via `shared_preferences`, not in SQLite. Read on app launch to configure the UI and determine which macros to display.

| Key | Type | Notes |
|---|---|---|
| `primary_metric` | String | e.g. `"calories"` |
| `secondary_metrics` | String | Comma-separated e.g. `"protein,fat"` |
| `daily_calorie_goal` | Float | User's daily calorie target |

---

## Relationships

```
food_items      ||--o{  meal_food_items   : "included in"
meals           ||--o{  meal_food_items   : "contains"
food_items      ||--o{  food_log_entries  : "logged as"
meals           ||--o{  food_log_entries  : "logged as"
```

---

## Macro Calculation Rules

**Logging a food item**
```
displayed_calories = food_items.calories * food_log_entries.servings
displayed_protein  = food_items.protein  * food_log_entries.servings
displayed_carbs    = food_items.carbs    * food_log_entries.servings
displayed_fat      = food_items.fat      * food_log_entries.servings
```

**Logging a meal**

Sum across all `meal_food_items` rows for the given `meal_id`, scaling each item's macros by its `serving_weight` relative to its defined serving:

```
item_ratio    = meal_food_items.serving_weight / food_items.serving_weight
meal_calories = SUM(food_items.calories * item_ratio)  for all items in meal
meal_protein  = SUM(food_items.protein  * item_ratio)  for all items in meal
meal_carbs    = SUM(food_items.carbs    * item_ratio)  for all items in meal
meal_fat      = SUM(food_items.fat      * item_ratio)  for all items in meal
```

**Logging an adhoc item**
```
displayed_calories = food_log_entries.adhoc_calories
displayed_protein  = food_log_entries.adhoc_protein
displayed_carbs    = food_log_entries.adhoc_carbs
displayed_fat      = food_log_entries.adhoc_fat
```

---

## Summary View Queries

The Summary View averages nutrition over selectable time intervals. Example query pattern:

```sql
SELECT
  AVG(daily_calories) as avg_calories,
  AVG(daily_protein)  as avg_protein,
  AVG(daily_carbs)    as avg_carbs,
  AVG(daily_fat)      as avg_fat
FROM (
  SELECT
    log_date,
    SUM(resolved_calories) as daily_calories,
    SUM(resolved_protein)  as daily_protein,
    SUM(resolved_carbs)    as daily_carbs,
    SUM(resolved_fat)      as daily_fat
  FROM food_log_entries
  WHERE log_date BETWEEN :start_date AND :end_date
  GROUP BY log_date
);
```

| Interval | `start_date` offset from today |
|---|---|
| Day | 0 days |
| Week | 7 days |
| Month | 30 days |
| 6 Months | 180 days |
| Year | 365 days |

---

## Package Stack

| Purpose | Package |
|---|---|
| Main data store | `drift` |
| User settings | `shared_preferences` |
| Unique IDs | `uuid` |
| Date handling | `intl` or built-in `DateTime` |

---

## Suggested Folder Structure

```
lib/
├── data/
│   ├── database/
│   │   ├── app_database.dart         # drift DB definition
│   │   ├── tables/
│   │   │   ├── food_items.dart
│   │   │   ├── meals.dart
│   │   │   ├── meal_food_items.dart
│   │   │   └── food_log_entries.dart
│   │   └── daos/
│   │       ├── food_dao.dart
│   │       ├── meal_dao.dart
│   │       └── log_dao.dart
│   └── preferences/
│       └── user_preferences.dart
├── models/
├── views/
│   ├── home/
│   ├── catalog/
│   └── summary/
└── widgets/
```

---

## Future Considerations

- **Scheduling** — a `scheduled_meals` table linking a `meal_id` to a recurring day pattern (e.g. Mon–Fri). Scheduled items would appear as suggestions on the Home View for the user to confirm, not auto-log.
- **Cloud sync** — SQLite schema maps cleanly to PostgreSQL (e.g. Supabase) if remote backup or multi-device support is added later.
