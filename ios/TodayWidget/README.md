# Today widget (iOS)

A small WidgetKit widget showing the calories (or primary metric) left today, with a progress ring. The Flutter app publishes the figures with `home_widget` into the shared App Group `group.com.nutriton.app`; the widget only reads them. See `lib/core/widget_snapshot.dart` for the keys.

These sources are **not wired into `ios/Runner.xcodeproj`**. The widget target has to be added in Xcode on a Mac. Nothing here has been compiled or run.

## Files

| File | Purpose |
|---|---|
| `TodayWidget.swift` | Timeline provider, view and widget definition |
| `Info.plist` | Widget extension plist (`com.apple.widgetkit-extension`) |
| `TodayWidget.entitlements` | App Group for the widget |
| `../Runner/Runner.entitlements` | App Group for the app |

## Steps

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File > New > Target > Widget Extension.** Product name `TodayWidget`, language Swift. Untick "Include Live Activity", "Include Control" and "Include Configuration App Intent". Choose "Activate" if asked about a scheme. Its bundle id becomes `com.nutriton.app.TodayWidget`.
3. Set the new target's **iOS Deployment Target** to 14.0 or later (the app's is 14.0).
4. In the new `TodayWidget` group, delete the generated Swift files and `Info.plist` (move to trash). Add the files from this folder to the `TodayWidget` target instead: right-click the group, **Add Files to "Runner"...**, pick `TodayWidget.swift` and `Info.plist`, tick only the `TodayWidget` target. If the generated plist is kept instead, make sure it has the `NSExtension` entry from `Info.plist` here.
5. Target `TodayWidget` > **Build Settings**: set `INFOPLIST_FILE` to `TodayWidget/Info.plist` and `CODE_SIGN_ENTITLEMENTS` to `TodayWidget/TodayWidget.entitlements`.
6. Target `Runner` > **Build Settings**: set `CODE_SIGN_ENTITLEMENTS` to `Runner/Runner.entitlements`.
7. Target `Runner` > **Signing & Capabilities** > **+ Capability** > **App Groups**. Tick `group.com.nutriton.app` (add it with **+** if missing). Repeat for target `TodayWidget`. Xcode may rewrite the entitlements files; the content should stay the same.
8. Select the same Team (`D8U7624NXN`) for both targets.
9. Target `Runner` > **Build Phases**: confirm "Embed Foundation Extensions" (or "Embed App Extensions") lists `TodayWidget.appex`, and that it sits above "Thin Binary" if Xcode reports a dependency cycle.
10. Run `cd ios && pod install` (adds `home_widget` to `Podfile.lock`), then build and run the Runner scheme on a device. Add the widget from the home screen's widget gallery ("Today").

## Free Apple team warning

The team is a free personal team. Free teams may not be able to provision the **App Groups** capability, and then Xcode shows "Personal development teams do not support the App Groups capability" or a provisioning-profile error. If so:

- The app itself still runs if the capability is removed from `Runner` (untested: the app should not crash), but the widget cannot read the app's data and will show an empty day.
- A paid Apple Developer Program membership is the only fix. Until then, leave the target out of the build (remove it from Runner's Embed phase) rather than ship a broken widget.
- Free-team builds also expire after 7 days.

This has not been verified against the real team.

## How refreshing works

- The app calls `updateWidget` whenever today's totals, the primary metric or its goal change, and at the day rollover while it is running.
- The timeline has two entries: now, and midnight. At midnight the widget shows an empty day (the whole goal left) if the app has not published for the new date, and the timeline reloads then (`.after(midnight)`).
- iOS budgets how often a widget may reload, so a redraw can lag the app by a short while.
