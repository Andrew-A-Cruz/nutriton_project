# Logbite — Code Review

Reviewed on 2026-11-12 at commit `e3ed0c7` (`main`), schema v13, Flutter 3.41.5. Written for the agent who fixes these. It assumes you have not seen the conversations that led here.

## How to use this file

- Each finding has an ID, a severity, where it is, what is wrong, why it matters, how to fix it and how to check the fix. Fix them in ID order within a severity unless a finding says it depends on another.
- **Read [`PRODUCT.md`](./PRODUCT.md) first**, in particular Technical Decisions and Conventions. The layering rule is: views → Riverpod providers → repositories → drift DAOs; `lib/core/` is pure Dart with no Flutter or drift imports.
- One finding per commit, on a branch. Commit and push only when the user asks.
- After every change: `dart format lib test`, `flutter analyze` (must report no issues) and `flutter test` (must pass).
- **Run tests with a time limit** until T1 is fixed, because a failing widget test can hang the run: `perl -e 'alarm 420; exec @ARGV' flutter test`.
- Line numbers are from the reviewed commit. If they have moved, search for the quoted symbol.
- Do not "fix" the items under [Checked and found fine](#checked-and-found-fine) or [Deliberate, do not change](#deliberate-do-not-change).
- When a finding is fixed, delete it from this file. Delete the file when it is empty.

## What was and was not reviewed

Read in full: the data layer (`lib/data/`), providers, `lib/core/` files touched by storage, backup, health, notifications and purchases, the native code (`AppDelegate.swift`, `MainActivity.kt`), platform config (`Info.plist`, entitlements, `AndroidManifest.xml`, Gradle files), CI and the test support code. Read in part: the views (the screens added in November 2026 and the ones involved in a finding). Not reviewed: `ios/TodayWidget/TodayWidget.swift`, the PDF report renderer, and the generated drift code.

The review is from reading code plus the test suite, two emulator sessions and simulator builds. Nothing here comes from a real iPhone. Each finding says whether it was **confirmed** (seen in code or observed running) or is **likely** (inferred, not reproduced).

## Summary

| ID | Severity | Finding |
|---|---|---|
| [S1](#s1--shared-backups-and-reports-are-left-in-the-temp-folder) | Medium | Shared backups and reports are left in the temp folder |
| [S2](#s2--pro_unlocked-could-ship-in-a-store-build) | Medium | `PRO_UNLOCKED` could ship in a store build |
| [S3](#s3--android-backup-behaviour-is-implicit) | Low | Android backup behaviour is implicit |
| [S4](#s4--ci-workflow-has-default-token-permissions-and-unpinned-actions) | Low | CI workflow has default token permissions and unpinned actions |
| [S5](#s5--no-dependency-update-or-audit-process) | Low | No dependency update or audit process |
| [S6](#s6--the-barcode-is-not-validated-where-the-url-is-built) | Low | The barcode is not validated where the URL is built |
| [S7](#s7--a-backup-file-of-any-size-is-read-into-memory) | Low | A backup file of any size is read into memory |
| [R1](#r1--background-failures-are-silently-discarded) | Medium | Background failures are silently discarded |
| [R2](#r2--backup-import-and-export-failures-are-not-logged-and-the-message-can-mislead) | Medium | Backup failures are not logged, and the message can mislead |
| [R3](#r3--settings-save-can-drop-a-setting-that-a-section-saved-on-its-own) | Medium | Settings Save can drop a setting that a section saved on its own |
| [R4](#r4--the-water-goal-writes-every-preference-on-every-keystroke) | Low | The water goal writes every preference on every keystroke |
| [R5](#r5--a-restore-is-not-atomic-across-the-database-and-preferences) | Low | A restore is not atomic across the database and preferences |
| [R6](#r6--log-writes-do-not-validate-the-date-key) | Low | Log writes do not validate the date key |
| [R7](#r7--a-failed-time-zone-lookup-silently-moves-reminders-to-utc) | Low | A failed time zone lookup silently moves reminders to UTC |
| [R8](#r8--the-error-log-can-lose-an-entry-when-two-errors-arrive-together) | Low | The error log can lose an entry |
| [R9](#r9--starter-foods-are-matched-to-catalog-foods-by-name) | Low | Starter foods are matched to catalog foods by name |
| [R10](#r10--the-ipad-add-food-pane-resets-on-any-new-entry) | Low | The iPad Add Food pane resets on any new entry |
| [A1](#a1--a-provider-imports-from-the-views-layer) | Low | A provider imports from the views layer |
| [A2](#a2--the-clock-is-read-directly-in-views-and-repositories) | Medium | The clock is read directly in views and repositories |
| [A3](#a3--the-wide-layout-threshold-is-a-mutable-global) | Low | The wide-layout threshold is a mutable global |
| [A4](#a4--a-timer-is-started-from-build) | Low | A timer is started from `build` |
| [P1](#p1--starter-foods-are-parsed-and-searched-on-the-ui-thread) | Low | Starter foods are parsed and searched on the UI thread |
| [P2](#p2--android-decodes-the-label-photo-on-the-main-thread) | Low | Android decodes the label photo on the main thread |
| [P3](#p3--recent-foods-run-one-query-per-row) | Low | Recent foods run one query per row |
| [T1](#t1--a-failing-widget-test-can-hang-the-whole-test-run) | High | A failing widget test can hang the whole test run |
| [T2](#t2--one-unexplained-intermittent-test-failure) | Medium | One unexplained intermittent test failure |
| [T3](#t3--ci-does-not-check-formatting-or-build-the-apps) | Medium | CI does not check formatting or build the apps |
| [T4](#t4--native-code-and-the-build-scripts-have-no-automated-check) | Low | Native code and the build scripts have no automated check |
| [D1](#d1--data_modelmd-has-stale-sections) | Low | `DATA_MODEL.md` has stale sections |
| [D2](#d2--the-app-version-has-never-been-raised) | Low | The app version has never been raised |
| [D3](#d3--gradle-asks-for-8-gb-of-heap) | Low | Gradle asks for 8 GB of heap |

Severity: **High** blocks reliable work or risks data. **Medium** should be fixed before a store release. **Low** is hygiene.

There are no High security findings. The app has no server, no account and no secrets in the repo, which removes most of the usual risks.

---

## Security and privacy

### S1 — Shared backups and reports are left in the temp folder

**Medium · confirmed**

**Where:** `lib/data/backup/backup_file_io.dart:56` (`_share`), `lib/data/report/report_sharer.dart:44`.

**Problem:** To share a backup or a PDF report, the app writes it to the temporary directory and hands the path to the share sheet. The file is never deleted. A backup is the user's whole log, body weight and settings in plain JSON.

**Why it matters:** The privacy policy says data stays where the user puts it. A stale copy in the app's temp folder is not what they chose, and the OS clears that folder only when it wants to.

**Fix:**
1. In both functions, wrap the share call in `try { ... } finally { ... }` and delete the file in `finally`. Catch `FileSystemException` around the delete and ignore it (the file may already be gone).
2. `SharePlus.instance.share` returns after the sheet is dismissed, so deleting afterwards is safe.
3. `PlatformLabelScanner.scan` in `lib/data/label/label_scanner.dart` already does exactly this for the label photo; copy its `try`/`finally`.
4. Write into a subfolder (`<temp>/share/`) and, at the start of each share, delete anything already in it, so a file left by a crash is cleared next time.

**Check:** Add a unit test that calls a small extracted helper (`Future<T> withTempFile(...)`) with a callback that throws, and asserts the file no longer exists. The plugin calls themselves are not testable; keep the helper pure `dart:io` so it is.

### S2 — `PRO_UNLOCKED` could ship in a store build

**Medium · confirmed**

**Where:** `lib/main.dart:100-103`, `.claude/skills/install-iphone/install.sh` (passes `--dart-define=PRO_UNLOCKED=true` by default).

**Problem:** Any build made with `--dart-define=PRO_UNLOCKED=true` gives everyone Pro for free. The install script sets it by default, which is right for a personal device build. Nothing stops the same flag reaching an App Store or Play Store archive.

**Why it matters:** One wrong archive command gives the paid tier away, and it cannot be recalled from phones that installed it.

**Fix:** Make it impossible by construction, not by care.
1. Add a second define that only store builds set, for example `--dart-define=STORE_BUILD=true`, and in `main.dart` compute `const unlocked = bool.fromEnvironment('PRO_UNLOCKED') && !bool.fromEnvironment('STORE_BUILD');`.
2. Add a `tool/build_store_ios.sh` (and later an Android one) that is the only documented way to make a store build. It must pass `STORE_BUILD=true`, must not pass `PRO_UNLOCKED`, and must exit non-zero if the `PRO_UNLOCKED` environment variable is set to `true`.
3. Document it in `README.md` and in the "Sell Pro on iOS" entry of `ROADMAP.md`.

**Check:** Unit-test the small function that combines the two flags (extract it so it takes two bools). Run the store script with `PRO_UNLOCKED=true` in the environment and confirm it refuses.

### S3 — Android backup behaviour is implicit

**Low · confirmed**

**Where:** `android/app/src/main/AndroidManifest.xml:11` (`<application>` has no `android:allowBackup`, `android:dataExtractionRules` or `android:fullBackupContent`).

**Problem:** `PRODUCT.md` says Android Auto Backup stays on deliberately. The manifest relies on the default instead of saying so, and Android 12+ expects `dataExtractionRules`. Everything is backed up, including caches and the error log.

**Fix:**
1. Add `android:allowBackup="true"` explicitly.
2. Add `res/xml/data_extraction_rules.xml` (Android 12+) and `res/xml/backup_rules.xml` (older), and reference them with `android:dataExtractionRules` and `android:fullBackupContent`. Include the database (`getApplicationSupportDirectory()` maps to the app's `files` dir; check the actual path on a device with `adb shell run-as`) and shared preferences. Exclude the cache directory.
3. Follow the Android documentation for the two file formats; they differ.

**Check:** `flutter build apk --release` succeeds. On the emulator, `adb shell bmgr backupnow com.andrewcruz.logbite` then reinstall and `bmgr restore` (see Android's "Test backup and restore" guide) brings the log back.

### S4 — CI workflow has default token permissions and unpinned actions

**Low · confirmed**

**Where:** `.github/workflows/checks.yml:12`, `:14`.

**Problem:** The workflow does not declare `permissions`, so it gets the repository's default token scope. The two actions are referenced by tag (`@v4`, `@v2`), which the action's owner can move.

**Fix:**
1. Add at the top level of the workflow:
   ```yaml
   permissions:
     contents: read
   ```
2. Pin each action to a full commit SHA with the version in a comment, for example `uses: actions/checkout@<40-character sha> # v4.x.y`. Look the SHAs up on each action's releases page; do not guess them.

**Check:** Push a branch and confirm the Checks workflow still passes.

### S5 — No dependency update or audit process

**Low · confirmed**

**Where:** repository root (no `.github/dependabot.yml`). `flutter pub get` reports 84 packages with newer versions.

**Problem:** Nothing prompts updates to packages or GitHub Actions, including the ones that touch purchases, health data and the camera.

**Fix:** Add `.github/dependabot.yml` with two entries, `package-ecosystem: "pub"` (directory `/`) and `package-ecosystem: "github-actions"` (directory `/`), both weekly, with a small `open-pull-requests-limit`. Do not bulk-upgrade packages as part of this finding; `pubspec.yaml` pins `image` below 4.11 for a documented reason.

**Check:** After merging, Dependabot opens its first pull requests within a day.

### S6 — The barcode is not validated where the URL is built

**Low · confirmed**

**Where:** `lib/data/remote/open_food_facts_client.dart:73` (`lookupBarcode`).

**Problem:** The barcode is interpolated into the request path. The only caller, `FoodLookupRepository.findByBarcode`, validates it as 8–14 digits first, so there is no bug today. The client itself trusts its argument, so a future caller could send arbitrary path text.

**Fix:** At the top of `lookupBarcode`, throw `ArgumentError` unless the barcode matches `^\d{8,14}$`. Move the regular expression to one shared place so the repository and the client use the same one.

**Check:** A unit test that `lookupBarcode('../x')` throws and makes no request (the `MockClient` handler must not be called).

### S7 — A backup file of any size is read into memory

**Low · confirmed**

**Where:** `lib/data/backup/backup_file_io.dart:72-79` (`pick`).

**Problem:** The picker accepts any file, and the whole file is read and decoded before anything checks it. Picking a multi-gigabyte file by mistake would exhaust memory.

**Fix:** Before reading, check the picked file's size and return a clear error above a generous cap (50 MB; a real backup is well under 5 MB). `pick` currently returns `String?`; the simplest route is to throw a `BackupException` with the message "That file is too large to be a Logbite backup." and let `_restoreFrom` in `lib/views/settings/backup_section.dart` show it, which it already does for `BackupException`.

**Check:** A test with a fake `BackupFileIo` that throws that exception, asserting the message shows and no data changed. Model it on the existing tests in `test/views/backup_view_test.dart`.

---

## Reliability and correctness

### R1 — Background failures are silently discarded

**Medium · confirmed**

**Where:** `.catchError((Object _) {})` in `lib/providers/reminder_providers.dart:43`, `lib/providers/health_providers.dart:58`, `:69`, `:85`, `lib/providers/widget_providers.dart:38`, `:58`, `lib/providers/review_providers.dart:28`, `lib/providers/entitlement_providers.dart:37`.

**Problem:** Reminders, Apple Health sync, the home screen widget, the review prompt and the purchase status check all run in the background, and each one throws its errors away. If Health access is revoked or a notification cannot be scheduled, nothing records it. The app already has an on-device error log (Settings > Error log) for exactly this, and the automatic backup uses it.

**Why it matters:** These are the features that have never run on a real phone. When one fails there, there will be no trace.

**Fix:**
1. Use `autoBackupPlanProvider` in `lib/providers/backup_providers.dart:81` as the model. It reads `errorLogProvider` and calls `errorLog.record(e, stack, context: '...')` in its `catchError`.
2. Replace each empty handler with one that records the error under a short context: "Reminders could not be scheduled", "Apple Health nutrition sync failed", "Apple Health weight import failed", "Widget update failed", "Review prompt failed", "Purchase status check failed".
3. Keep swallowing after recording: these must still never crash the app.
4. Leave the three `_tail = run.catchError(...)` lines in `ReminderSync`, `HealthSync` and `WidgetSync` alone. They only stop one failed run blocking the next; the caller still receives the error.
5. A repeating failure would fill the 50-entry log. In `ErrorLog.record` (`lib/data/diagnostics/error_log.dart`), skip the write when the newest entry has the same context and message.

**Check:** Tests with the existing fakes in `test/support/` (for example make `FakeHealthService` throw) asserting one entry appears in `ErrorLog.entries` and the app keeps running; and a test that the same failure twice records once.

### R2 — Backup import and export failures are not logged, and the message can mislead

**Medium · confirmed**

**Where:** `lib/data/repositories/backup_repository.dart:92-97`, `lib/views/settings/backup_section.dart:59` and `:141`.

**Problem:** `BackupRepository.restore` catches every `Exception` from the transaction and reports "The backup contains data that breaks the app's rules". That is right for a constraint failure and wrong for anything else, such as a full disk. The view's own `on Exception` handlers show a generic message. In all three places the original error is dropped, so there is nothing to diagnose from.

**Why it matters:** Backup is the feature that protects the user's data. It is the worst place to lose the reason for a failure.

**Fix:**
1. In `restore`, catch only what a rule violation produces. drift surfaces SQLite constraint failures as `SqliteException` and its own validation as `InvalidDataException`. Import `SqliteException` from `package:drift/native.dart`, which re-exports it; `sqlite3` is not a direct dependency, so do not import that package. Catch those two and throw the existing `BackupException`. Let anything else propagate.
2. In `backup_section.dart`, change the two `on Exception` blocks to `catch (e, stack)` and build the message with `reportError(ref, e, stack, 'Could not read the backup file')` (and `'Could not save the backup'`), from `lib/views/common/error_feedback.dart`. That records the error and returns the text to show. Keep the `on BackupException` clause before it, unchanged.

**Check:** Existing backup tests still pass (several assert the "breaks the app's rules" message for bad rows; they must keep passing). Add a view test where the fake file IO throws a plain `Exception` and assert an entry lands in the error log.

### R3 — Settings Save can drop a setting that a section saved on its own

**Medium · confirmed (design weakness; no current bug)**

**Where:** `lib/views/settings/settings_view.dart:46-60`, `lib/views/onboarding/preferences_form.dart` (`_submit` builds a new `UserSettings`).

**Problem:** The Settings form builds a brand-new `UserSettings` from its own fields when Save is tapped. Several sections (reminders, Apple Health, weekday goals, water, fasting) save immediately on their own. To stop Save overwriting them with defaults, `SettingsView.onSubmit` copies each of those fields back by hand with `copyWith`. Every new save-as-you-go setting must be added to that list, and nothing fails if it is forgotten: the setting just silently resets when the user taps Save. This was caught by hand twice in November 2026 (water and fasting).

**Fix:** Invert it so forgetting is impossible.
1. In `PreferencesForm._submit`, stop constructing `UserSettings(...)` from scratch. Start from the **current** settings instead and change only the fields the form owns: primary metric, tracked metrics, goals, display unit, body weight unit, macro goal percents.
2. `UserSettings.copyWith` cannot currently clear `macroGoalPercents` (it always passes the existing value through). Add a way to set it to null, for example a `clearMacroGoalPercents` flag or a dedicated `withFormFields({...})` method that takes all six form-owned fields as required parameters and copies everything else.
3. The form is a plain `StatefulWidget` that receives `initial`. Give it the current settings at submit time: either pass a `ValueGetter<UserSettings> current` from both callers, or make the callback signature `onSubmit(UserSettings Function(UserSettings current) apply)`. Both callers (`SettingsView` and `_SetupView` in `lib/views/onboarding/onboarding_view.dart`) then apply it to `ref.read(preferencesProvider)`.
4. Delete the hand-written `copyWith` list in `SettingsView.onSubmit`.

**Check:** A test that sets every save-as-you-go field to a non-default value (use `mockPreferences` with all of them), opens Settings, taps Save without touching anything, and asserts every one is unchanged in `SharedPreferences`. `test/views/water_test.dart` ("saving the form keeps the water settings") shows the shape. This single test then guards every future field.

### R4 — The water goal writes every preference on every keystroke

**Low · confirmed**

**Where:** `lib/views/settings/water_section.dart:48` (`_goalChanged`), `lib/data/preferences/user_preferences.dart:272` (`write`).

**Problem:** Each character typed in the water goal field calls `PreferencesNotifier.save`, and `UserPreferences.write` rewrites every key (about 80 sequential awaited writes). Typing "2000" does that four times, and the intermediate values ("2", "20", "200") are briefly the saved goal.

**Fix:** Save when editing ends, not on each change. In `WaterSection`, keep validating on change (so the error shows as the user types) but call `_save` from `onSubmitted` and when the field loses focus (a `FocusNode` listener). `formRow` in `lib/views/common/form_widgets.dart` does not expose those; add optional `focusNode` and `onSubmitted` parameters and pass them through to the `CupertinoTextField`. Also save in `dispose` if the text changed and is valid, so leaving Settings without dismissing the keyboard keeps the value.

**Check:** Update `test/views/water_test.dart`: after `enterText`, send `tester.testTextInput.receiveAction(TextInputAction.done)` before asserting the stored goal. Add an assertion that the goal is not saved mid-typing.

### R5 — A restore is not atomic across the database and preferences

**Low · confirmed**

**Where:** `lib/data/repositories/backup_repository.dart:98` (`await _prefs.write(data.settings)` runs after the transaction commits).

**Problem:** The rows are replaced in one transaction, then the preferences are written key by key. If the app is killed between the two, the database is the backup's and the settings are the old ones. The method's doc comment promises that a failure "leaves nothing changed, preferences included", which is true for a failure inside the transaction and false for one after it.

**Fix:** This cannot be made truly atomic across two stores. Make it recoverable and say so.
1. Before the transaction, write a marker preference holding the settings to apply (encode them with the same `_encodeSettings` the codec uses, as a JSON string under a key such as `pending_restore_settings`).
2. After `_prefs.write` succeeds, remove the marker.
3. At launch (in `main`, after `SharedPreferences.getInstance()`), if the marker exists, decode and apply it, then remove it.
4. Correct the doc comment to describe this.

**Check:** A repository test that writes the marker by hand, runs the launch step, and asserts the settings were applied and the marker removed.

### R6 — Log writes do not validate the date key

**Low · confirmed**

**Where:** `lib/data/repositories/log_repository.dart:152` (`logFood`), `logMeal`, `logAdhoc`, `copyDay`; also `WaterRepository.add` and `BodyWeightRepository.setWeight`.

**Problem:** `moveEntry` and `duplicateEntry` call `dateFromKey(date)` to reject a malformed day key. The other writers store whatever string they are given. Every current caller passes a key built by `dateKey`, so nothing is wrong today, but one bad caller would write rows that no screen can ever show.

**Fix:** Call `dateFromKey(logDate)` at the top of each writer (it throws `FormatException` for a malformed or impossible date; see `lib/core/date_key.dart`). For `copyDay`, validate both dates.

**Check:** One test per repository that a key such as `'2026-13-40'` or `'today'` throws and writes nothing.

### R7 — A failed time zone lookup silently moves reminders to UTC

**Low · confirmed**

**Where:** `lib/data/notifications/local_notification_scheduler.dart:28-33`.

**Problem:** If `FlutterTimezone.getLocalTimezone()` fails or returns a name the `timezone` package does not know, the code keeps UTC. A 9:00 reminder then fires at 9:00 UTC, hours off, with nothing recorded.

**Fix:**
1. Give `LocalNotificationScheduler` an optional `void Function(Object error, StackTrace stack)? onError` constructor parameter and call it in that `catch`. In `main.dart`, pass a closure that calls `errorLog.record(..., context: 'Could not read the time zone')`. (`errorLog` already exists in `main`.)
2. Fall back better than UTC: when the lookup fails, build a fixed-offset location from `DateTime.now().timeZoneOffset` so reminders fire at the right local time until the next clock change. The `timezone` package has no direct "fixed offset" helper; the simplest correct approach is to schedule using `tz.TZDateTime.from(when, tz.UTC)` computed from the local `DateTime` (which already carries the device offset) on the fallback path.

**Check:** This class is not covered by tests (it needs a device). Extract the "which instant to schedule" decision into a pure function in `lib/core/reminder.dart` and test that function for both paths.

### R8 — The error log can lose an entry when two errors arrive together

**Low · confirmed**

**Where:** `lib/data/diagnostics/error_log.dart:87-91` (`record` reads the list, then awaits the write).

**Problem:** Two `record` calls that overlap both read the same list and each writes its own version; the second write discards the first entry.

**Fix:** Chain writes, as `HealthSync._queue` in `lib/data/health/health_sync.dart` does: keep a `Future<void> _tail` field and run each `record` body after the previous one finishes.

**Check:** A test that starts two `record` calls without awaiting the first, then awaits both, and finds two entries.

### R9 — Starter foods are matched to catalog foods by name

**Low · confirmed (documented limit)**

**Where:** `lib/data/repositories/catalog_repository.dart:76` (`adoptBundledFood`), `lib/views/catalog/food_list.dart:47`.

**Problem:** Picking a starter food reuses a catalog food with the same name and no brand. If the user renames their copy, the starter food appears in search again and picking it makes a second food. If the user had their own food with that exact name, theirs is silently used.

**Fix:** Fold this into M24, which adds `food_items.menu_item_id` for the same purpose (see [`M24_FAST_FOOD_MENUS_PLAN.md`](./M24_FAST_FOOD_MENUS_PLAN.md) section 1.2). When that column exists, give each starter food a stable id (for example `usda/<fdc_id>`; `tool/make_generic_foods.py` already reads `fdc_id` and would need to write it as a first column), store it on adoption, and match on it. Do not add a separate column for this before M24.

**Check:** Covered by M24's repository tests, extended with a "renamed copy is still reused" case.

### R10 — The iPad Add Food pane resets on any new entry

**Low · confirmed**

**Where:** `lib/views/home/home_view.dart:181-191` (`_AddFoodPaneState.build`).

**Problem:** On a wide screen, Add Food sits beside the day. To clear a form after it logs, the pane rebuilds from scratch whenever the day's entry count rises. That also fires when an entry appears for another reason: Undo after a delete, "log again", a planned meal confirmed on the left. A half-typed quick add in the pane is then lost.

**Fix:** Reset on the pane's own logs only. `AddFoodView` should tell its host when it logged something:
1. Add an optional `VoidCallback? onLogged` to `AddFoodView`, and pass it to `QuickAddForm` and `AdhocFoodForm`, which call it after a successful log (they currently call `Navigator.popUntil`, which does nothing at the pane's root).
2. In `_AddFoodPane`, pass `onLogged: () => setState(() => _generation++)` and delete the `ref.listen` block.
3. The catalog path (`LogFoodView`, `MealLogView`) already returns to the pane's root by popping, and the root has no typed state to clear, so it needs nothing.

**Check:** In `test/views/wide_layout_test.dart`, keep "a quick add clears its form" passing, and add a test that typing in quick add and then logging a different entry by repository call (as other tests do with `tester.runAsync`) leaves the typed text in place.

---

## Architecture and maintainability

### A1 — A provider imports from the views layer

**Low · confirmed**

**Where:** `lib/providers/widget_providers.dart:10` imports `../views/home/macro_summary.dart` for `totalsOf`.

**Problem:** The layering rule is views → providers → repositories. This is the only import that points the wrong way. It ties the home screen widget's data to a view file.

**Fix:** Move `totalsOf` (it sums a list of log entries into `Macros`) out of `macro_summary.dart`. It takes drift `FoodLogEntry` rows, so it cannot go in `lib/core/`; put it in `lib/data/repositories/log_repository.dart` as a top-level function or a static, and import it from both `macro_summary.dart` and `widget_providers.dart`. Search for other users with `grep -rn "totalsOf" lib test` and update their imports.

**Check:** `grep -rn "import '../views" lib/providers lib/data lib/core` prints nothing. Tests pass unchanged.

### A2 — The clock is read directly in views and repositories

**Medium · confirmed**

**Where:** `DateTime.now()` in `lib/views/add_food/log_food_view.dart:53`, `quick_add_form.dart:39`, `adhoc_food_form.dart:37`, `lib/views/meals/meal_log_view.dart:40`, `lib/views/home/day_log_list.dart:95`, `lib/views/settings/backup_section.dart:51` and `:151`, `lib/providers/backup_providers.dart:36`, and in the repositories for `createdAt` (`log_repository.dart`, `schedule_repository.dart:156` and `:176`, `catalog_repository.dart:60`, `body_weight_repository.dart`).

**Problem:** The app has a `clockProvider` (`lib/providers/today_providers.dart:9`) that tests override, and "today" comes from it. These places bypass it. A test that pins the clock still gets the real time for the default meal slot and for timestamps, so behaviour near a slot boundary (10:30, 15:00, 20:00) or midnight depends on when the suite runs. This is a plausible cause of T2.

**Fix:**
1. **Views and providers:** replace each `DateTime.now()` with `ref.read(clockProvider)()`. The four `MealSlot _slot = MealSlot.forTime(DateTime.now());` field initialisers run before `ref` is usable in a `ConsumerState`; change them to `late MealSlot _slot = MealSlot.forTime(ref.read(clockProvider)());`.
2. **Repositories:** give each repository an optional `DateTime Function() clock` constructor parameter defaulting to `DateTime.now`, store it, and use it for `createdAt`. In the provider that builds each repository (`lib/providers/infrastructure_providers.dart` and the per-feature provider files), pass `ref.watch(clockProvider)`. `FastingRepository` already takes the time as an argument from its callers; that style is also fine.
3. Leave `lib/core/date_key.dart:39` (`todayKey([DateTime? now])`) and `BackupCodec.encode`'s `exportedAt` default as they are; both already accept an injected time.

**Check:** `grep -rn "DateTime.now()" lib --include="*.dart" | grep -v "\.g\.dart"` shows only the two exceptions in step 3 and the repository default parameters. Add one widget test that overrides `clockProvider` to 09:00 and asserts the servings screen preselects Breakfast, and to 21:00 for Snack.

### A3 — The wide-layout threshold is a mutable global

**Low · confirmed**

**Where:** `lib/views/common/wide_layout.dart:10`, set from `test/flutter_test_config.dart`.

**Problem:** `wideLayoutMinWidth` is a top-level variable that tests change, because Flutter's 800-wide test window would otherwise switch every test to the iPad layout. Production code with a global that exists for tests is a smell, and a test that forgets to restore it leaks into the next file.

**Fix:** Make it a provider, which is how every other test seam in this app works.
1. Add `final wideLayoutMinWidthProvider = Provider<double>((ref) => 700);` (in `lib/providers/`).
2. Replace `isWideLayout(context)` with a function that takes the width threshold, and have the two callers (`HomeView`, `_ReportBody` in `summary_view.dart`; both are already `ConsumerWidget`s) read the provider.
3. In `test/support/test_app.dart`, make `testApp` and `testScreen` add `wideLayoutMinWidthProvider.overrideWithValue(double.infinity)` **before** the caller's `overrides`, so a test can override it back. Riverpod uses the last override for a provider, so check the order works; if not, add an optional `bool wide = false` parameter instead.
4. Delete the global, and delete `test/flutter_test_config.dart` if nothing else is in it. Tests that build their own `ProviderScope` without the helpers (search for `ProviderScope(` under `test/`) need the same override.

**Check:** Full suite passes; `test/views/wide_layout_test.dart` passes using the override instead of the global.

### A4 — A timer is started from `build`

**Low · confirmed**

**Where:** `lib/views/home/fasting_row.dart:64` (`_syncTick(fast != null)` inside `build`).

**Problem:** `build` should not have side effects. It works because `_syncTick` is idempotent, but it is fragile.

**Fix:** Move the timer control into a listener: in `build`, call `ref.listen(activeFastProvider, (_, next) => _syncTick(next.value != null));` and remove the direct call. `ref.listen` does not fire for the value already present when the widget first builds, so also call `_syncTick` once from a post-frame callback in `initState` (`WidgetsBinding.instance.addPostFrameCallback`) using `ref.read(activeFastProvider).value`. Stop the timer when the row is hidden (fasting switched off or another day shown).

**Check:** `test/views/fasting_test.dart` passes. No pending-timer error at the end of any test.

---

## Performance

### P1 — Starter foods are parsed and searched on the UI thread

**Low · confirmed (not measured on a slow phone)**

**Where:** `lib/providers/catalog_providers.dart:58` (`parseBundledFoods` on a 650 KB file), `lib/views/catalog/food_list.dart:47` (`searchBundledFoods` runs in `build`, lower-casing 6,158 names each time).

**Problem:** The first search parses the whole file on the main isolate, and every rebuild of the list (each keystroke, each database change) re-scans every name and allocates a lower-cased copy of each.

**Fix:**
1. Parse off the main isolate: `await compute(parseBundledFoods, source)` (from `package:flutter/foundation.dart`). `parseBundledFoods` is a top-level function and `BundledFood` holds only plain values, so it can cross isolates. `lib/core/` must stay free of Flutter imports, so make the `compute` call in the provider, not in `core`.
2. Store the lower-cased name once: add a `final String searchName` to `BundledFood`, set in the parser, and use it in `searchBundledFoods`.
3. Move the search out of `build` into a provider keyed by the query, for example `Provider.family<List<BundledFood>, String>`, so a rebuild with the same query reuses the result. Exclusion of names already in the catalog can stay in the widget, applied to the provider's result.

**Check:** Existing starter-food tests pass. In widget tests `compute` runs synchronously enough under `tester.runAsync`/`settle`; if a test starts timing out, keep the override of `genericFoodsSourceProvider` and confirm `settle` is called after typing.

### P2 — Android decodes the label photo on the main thread

**Low · confirmed**

**Where:** `android/app/src/main/kotlin/com/andrewcruz/logbite/MainActivity.kt:34` (`InputImage.fromFilePath`).

**Problem:** `fromFilePath` reads and decodes a photo up to 2400 px on the platform (UI) thread before recognition starts. The recognition itself is asynchronous. The decode can stall the UI for a moment on a slow phone.

**Fix:** Do the decode on a background executor and post the result back. Create one `java.util.concurrent.Executors.newSingleThreadExecutor()` as a field of `MainActivity`; inside the handler, `executor.execute { ... build InputImage and call recognizer.process(image) ... }`. ML Kit's listeners already run on the main thread by default, and `MethodChannel.Result` must be answered on the main thread, so keep `result.success`/`result.error` inside those listeners; for the `catch` path wrap the call in `runOnUiThread { }`. Shut the executor down in `onDestroy`.

**Check:** `flutter build apk --debug` compiles. On the "Logbite Test API 33" emulator, New Food > Choose a photo with a label image still fills the form (the image used in the last check is `us_cereal.png`, pushed to the emulator's Pictures folder).

### P3 — Recent foods run one query per row

**Low · confirmed**

**Where:** `lib/data/database/daos/log_dao.dart:158` (`asyncMap` calling `findById` for each id).

**Problem:** The recent and frequent lists fetch ids, then load each food or meal with its own query. The limit is 8, so it is at most 8 extra queries per emission, each time the log changes.

**Fix:** Collect the food ids and the meal ids from the rows, load each set with one `select(...)..where((t) => t.id.isIn(ids))`, put them in maps by id, and build the result in the original row order. Skip ids that are no longer found, as the code does now.

**Check:** `test/data/daos/recent_sources_dao_test.dart` passes unchanged.

---

## Tests and CI

### T1 — A failing widget test can hang the whole test run

**High · confirmed (seen three times); cause is likely, not proven**

**Where:** every `testWidgets` that ends with `await unmount(tester);` (about 300 calls), and the helper in `test/support/test_app.dart:90`.

**Problem:** When an `expect` fails in a widget test, the test body stops before its last line, `await unmount(tester)`. The app stays mounted with its drift streams and timers alive. In practice `flutter test` then prints the failure and sits on "loading <file>" until killed; it ran past ten minutes each time. One wrong finder turns a two-minute run into a hang with no summary.

**Why it matters:** It hides which tests failed, wastes CI minutes up to the 20-minute job limit, and is a trap for any agent working here.

**Fix:** Make cleanup run whether or not the test passes.
1. In `test/support/test_app.dart`, add a helper that pumps a widget and registers its own teardown:
   ```dart
   Future<void> pumpApp(WidgetTester tester, Widget app) async {
     addTearDown(() => unmount(tester));
     await tester.pumpWidget(app);
     await settle(tester);
   }
   ```
   `addTearDown` callbacks run after the test body even when it throws.
2. Make `unmount` safe to call twice (once from the teardown, once from old test bodies that still call it): keep a flag or simply let the second `pumpWidget(const SizedBox.shrink())` be a no-op, and confirm it does not throw.
3. Prove it before converting anything: write a deliberately failing test (`expect(find.text('nope'), findsOneWidget)`) in a scratch file using the new helper, run that file alone with the time limit, and confirm the run ends with a failure summary instead of hanging. If it still hangs, the cause is something else: find what keeps the process alive (candidates: the midnight `Timer` in `TodayNotifier`, `lib/providers/today_providers.dart:43`; the Undo banner timer; an open `AppDatabase`, though `tearDown` closes it) by removing them one at a time in the scratch test. Record what you find here.
4. Then convert tests file by file to the helper and drop their trailing `await unmount(tester);`. This is mechanical but large; do it in several commits, running the suite after each.
5. Delete the scratch test.

**Check:** With one test temporarily broken, the full `flutter test` run finishes and reports exactly that failure. Then restore the test.

### T2 — One unexplained intermittent test failure

**Medium · confirmed once, not reproduced**

**Where:** unknown. On 2026-11-11 at about 21:15 local time, a full `flutter test` run on a clean checkout of commit `c023868` reported one failure (`+928 -1`). The failing test's name was not captured. The next run on the same code passed, as did roughly a dozen full runs afterwards.

**Problem:** Some test depends on something that varies between runs.

**Fix:**
1. Do A2 first. Tests that mix a real clock with stored dates are the most likely cause.
2. Search the tests for other time dependence: `grep -rn "DateTime.now()\|todayKey()" test | wc -l` is large; look for tests that compute "today" in `setUp` and compare it with what the app computed later, and for anything using `MealSlot.forTime` without a fixed time.
3. To hunt it, run the suite in a loop with a different order each time and keep the logs: `for i in $(seq 1 20); do perl -e 'alarm 420; exec @ARGV' flutter test --test-randomize-ordering-seed=random > run_$i.log 2>&1 || echo "run $i failed"; done`. A failure prints the seed; rerun with that seed to reproduce.
4. If a specific test is found, fix it by pinning the clock (`clockProvider.overrideWithValue(() => DateTime(2026, 11, 11, 12))`), not by retrying.

**Check:** Twenty randomized runs in a row pass.

### T3 — CI does not check formatting or build the apps

**Medium · confirmed**

**Where:** `.github/workflows/checks.yml`.

**Problem:** CI runs code generation, `flutter analyze` and `flutter test`. It does not check formatting, and it never compiles the Android or iOS app, so a broken `MainActivity.kt`, Gradle dependency, `AppDelegate.swift` or Xcode setting passes CI. The native label-scan and app-icon code added in November 2026 is only checked by hand.

**Fix:**
1. Add a formatting step after `flutter pub get`: `dart format --output=none --set-exit-if-changed lib test`. Exclude generated files if they fail it (`*.g.dart`, `app_database.steps.dart`, `test/drift/app_database/generated/`); the simplest way is to pass the directories and files explicitly, or run `dart format` locally on everything first and see what changes.
2. Add an Android build job on `ubuntu-latest`: set up Java 17 (`actions/setup-java`, `distribution: temurin`, `java-version: 17`), then `flutter build apk --debug`. See D3 first: the 8 GB Gradle heap may not fit a hosted runner.
3. Add an iOS build job on `macos-latest`: `flutter build ios --simulator --debug --no-codesign`. macOS minutes cost more; run it on pull requests and on `main` only, not every push, if the user wants to limit usage. Ask the user.
4. Pin any new actions by SHA (S4).

**Check:** Open a pull request that breaks a Kotlin line on purpose and confirm the Android job fails; revert.

### T4 — Native code and the build scripts have no automated check

**Low · confirmed**

**Where:** `ios/Runner/AppDelegate.swift` (the `logbite/app_icon` and `logbite/label_ocr` channels), `MainActivity.kt`, `tool/make_alt_icons.py`, `tool/make_generic_foods.py`.

**Problem:** The Dart side of each channel is tested with fakes. The native side and the channel contract (method names, argument and result shapes) are not. The two Python tools that generate bundled assets have no test and are run by hand.

**Fix:**
1. Contract tests in Dart: for `MethodChannelAppIconService` and `PlatformLabelScanner`'s channel, use `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler` to assert the method names and arguments sent (`'get'`, `'set'` with a name or null; `'recognize'` with a path) and that a result shaped like the native code's (a list of maps with `text`, `x1`, `y1`, `x2`, `y2`, `height`) decodes. `PlatformLabelScanner` takes an `ImagePicker`; to test it without the plugin, split the channel call into its own small class or method that takes a path.
2. For the asset tools, the existing tests already guard the outputs (`test/core/bundled_foods_test.dart` reads the real `.tsv`; `test/core/appearance_test.dart` checks the icon sets exist). Add a line to the README saying those tests are the check after regenerating.
3. T3's build jobs cover "does the native code compile".

**Check:** The new contract tests pass, and fail if a method name is changed on the Dart side.

---

## Documentation and project hygiene

### D1 — `DATA_MODEL.md` has stale sections

**Low · confirmed**

**Where:** `DATA_MODEL.md:161` cites `test/data/migrations/schema_migration_test.dart`, which does not exist (the tests are in `test/drift/app_database/migration_test.dart`). The "Package Stack" table (line 345) lists 6 packages of about 25. The "Folder Structure" tree (line 358) predates most of `lib/` (no `backup/`, `health/`, `label/`, `store/`, `widget/`, and it lists 4 of the 20-odd files in `core/`).

**Fix:** Correct the test path. Replace the Folder Structure tree with a short description of each top-level folder under `lib/` (one line each) instead of a file list that will go stale again; `README.md`'s Layout section does this already, so link to it. Either complete the Package Stack table from `pubspec.yaml` with one line of purpose each, or delete it and point at `pubspec.yaml`.

**Check:** Every file path mentioned in `DATA_MODEL.md` exists: extract them and `ls` each.

### D2 — The app version has never been raised

**Low · confirmed**

**Where:** `pubspec.yaml:19` (`version: 1.0.0+1`).

**Problem:** Every build so far is 1.0.0 build 1. App Store Connect and Google Play reject an upload whose build number is not higher than the last, and the Pro grandfathering rule in `lib/core/pro.dart` (`grandfatherBeforeBuild`) compares build numbers.

**Fix:** No code change now. Add a "Releasing" section to `README.md`: raise the build number (the part after `+`) for every upload, and the version for every public release. If S2's store script is written, have it refuse to build when the build number equals the last git tag's.

**Check:** The README section exists and the roadmap's "Sell Pro on iOS" entry links to it.

### D3 — Gradle asks for 8 GB of heap

**Low · confirmed**

**Where:** `android/gradle.properties:1` (`-Xmx8G -XX:MaxMetaspaceSize=4G`).

**Problem:** This is Flutter's template default. A machine or CI runner with less free memory can fail or thrash. GitHub's standard Linux runners have 16 GB, so it should fit, but it leaves little room.

**Fix:** Lower to `-Xmx4G -XX:MaxMetaspaceSize=1G` and confirm `flutter build apk --release` still succeeds locally. Only do this together with T3's Android job, so CI proves it.

**Check:** A clean release build passes (`flutter clean` first).

---

## Checked and found fine

Do not spend time on these; each was looked at and is sound.

- **SQL injection:** every `customSelect`/`customUpdate` binds user values as variables. The string interpolation in `LogDao`'s recent-sources query (`log_dao.dart:140-150`) inserts only hard-coded table and column names. Catalog search escapes `%`, `_` and `\` (`FoodDao._contains`).
- **Secrets:** none in the repository. The RevenueCat key is a public SDK key passed at build time. `android/key.properties` and keystores are git-ignored (`android/.gitignore`).
- **Network:** two HTTPS endpoints on Open Food Facts, with a timeout, a status check and tolerant parsing. No cleartext traffic (Android blocks it by default at this target SDK; iOS App Transport Security is untouched).
- **Backup import as untrusted input:** the file is validated before anything is deleted, the replace runs in one transaction that rolls back on a bad row, database CHECK constraints apply, and a newer format is refused. Purchase status is not part of a backup.
- **Database integrity:** foreign keys are switched on at open; multi-step writes are in transactions; each schema step has a migration test.
- **Purchases:** the Pro entitlement comes from RevenueCat; the cached copy in preferences is replaced by the store's answer whenever the store is reachable. The trial is timed from the store's purchase date, not a local clock value.
- **Label scan privacy:** recognition is on the device on both platforms, and the photo is deleted after reading.
- **File names:** `DirectoryAutoBackupStore` rejects path separators in names, and writes through a temp file and rename.

## Deliberate, do not change

- **`nutriton` in identifiers** (iOS bundle id `com.andrewcruz.nutriton`, App Group, product ids `com.nutriton.app.*`, backup `app` field, Dart package name). The app was renamed to Logbite and these were kept on purpose; changing them breaks installs, purchases and old backups.
- **Backups are plain JSON, unencrypted.** They are the user's own export, and Principle 1 in `PRODUCT.md` puts portability first.
- **Android release builds fall back to the debug key** when `android/key.properties` is missing (`android/app/build.gradle.kts:63`), so `flutter run --release` works. Google Play rejects such a build, so it cannot ship by accident.
- **ML Kit models are bundled** in the Android app. Size versus offline use is decision D8 in the roadmap and is the user's to make.
- **English only, no localisation framework.** `PRODUCT.md` records that only the decimal separator follows the phone's region. Adding localisation is a feature for the roadmap, not a review fix.
- **Cupertino widgets on Android.** A recorded technical decision.
