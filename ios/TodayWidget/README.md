# Today widget (iOS)

A small WidgetKit widget showing the calories (or primary metric) left today, with a progress ring. The Flutter app publishes the figures with `home_widget` into the shared App Group `group.com.andrewcruz.nutriton`; the widget only reads them. See `lib/core/widget_snapshot.dart` for the keys.

The `TodayWidget` app extension target is in `ios/Runner.xcodeproj` (added in October 2026 with the `xcodeproj` Ruby gem), and `flutter build ios` builds, signs and embeds it. The widget is a Logbite Pro feature: without Pro the app publishes a locked snapshot (`locked: true`) and the widget shows a lock and "Unlock in Logbite" instead of the day's figures.

## Files

| File | Purpose |
|---|---|
| `TodayWidget.swift` | Timeline provider, view and widget definition |
| `Info.plist` | Widget extension plist (`com.apple.widgetkit-extension`); its version is the app's |
| `TodayWidget.entitlements` | App Group for the widget |
| `TodayWidget.xcconfig` | Base config: includes Flutter's `Generated.xcconfig` for `FLUTTER_BUILD_NAME` and `FLUTTER_BUILD_NUMBER`. Not a CocoaPods target |
| `../Runner/Runner.entitlements` | App Group (and HealthKit) for the app |

## How it is wired

- Target `TodayWidget`: bundle id `com.andrewcruz.nutriton.TodayWidget`, iOS 15.0, team `D8U7624NXN`, automatic signing, `INFOPLIST_FILE = TodayWidget/Info.plist`, `CODE_SIGN_ENTITLEMENTS = TodayWidget/TodayWidget.entitlements`. Debug, Profile and Release configurations, so Flutter's profile builds work too.
- Target `Runner`: depends on `TodayWidget`, and an "Embed Foundation Extensions" phase copies `TodayWidget.appex` into `PlugIns`. That phase sits before "Thin Binary" to avoid Flutter's known build cycle. `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`.
- The free personal team provisions the App Group (checked October 2026). Free-team builds still expire after 7 days.

After installing, add the widget from the home screen's widget gallery ("Today").

## How refreshing works

- The app calls `updateWidget` whenever today's totals, the primary metric or its goal change, and at the day rollover while it is running.
- The timeline has two entries: now, and midnight. At midnight the widget shows an empty day (the whole goal left) if the app has not published for the new date, and the timeline reloads then (`.after(midnight)`).
- iOS budgets how often a widget may reload, so a redraw can lag the app by a short while.
