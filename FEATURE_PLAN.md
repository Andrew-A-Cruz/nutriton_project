# Food Log App — Feature Plan (post-v1)

The features after v1, ordered by value for effort: the most daily benefit for the least work comes first. v1 (M0–M8) is in [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md).

> Related docs: [`GAME_PLAN.md`](./GAME_PLAN.md) · [`DATA_MODEL.md`](./DATA_MODEL.md) · [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) · [`MONETIZATION_PLAN.md`](./MONETIZATION_PLAN.md)

---

## Already in v1

Three ideas from the brainstorm are already built, so they are not milestones here:

| Idea | Where it already is |
|---|---|
| Goal progress on Home | M3: progress bar plus "n left" for each metric that has a goal (`views/home/macro_summary.dart`) |
| Goals for protein, carbs and fat | Open Question 1: optional `goal_<metric>` preferences, set in onboarding and Settings |
| Edit and delete log entries | M3: swipe to delete, tap to edit servings or view a meal's breakdown |

---

## Order at a Glance

| # | Milestone | Value | Effort | Schema change | New packages |
|---|---|---|---|---|---|
| M9 | Recent and frequent foods | High | S | No | None |
| M10 | Log again and copy day | High | S | No | None |
| M11 | Backup: export and import | High | M | No | `share_plus`, `file_picker` |
| M12 | Meal sections (breakfast, lunch, dinner, snacks) | Medium | M | v2 (first migration) | None |
| M13 | Fiber, sugar, sodium | Medium | M | v3 | None |
| M14 | Streaks and reminders | Medium | M | No | `flutter_local_notifications`, `timezone` |
| M15 | Body weight tracking | Medium | M | v4 (new table) | None |
| M16 | Barcode scan and food lookup | High | L | v5 (barcode column) | `mobile_scanner`, `http` |
| M17 | Planned meals (scheduling) | Medium | L | v6 (new table) | None |
| M18 | Home screen widget | Low–Med | L | No | `home_widget` + a Swift WidgetKit target |
| M19 | Apple Health | Low–Med | M | No | `health` |
| M20 | Cloud sync | Low (one device) | XL | Sync metadata | `supabase_flutter` |
| M21 | Pro unlock (monetization) | — | M | No | `purchases_flutter` |

**Why this order:**
- **M9 and M10 come first.** They remove taps from every logging session and are pure queries and repository code on the current schema.
- **M11 comes before any migration.** The app now holds real data on your phone. The first schema migration (M12) is the first chance to lose it, so an export path must exist before then.
- **M13 comes before M16.** Open Food Facts returns fiber, sugar and sodium, so a barcode lookup can fill them once the columns exist.
- **M16 is high value but large.** It brings in the network, the camera, permissions and messy third-party data. It is placed after the cheaper wins, not because it matters less.
- **M18 to M20 are late.** They're mostly platform plumbing, and M18 and M19 may need a paid Apple Developer account (see Open Questions).
- **M21 is last.** Pro only has something to sell once the features it unlocks exist. Detailed in [`MONETIZATION_PLAN.md`](./MONETIZATION_PLAN.md).

---

## Milestones

Each milestone ends with something runnable and its tests passing, as in v1. Run `flutter analyze && flutter test` before each push.

### M9 — Recent and frequent foods
- [ ] `LogDao.watchRecentSources(limit)`: distinct catalog foods and meals from `food_log_entries`, newest `created_at` first, skipping archived items and adhoc entries
- [ ] `LogDao.watchFrequentSources(sinceDate, limit)`: the same sources ranked by how often they were logged in the last 30 days
- [ ] Add Food sheet: a "Recent" section above the catalog list, with a Recent / Frequent toggle. Tapping an item opens the normal servings or meal flow
- [ ] Prefill servings with the amount used last time, read from the most recent entry for that food
- [ ] Hide the section while the user is searching
- [ ] DAO tests: ordering, the archived and adhoc exclusions, the 30-day window; a widget test for the section

**Done when:** a food logged yesterday can be logged again in two taps from the Add sheet.

### M10 — Log again and copy day
- [ ] `LogRepository.duplicateEntry(entryId, toDate)` copies the snapshot row and its `food_log_entry_items` in one transaction, with a new id and `created_at`. It copies the snapshot, not the current catalog values, so you get exactly what you ate before
- [ ] `LogRepository.copyDay(fromDate, toDate)`: every entry from one day, in its original order
- [ ] Entry tile: a "Log again today" swipe or long-press action (disabled when Home is already on today)
- [ ] Home: a "Copy from…" action in the nav bar. It defaults to the previous day, and its date picker shows how many entries the chosen day has
- [ ] Empty-day state: a "Copy yesterday" button
- [ ] Repository tests: meal breakdown rows are copied, the source day is unchanged, copying an empty day is a no-op

