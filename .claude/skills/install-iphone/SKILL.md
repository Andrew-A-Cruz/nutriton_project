---
name: install-iphone
description: Build a signed release of Nutriton and install it on the user's paired iPhone, over USB or Wi-Fi. Use when asked to build, install, deploy or run the app on the iPhone or a physical iOS device.
---

# Install on iPhone

Run the script from the repo root:

```sh
.claude/skills/install-iphone/install.sh            # first paired iPhone
.claude/skills/install-iphone/install.sh <device-id> # a specific one
```

It finds a physical iOS device with `flutter devices`, runs `flutter build ios --release`, installs `build/ios/iphoneos/Runner.app` with `xcrun devicectl device install app`, and launches `com.nutriton.app`. A full build takes about a minute. Run it with a timeout of at least 10 minutes.

**Do not use `flutter install` or `flutter run`.** `flutter install` uninstalls the old app first, which deletes the user's logged data (the drift database lives in the app container). `devicectl` updates the app in place and keeps the data.

## Requirements

- The iPhone must already be paired with this Mac and have Developer Mode on. After that, no cable is needed. The phone has to be unlocked and on the same Wi-Fi network as the Mac.
- Signing is automatic with team `D8U7624NXN` (set in `ios/Runner.xcodeproj`). The minimum iOS version is 15.0, because the `health` plugin requires it.

## When it fails

- **No device found, or "The device disconnected" / CoreDeviceError 3003 or 4000:** the Wi-Fi link dropped, usually because the phone locked. Ask the user to unlock the phone, then retry. If retries keep failing, ask them to plug it in.
- **Installed but not launched:** the phone was locked. The install worked, so tell the user to open the app.
- **"Untrusted Developer" on the phone, or launch fails with "invalid code signature, inadequate entitlements or its profile has not been explicitly trusted":** the install worked, but the phone does not trust the signing profile yet. The user goes to Settings > General > VPN & Device Management and trusts the developer profile.
- **App stops opening after 7 days:** builds signed by a free personal team expire. Run the script again.
- **Provisioning errors about HealthKit or App Groups:** a free team may not support these capabilities. See `ios/HEALTHKIT.md` and `ios/TodayWidget/README.md`.
- **CocoaPods error that a plugin "requires a higher minimum iOS deployment version":** raise `platform :ios` in `ios/Podfile` and `IPHONEOS_DEPLOYMENT_TARGET` in `ios/Runner.xcodeproj/project.pbxproj` to the version the error asks for.

After installing, report what happened: built, installed, and whether it launched.
