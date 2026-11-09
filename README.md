# Logbite

A Flutter app for tracking calories and macronutrients day by day. Data stays on the device (SQLite via drift).

See [`PRODUCT.md`](./PRODUCT.md) for what the app does, its free and Pro rules and what's built, [`ROADMAP.md`](./ROADMAP.md) for open work sorted by size and blockers, and [`DATA_MODEL.md`](./DATA_MODEL.md) for the schema.

## Setup

Requires the Flutter SDK (stable channel).

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Run the `build_runner` step after changing any file under `lib/data/database/` (tables or DAOs). It generates the `*.g.dart` files that drift needs. The generated files are committed.

## Checks

```sh
flutter analyze
flutter test
```

## Android

Requires JDK 17 and the Android SDK (API 36, build-tools 36, NDK 28.2.13676358; Gradle fetches anything missing). The minimum supported version is Android 8.0 (API 26).

```sh
flutter build apk --release        # to install on a device
flutter build appbundle --release  # to upload to Google Play
```

Without `android/key.properties`, release builds use the debug key, which Google Play rejects. To sign for Play, create a keystore once and keep it and its passwords backed up outside the repo; both are git-ignored:

```sh
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties`. `storeFile` is relative to `android/app`:

```properties
storeFile=upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

## Layout

```
lib/
├── core/          pure Dart: nutrition math, date keys, summary math, validation
├── data/
│   ├── database/  drift tables, DAOs, AppDatabase
│   ├── preferences/  shared_preferences wrapper
│   └── repositories/
├── providers/     Riverpod providers
├── views/         Cupertino screens (onboarding, home, add food, catalog, meals, summary, settings)
└── app.dart / main.dart
```

## App icon

The icon source is `assets/icon/app_icon.png` (1024x1024, full-bleed) plus `assets/icon/app_icon_foreground.png` for the Android adaptive icon. To regenerate the platform icons after changing them:

```
dart run flutter_launcher_icons
```

If the iOS Xcode project is modified by the tool (it can rewrite `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`), revert that one line to `YES`.