### M11 — Backup: export and import
- [ ] Format: a single JSON file `{ "format": 1, "schemaVersion": n, "exportedAt", "preferences": {…}, "tables": {…} }`. JSON is chosen over copying the SQLite file because it stays readable across schema versions (see Open Questions)
- [ ] `BackupRepository.export()` reads every table plus `UserSettings` into the JSON. Settings shares it through the share sheet (`share_plus`), so it can go to Files, AirDrop or email
- [ ] `BackupRepository.import(file)` validates the format and version, shows counts ("212 entries, 48 foods, 6 meals"), then replaces all data in one transaction after a destructive-action confirm
- [ ] An import from an older `schemaVersion` is supported by mapping missing columns to their defaults. One from a newer version is refused with a clear message
- [ ] A "Last backup: n days ago" line in Settings, stored in preferences
- [ ] Tests: an export then import round trip gives identical rows; a corrupt file or one from a newer version changes nothing

**Done when:** you can export on the phone, delete the app, reinstall and import with nothing lost. Do this once by hand before starting M12.

### M12 — Meal sections
- [ ] **Migration setup** (first time, reused by every later schema change): dump the current schema with `dart run drift_dev make-migrations`, commit `drift_schemas/`, and add the generated migration test. Bump `schemaVersion` to 2
- [ ] Add a nullable `meal_slot` column to `food_log_entries`: `'breakfast' | 'lunch' | 'dinner' | 'snack'`. Existing rows stay null and show under "Other"
- [ ] Default slot when logging, by time of day: before 10:30 breakfast, before 15:00 lunch, before 20:00 dinner, otherwise snack. The user can change it in the Add sheet and in the entry edit sheet
- [ ] Home log list: grouped sections with a calorie subtotal per section. Empty sections are hidden
- [ ] Log again (M10) keeps the slot. Copy day keeps each entry's slot
- [ ] Backup format: add the column (M11 maps it to null for older files)
- [ ] Migration test from v1 to v2 with real-looking rows; widget test for grouping

### M13 — Fiber, sugar, sodium
- [ ] `Metric`: add `fiber (g)`, `sugar (g)` and `sodium (mg)`. Sodium is the first metric not in grams, so check every place that assumes `g` (`formatMacroLine`, form suffixes)
- [ ] `Macros`: add the three fields. Because the class is used everywhere, the compiler finds each place that builds one
- [ ] Schema v3: nullable `fiber`, `sugar` and `sodium` on `food_items`, `food_log_entries` and `food_log_entry_items`. Null means "not recorded" and is different from 0
- [ ] Sums and averages treat null as 0 but report coverage, e.g. "sodium recorded for 3 of 5 entries" on Home and Summary
- [ ] Forms: the three fields show only for metrics the user tracks, and are optional
- [ ] `formatMacroLine` shows only tracked metrics; check that 2x text still fits
- [ ] Migration test v2 to v3; `nutrition_math` tests for null handling

### M14 — Streaks and reminders
- [ ] Streak: the number of consecutive days with at least one entry, ending today (or yesterday, if today is still empty). Shown as a small badge in the Home header. A pure function in `core/` plus one `SummaryDao` query
- [ ] Reminders in Settings: up to three daily times, off by default. Ask for notification permission only when the user turns one on
- [ ] "Nothing logged yet" reminder: schedule one-off notifications for the next 14 days. Cancel today's when the first entry for today is logged, and top the schedule up on each app launch. iOS can't run the check in the background, so this is how it works without a server
- [ ] Tests: streak edge cases (gaps, today empty, month boundary); scheduling logic behind an interface so it can be faked

### M15 — Body weight tracking
- [ ] New table `body_weights`: `log_date` (unique), `weight_kg`, `created_at`. Schema v4
- [ ] Preference `body_weight_unit`: `kg` or `lb`. This is separate from the food `display_unit`, since people often weigh food in grams and themselves in pounds
- [ ] Home: a "Weigh in" row on the selected date (one value per day, editing replaces it)
- [ ] Summary: a weight line chart for the range, with a 7-day moving average to smooth out daily noise, next to average calories
- [ ] Backup format and the migration test include the new table

