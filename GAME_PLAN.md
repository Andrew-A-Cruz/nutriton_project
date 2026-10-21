# Food Log App — Game Plan

A mobile app for tracking calories and macronutrients, built in Flutter.

---

## Views

The app has three primary views plus an initial onboarding view.

---

### Initial View (Onboarding)

Shown once on first launch. Collects user preferences before entering the app.

- User selects a **primary metric** to track (e.g. Calories)
- User selects **secondary metrics** (e.g. Protein, Carbs, Fat)
- User sets a **daily calorie goal**
- On completion, navigates to Home View

> This settings screen is also accessible later via a dedicated Settings view.

---

### Home View

The main daily logging screen.

**Date Navigation**
- Displays `Today` by default, or a formatted past/future date
- Forward and backward arrow buttons to change the active date

**Macro Summary**
- Shows the primary metric (e.g. Calories) prominently
- Shows any selected secondary metrics below it

**Food Log List**
- Lists all food entries logged for the active date
- Each entry shows name and relevant macro values

**Bottom Scaffold (Navigation Bar)**
- Switch between Home, Food Catalog, and Summary views
- Add Food button to open the Add Food View

---

#### Add Food View

Accessible from the Home View bottom scaffold. Four entry methods:

**1. Add from Food Catalog**
- User browses saved food items or meals
- Selects an item to log it for the active date

**2. Add Adhoc Food Item**
- One-off entry, not saved to the Food Catalog
- Requires: name, and values for all primary + secondary metrics

**3. Add Food Item (to Catalog)**
- Requires: name, all primary + secondary macro values, and a weight (oz or grams)
- 1 serving = the entered weight

**4. Add Meal**
- User selects a saved meal from the catalog
- Before confirming, user sees a list of all food items in the meal
- User can add, remove, or adjust the weight/serving of any item
- Final macro totals are calculated and logged for the active date

---

### Food Catalog View

A library of saved food items and meals.

**Food Items**
- Stored with: name, and all primary + secondary macro values
- Reusable across any day's log

**Meals**
- A named collection of food items
- Built from existing food catalog items
- Serves as a template when logging from the Home View

---

### Summary View

Displays nutritional averages over selectable time intervals.

| Interval | Description |
|---|---|
| Day | Single day snapshot |
| Week | 7-day average |
| Month | 30-day average |
| 6 Months | 180-day average |
| Year | 365-day average |

---

## Data Model

> See [`DATA_MODEL.md`](./DATA_MODEL.md) for full schema and relationships.

**Storage approach:** Local SQLite via [`drift`](https://drift.simonbinder.eu/)  
**User preferences:** [`shared_preferences`](https://pub.dev/packages/shared_preferences)

### Tables at a glance

| Table | Purpose |
|---|---|
| `food_items` | Saved food catalog entries |
| `meals` | Named meal templates |
| `meal_food_items` | Junction table — links meals to food items |
| `food_log_entries` | Daily log (food items, meals, and adhoc entries) |
| `user_preferences` | Primary metric, secondary metrics, calorie goal |

### Package Stack

| Purpose | Package |
|---|---|
| Main data store | `drift` |
| User settings | `shared_preferences` |
| Unique IDs | `uuid` |
| Date handling | `intl` or built-in `DateTime` |

---

## Future Ideas

- [ ] Scheduling — allow users to plan meals for future days (e.g. same lunch Mon–Fri)

---

## TODOs

- [ ] Finish `GAME_PLAN.md`
- [ ] Continue Flutter research
- [ ] Build app