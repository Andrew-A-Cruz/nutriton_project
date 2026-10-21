# Nutriton

A Flutter app for tracking calories and macronutrients day by day. Data stays on the device (SQLite via drift).

See [`GAME_PLAN.md`](./GAME_PLAN.md) for what the app does, [`DATA_MODEL.md`](./DATA_MODEL.md) for the schema, and [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) for the build order.

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