### M16 — Barcode scan and food lookup
- [ ] Schema v5: nullable, indexed `barcode` column on `food_items`
- [ ] Scan button on the new-food form (`mobile_scanner`). Add `NSCameraUsageDescription` to `ios/Runner/Info.plist`
- [ ] Look up the barcode locally first: if it is already a catalog food, go straight to the log flow, with no network call
- [ ] Otherwise call Open Food Facts (`/api/v2/product/{barcode}`) with an identifying `User-Agent`, as their terms ask. Map the per-100 g nutriments, and the serving size when present, into a prefilled food form. The user always reviews the form before saving
- [ ] Handle the failure cases: offline, not found, missing nutriments, kJ with no kcal (convert at 4.184), sodium given in g
- [ ] Optional: a text search of Open Food Facts from the catalog search field, with a "Search online" row
- [ ] Tests: the mapper against saved JSON fixtures (complete, partial, kJ-only); the HTTP client behind an interface

### M17 — Planned meals (scheduling)
- [ ] Table `scheduled_items`: `meal_id` or `food_item_id`, `meal_slot`, `weekdays` (bitmask), `servings`, `active`. Schema v6
- [ ] Catalog: "Schedule…" on a meal or food (pick weekdays and a slot)
- [ ] Home: scheduled items that haven't been logged yet appear as dimmed suggestion rows in their section. Tap to log, swipe to skip for that day. They never log automatically, per GAME_PLAN
- [ ] Suggestions don't count toward totals until confirmed
- [ ] Repository tests: matching by weekday, a confirmed or skipped item disappears, archived sources are hidden

### M18 — Home screen widget
- [ ] Check first: App Groups provisioning with your signing setup (see Open Questions)
- [ ] `home_widget`: the app writes today's totals and goal to shared storage whenever the log changes. A small SwiftUI WidgetKit extension shows remaining calories and a progress ring
- [ ] Refresh on log changes and at midnight

### M19 — Apple Health
- [ ] Check first: the HealthKit entitlement with your signing setup (see Open Questions)
- [ ] Write each day's dietary energy, protein, carbs and fat (and M13's fiber, sugar and sodium). Writes are idempotent, so editing an entry rewrites that day
- [ ] Read body weight into M15's table, marked with its source so it isn't written back
- [ ] Opt-in from Settings, with per-type permissions

### M20 — Cloud sync
- [ ] Decide whether it is needed. With M11 in place, sync is only worth building for a second device or a web view
- [ ] If yes: Supabase Postgres mirroring the drift schema, `updated_at` and `deleted` columns on every table, last-write-wins per row, and sign in with Apple
- [ ] Plan this one separately in detail before starting. The choice between CloudKit and Supabase also decides its pricing tier (see [`MONETIZATION_PLAN.md`](./MONETIZATION_PLAN.md#sync-and-pricing))

### M21 — Pro unlock
- [ ] Free core plus a one-time Pro in-app purchase, with an optional subscription later only for features that cost money to run. Full plan, free/Pro split and checklist in [`MONETIZATION_PLAN.md`](./MONETIZATION_PLAN.md)

---

## Schema Changes Summary

| Version | Milestone | Change |
|---|---|---|
| 1 | v1 | Current schema |
| 2 | M12 | `food_log_entries.meal_slot` (nullable) |
| 3 | M13 | `fiber`, `sugar`, `sodium` (nullable) on `food_items`, `food_log_entries`, `food_log_entry_items` |
| 4 | M15 | New `body_weights` table |
| 5 | M16 | `food_items.barcode` (nullable, indexed) |
| 6 | M17 | New `scheduled_items` table |

Each step gets a drift migration test (`make-migrations`) and an update to `DATA_MODEL.md` and the backup format.

---

## Open Questions

Decide each one before its milestone starts:

1. **Backup format (M11).** *Proposed:* JSON. Copying the SQLite file is simpler, but a file from an older build can't be safely opened by a newer one without running migrations on import, and you can't read or edit it. JSON costs about a day more.
2. **Slot times (M12).** The 10:30 / 15:00 / 20:00 cutoffs are a guess. Should they be adjustable in Settings, or are fixed times fine?
3. **Null vs 0 for new nutrients (M13).** *Proposed:* null means not recorded, so old foods don't claim 0 mg of sodium. The cost is the coverage text in the UI.
4. **Paid Apple Developer account (M18, M19).** Your current builds use a free personal team. Free teams may not be able to provision App Groups (M18) or HealthKit (M19), and their builds expire after 7 days. Check what your team can provision before starting either milestone. If it can't, these two wait or are dropped.
5. **Cloud sync (M20).** Is a second device or a web version actually planned? If not, M20 can be cut.
6. **Monetization (M21).** Price, the free/Pro split, and whether sync is Pro or a subscription. See [`MONETIZATION_PLAN.md`](./MONETIZATION_PLAN.md#open-questions).
