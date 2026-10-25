# Food Log App — Feature Plan (post-v1)

The features after v1, ordered by value for effort: the most daily benefit for the least work comes first. v1 (M0–M8) is in [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md). Fixes from the October 2026 review and an unordered backlog of further enhancements are at the end, under [Fixes From the October 2026 Review](#fixes-from-the-october-2026-review) and [Enhancement Backlog](#enhancement-backlog).

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
- [x] `LogDao.watchRecentSources(limit)`: distinct catalog foods and meals from `food_log_entries`, newest `created_at` first, skipping archived items and adhoc entries
- [x] `LogDao.watchFrequentSources(sinceDate, limit)`: the same sources ranked by how often they were logged in the last 30 days
- [x] Add Food sheet: a "Recent" section above the catalog list, with a Recent / Frequent toggle. Tapping an item opens the normal servings or meal flow
- [x] Prefill servings with the amount used last time, read from the most recent entry for that food
- [x] Hide the section while the user is searching
- [x] DAO tests: ordering, the archived and adhoc exclusions, the 30-day window; a widget test for the section

**Done when:** a food logged yesterday can be logged again in two taps from the Add sheet.

### M10 — Log again and copy day
- [x] `LogRepository.duplicateEntry(entryId, toDate)` copies the snapshot row and its `food_log_entry_items` in one transaction, with a new id and `created_at`. It copies the snapshot, not the current catalog values, so you get exactly what you ate before
- [x] `LogRepository.copyDay(fromDate, toDate)`: every entry from one day, in its original order
- [x] Entry tile: a "Log again today" swipe or long-press action (offered from the long-press menu, and left out when the entry is already on today)
- [x] Home: a "Copy from…" action in the nav bar. It defaults to the previous day, and its date picker shows how many entries the chosen day has
- [x] Empty-day state: a "Copy yesterday" button
- [x] Repository tests: meal breakdown rows are copied, the source day is unchanged, copying an empty day is a no-op

### M11 — Backup: export and import
- [x] Format: a single JSON file `{ "app": "nutriton", "version": 1, "exportedAt", "food_items": […], "meals": […], …, "preferences": {…} }`, one array per table with drift's generated row JSON. JSON is chosen over copying the SQLite file because it stays readable across schema versions. The `version` field plus the upgrade pipeline in `BackupCodec` (`_upgrades`) replaces the originally planned `format` / `schemaVersion` / `tables` layout
- [x] `BackupRepository.exportJson()` reads every table plus `UserSettings` in one transaction. Settings shares it through the share sheet (`share_plus`) on iOS and Android, so it can go to Files, AirDrop or email; desktop and web keep the `file_picker` save dialog (behind `BackupFileIo`)
- [x] `BackupRepository.readBackup(json)` validates the file and returns `BackupData` (nothing is changed); Settings shows counts ("212 entries, 48 foods, 6 meals", plus plans and the export date) in a destructive-action confirm, then `restore(data)` replaces all data in one transaction
- [x] An import from an older `version` is upgraded step by step, with missing columns mapped to their defaults. One from a newer version is refused with a clear message
- [x] A "Last backup: n days ago" line in Settings, stored in preferences (`last_backup_at`, not part of the backup itself)
- [x] Tests: an export then import round trip gives identical rows and preferences; a corrupt file or one from a newer version changes nothing

**Done when:** you can export on the phone, delete the app, reinstall and import with nothing lost. Do this once by hand before starting M12.

### M12 — Meal sections
- [x] **Migration setup** (first time, reused by every later schema change): dump the current schema with `dart run drift_dev make-migrations`, commit `drift_schemas/`, and add the generated migration test. *Done in the October 2026 fixes:* `build.yaml`, `drift_schemas/app_database/` (v1 and v2) and `test/drift/app_database/` exist; scheduling already took v2, so meal sections bump `schemaVersion` to 3
- [x] Add a nullable `meal_slot` column to `food_log_entries`: `'breakfast' | 'lunch' | 'dinner' | 'snack'`. Existing rows stay null and show under "Other"
- [x] Default slot when logging, by time of day: before 10:30 breakfast, before 15:00 lunch, before 20:00 dinner, otherwise snack. The user can change it in the Add sheet and in the entry edit sheet
- [x] Home log list: grouped sections with a calorie subtotal per section. Empty sections are hidden
- [x] Log again (M10) keeps the slot. Copy day keeps each entry's slot
- [x] Backup format: no bump needed. `meal_slot` is a nullable column, so a file from before M12 imports with null and one with an invalid slot is refused by the CHECK rule (tests in `test/data/backup/backup_meal_slot_test.dart`)
- [x] Migration test from v2 to v3 with real-looking rows (and v1 to v3); widget test for grouping

### M13 — Fiber, sugar, sodium
- [ ] `Metric`: add `fiber (g)`, `sugar (g)` and `sodium (mg)`. Sodium is the first metric not in grams, so check every place that assumes `g` (`formatMacroLine`, form suffixes)
- [ ] `Macros`: add the three fields. Because the class is used everywhere, the compiler finds each place that builds one
- [ ] Schema v4: nullable `fiber`, `sugar` and `sodium` on `food_items`, `food_log_entries` and `food_log_entry_items`. Null means "not recorded" and is different from 0
- [ ] Sums and averages treat null as 0 but report coverage, e.g. "sodium recorded for 3 of 5 entries" on Home and Summary
- [ ] Forms: the three fields show only for metrics the user tracks, and are optional
- [ ] `formatMacroLine` shows only tracked metrics; check that 2x text still fits
- [ ] Migration test v3 to v4; `nutrition_math` tests for null handling

### M14 — Streaks and reminders
- [ ] Streak: the number of consecutive days with at least one entry, ending today (or yesterday, if today is still empty). Shown as a small badge in the Home header. A pure function in `core/` plus one `SummaryDao` query
- [ ] Reminders in Settings: up to three daily times, off by default. Ask for notification permission only when the user turns one on
- [ ] "Nothing logged yet" reminder: schedule one-off notifications for the next 14 days. Cancel today's when the first entry for today is logged, and top the schedule up on each app launch. iOS can't run the check in the background, so this is how it works without a server
- [ ] Tests: streak edge cases (gaps, today empty, month boundary); scheduling logic behind an interface so it can be faked

### M15 — Body weight tracking
- [ ] New table `body_weights`: `log_date` (unique), `weight_kg`, `created_at`. Schema v5
- [ ] Preference `body_weight_unit`: `kg` or `lb`. This is separate from the food `display_unit`, since people often weigh food in grams and themselves in pounds
- [ ] Home: a "Weigh in" row on the selected date (one value per day, editing replaces it)
- [ ] Summary: a weight line chart for the range, with a 7-day moving average to smooth out daily noise, next to average calories
- [ ] Backup format and the migration test include the new table

### M16 — Barcode scan and food lookup
- [ ] Schema v6: nullable, indexed `barcode` column on `food_items`
- [ ] Scan button on the new-food form (`mobile_scanner`). Add `NSCameraUsageDescription` to `ios/Runner/Info.plist`
- [ ] Look up the barcode locally first: if it is already a catalog food, go straight to the log flow, with no network call
- [ ] Otherwise call Open Food Facts (`/api/v2/product/{barcode}`) with an identifying `User-Agent`, as their terms ask. Map the per-100 g nutriments, and the serving size when present, into a prefilled food form. The user always reviews the form before saving
- [ ] Handle the failure cases: offline, not found, missing nutriments, kJ with no kcal (convert at 4.184), sodium given in g
- [ ] Optional: a text search of Open Food Facts from the catalog search field, with a "Search online" row
- [ ] Tests: the mapper against saved JSON fixtures (complete, partial, kJ-only); the HTTP client behind an interface

### M17 — Planned meals (scheduling)
- [ ] Table `scheduled_items`: `meal_id` or `food_item_id`, `meal_slot`, `weekdays` (bitmask), `servings`, `active`. Schema v7
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

## Fixes From the October 2026 Review

Problems found in a review of the built app. Do these before new milestones: the first two can lose or misplace data.

- [x] **Stale "today".** `selectedDateProvider` is set to today once and kept alive, and nothing moves it when the app resumes or the date changes. Leave the app in the background overnight and the next morning's breakfast is logged to yesterday, while the header may still read "Today". Listen for app resume (`AppLifecycleListener`) and for midnight; if Home was on the old today, move it to the new one. Summary's `endDate: todayKey()` needs the same refresh. Test with an injectable clock
- [x] **Undo for swipe-to-delete.** One accidental swipe on Home deletes an entry for good. Show an "Entry deleted · Undo" banner for a few seconds that re-inserts the entry and its breakdown rows. This uses the same copy code as Log again (M10)
- [x] **Edit any entry.** Tapping a one-off entry does nothing, and food entries only let you change servings. Add an edit sheet for one-off entries (name and macros) and a "Move to another day" action for every entry type
- [x] **Read older backups after a schema change.** `BackupCodec` rejects newer files but has no step that upgrades older ones. Once a table gains a column (M12, M13), `fromJson` fails on a version 1 file and the restore reports "damaged". Before the next migration, add a per-version upgrade step that fills new columns with their defaults, plus a fixture test holding a real version 1 file
- [x] **Migration test tooling.** `schema_migration_test.dart` rebuilds v1 by hand. Set up `drift_dev make-migrations` and commit `drift_schemas/` (already planned in M12) before any further schema change. *Done:* after changing tables, bump `schemaVersion`, then run `dart run drift_dev make-migrations` and `dart run build_runner build`
- [x] **Double-tap on Copy yesterday.** Two quick taps copy the day twice. Disable the button while the copy runs
- [x] **Release housekeeping.** Android release builds still use the debug signing config; the `pubspec.yaml` description still reads "A new Flutter project."; the Open Food Facts User-Agent contains a personal email in a public repo (consider a project address). *Done:* release builds sign with `android/key.properties` when it exists (create it and the keystore before a Play release; it is git-ignored), and the User-Agent now gives the repo URL

---

## Enhancement Backlog

Ideas that aren't milestones yet. They aren't ordered: when one is picked up, give it a milestone number and place it in the table above. Schema changes get their version number at that point too. The tier column follows the rule of thumb in [`MONETIZATION_PLAN.md`](./MONETIZATION_PLAN.md#free-vs-pro).

### Faster logging

| Idea | Value | Effort | Schema change | Tier |
|---|---|---|---|---|
| Quick add | High | S | No | Free |
| Recipes with a cooked weight | High | M | Yes | Free |
| Favorites | Medium | S | Yes | Free |
| Duplicate a catalog food | Medium | S | No | Free |
| Serving presets | Medium | M | Yes (new table) | Free |
| Siri Shortcuts / App Intents | Low–Med | L | No | Pro candidate (see Open Questions) |

- [ ] **Quick add.** Log a number of calories (optionally with macros) with no name, e.g. a restaurant estimate. Stored as a one-off entry named "Quick add", so no schema change
- [ ] **Recipes with a cooked weight.** A meal records the raw ingredients, but batch cooking changes the weight (a pot of chili loses water). A recipe stores its ingredients plus the total cooked weight, so "200 g of chili" logs 200 / cooked weight of the recipe's totals. Either a `cooked_weight_g` column on `meals` or a separate recipe type; decide when planning it
- [ ] **Favorites.** A `favorite` flag on `food_items` and `meals`, shown as a star in the catalog and pinned at the top of the Add Food sheet, above Recent
- [ ] **Duplicate a catalog food.** "Duplicate" in the food action sheet opens the food form prefilled with "<name> copy", for variants like a different brand or size
- [ ] **Serving presets.** Named portions per food, such as "1 cup = 240 g" or "1 slice = 28 g", in a new `food_servings` table. The log-by-weight input offers them alongside g/oz. Open Food Facts' `serving_size` text can seed one preset
- [ ] **Siri Shortcuts / App Intents.** "Log my usual breakfast" or "How many calories are left?" from Siri, Spotlight or the Action button. Needs a Swift App Intents target and a platform channel, like M18

### Understanding your data

| Idea | Value | Effort | Schema change | Tier |
|---|---|---|---|---|
| Movable Summary end date | High | S | No | Free |
| Macro split chart | Medium | S | No | Free |
| Over/under goal on the chart | Medium | S | No | Free |
| Calendar of logged days | Medium | M | No | Free |
| Top foods | Medium | M | No | Free |

- [ ] **Movable Summary end date.** Summary always ends today. Add ‹ › arrows that step by one range (the previous week, the previous month), plus a "Today" button to return. `summary_math` already takes `endDate`
- [ ] **Macro split chart.** The share of calories from protein, carbs and fat (4 / 4 / 9 kcal per g) for the day on Home and for the range on Summary, as a ring or stacked bar
- [ ] **Over/under goal on the chart.** Color each Summary bar by whether it is within, over or under the goal (with a tolerance such as ±10%), and show "n days on target" under the averages
- [ ] **Calendar of logged days.** A month grid, reachable by tapping the Home date, with a dot on logged days and tinted days over or under goal. Tapping a day jumps Home there. It doubles as a "go to date" picker
- [ ] **Top foods.** For the Summary range, the foods and meals that contributed most to the primary metric, by total and by how often they were logged. One `GROUP BY` over `food_log_entries` (meal breakdown rows counted per food)

### Goals

| Idea | Value | Effort | Schema change | Tier |
|---|---|---|---|---|
| Goals per weekday | Medium | M | No (preferences) | Free |
| Macro goals as percentages | Medium | S | No (preferences) | Free |
| TDEE helper | Medium | M | No (preferences) | Free |
| Adaptive goals | Medium | L | No | Free (after M15) |

- [ ] **Goals per weekday.** Different goals on training and rest days, or per weekday. Stored as optional `goal_<metric>_<weekday>` preferences that fall back to `goal_<metric>`. Home and the Summary goal line read the goal for the day shown (Summary uses the average goal across the range)
- [ ] **Macro goals as percentages.** Set protein, carbs and fat as a percentage of the calorie goal (e.g. 30 / 40 / 30); the gram goals are derived and update when the calorie goal changes
- [ ] **TDEE helper.** An optional step in onboarding and Settings: age, sex, height, weight and activity level give an estimated daily energy use (Mifflin-St Jeor) and a suggested calorie goal for maintain, lose or gain. The inputs stay on the device; state that on the screen
- [ ] **Adaptive goals.** After M15, compare the weight trend with average intake over the last few weeks to estimate real energy use, and suggest a goal change. Suggest only; never change the goal without the user confirming it

### Data and safety

| Idea | Value | Effort | Schema change | Tier |
|---|---|---|---|---|
| Automatic backups | High | M | No | Free |
| Undo last action | Medium | M | No | Free |
| CSV export of the log | Medium | S | No | See Open Questions |

- [ ] **Automatic backups.** Write a backup to the app's Documents folder after the day's first entry, at most once a week, keeping the newest few. Turning on `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` makes that folder visible in the Files app, and Restore can list those files without the file picker. Free, by Principle 1 of the monetization plan
- [ ] **Undo last action.** Generalizes the swipe-to-delete undo above to edits, copy day and imports: keep the last change's inverse in memory and offer Undo for a few seconds
- [ ] **CSV export of the log.** One row per entry (date, name, type, macros), readable in a spreadsheet. Overlaps with the Pro "shareable reports"; see Open Questions

### Polish and accessibility

| Idea | Value | Effort | Schema change | Tier |
|---|---|---|---|---|
| Haptics | Low | S | No | Free |
| VoiceOver labels | Medium | S | No | Free |
| Comma decimals | Medium | S | No | Free |
| Water tracking | Medium | M | Yes (new table) | Free |
| iPad and landscape layout | Low–Med | M | No | Free |

- [ ] **Haptics.** A light tap when an entry is logged or a plan is confirmed, and a warning tap on delete
- [ ] **VoiceOver labels.** `Semantics` on the progress bars ("1,450 of 2,000 calories, 550 left") and a text summary on each chart, since VoiceOver can't read an `fl_chart` bar. Add a semantics check to the 2x text / dark mode test
- [ ] **Comma decimals.** `parseNumber` uses `double.tryParse`, so "1,5" typed on a European keyboard is rejected. Accept a comma as the decimal separator, and format numbers with the device locale
- [ ] **Water tracking.** A row on Home with +/- buttons in glasses or ml, an optional daily goal, and a line on Summary. A new `water_log` table (`log_date`, `amount_ml`); include it in the backup format
- [ ] **iPad and landscape layout.** On wide screens, show the catalog or the day's log beside Home instead of a full-screen push, and give the Summary chart the extra width

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
7. **CSV export (backlog).** A raw CSV of your own log is data portability, which argues for free (Principle 1). The Pro "shareable reports" already list "a PDF or CSV of a date range". *Proposed:* the plain CSV is free, and Pro keeps the formatted PDF report.
8. **Siri Shortcuts (backlog).** It connects the app to something else, which the monetization rule of thumb puts in Pro, but it is also a faster way to log, which Principle 3 keeps free. Decide before building it.
