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

The alternate icons (Pro) and their in-app previews are made from the same source by `python3 tool/make_alt_icons.py` (needs Pillow). Their names are listed in `AppIconChoice` (`lib/core/appearance.dart`) and in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in the Xcode project.

If the iOS Xcode project is modified by the tool (it can rewrite `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`), revert that one line to `YES`.

## Restaurant menus

`assets/menus/menus.json` holds the menus of a few US chains, browsed from Add Food > Restaurants. It is built, never edited by hand:

```
tool/menus/chains/<chain>.json    one file per chain: the source of truth
tool/menus/extract_<chain>.py     reads the chain's own document into that file
tool/menus/sources/               the downloaded documents (git-ignored)
tool/make_menus.py                checks every chain file and writes menus.json
```

**Every value comes from the chain's own published nutrition document**, fetched or downloaded for the purpose, never from memory or a third-party site. Each chain file records the document's address (`source`), the day it was read (`checkedAt`), and what was left out and why (`skipped`).

To add or re-check a chain:

1. Download its US nutrition document into `tool/menus/sources/`. Many chains' sites refuse scripts; use a browser.
2. Write or re-run its extractor (`python3 tool/menus/extract_arbys.py`; PDFs need `pip install pymupdf`). `tool/menus/menulib.py` turns a PDF into rows of cells and writes the chain file.
3. Run `python3 tool/make_menus.py`. It fails, naming the item, on anything the app would skip, on calories that do not match the macros (a swapped column or a typo), and on sugar or fiber above carbs. Fix a failure by re-reading the document, never by changing a number to pass. A row that is inconsistent as printed carries `"energyCheck": false` and a `"note"`.
4. Re-read a sample of items against the document.

The file format: `version`, then `chains[]` (`id`, `name`, `source`, `checkedAt`) each with `items[]` (`id`, `name`, `category`, `calories`, `protein`, `carbs`, `fat`, and `servingWeightG`, `fiber`, `sugar`, `sodium` where published). Values are per item as served; each size is its own item. A drink published by volume counts 1 ml as 1 g. An item with no `servingWeightG` is one the chain publishes without a weight (Dunkin', Sonic, fountain drinks); the app counts it in items and never shows a weight for it. Ids are permanent, because catalog foods point at them: a renamed product keeps its id. The script raises `version` whenever the output changes, which is what refreshes unedited restaurant foods on users' phones.

Names only: no logos, brand colours or artwork.

## Starter foods

`assets/foods/generic_foods.tsv` holds about 6,000 generic foods from USDA FoodData Central (SR Legacy, public domain), searchable from Add Food. To rebuild it, download and unzip the SR Legacy CSV release and run `python3 tool/make_generic_foods.py <folder>`; the script's header has the link and the file format.
