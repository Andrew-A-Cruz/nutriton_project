#!/usr/bin/env python3
"""Makes the alternate app icons (M23) from assets/icon/app_icon.png.

The icon is two flat colours: a green background and a white mark. Each
variant swaps those two colours, keeping the anti-aliased edges.

Writes, per variant:
  ios/Runner/Assets.xcassets/AppIcon-<Name>.appiconset/  (1024 px, no alpha)
  assets/icon/alt/<name>.png                             (the in-app preview)

Run from the repository root:  python3 tool/make_alt_icons.py   (needs Pillow)
The names must match AppIconChoice in lib/core/appearance.dart and
ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES in the Xcode project.
"""
import json
import os

from PIL import Image

SOURCE = "assets/icon/app_icon.png"
GREEN = (46, 125, 50)
WHITE = (255, 255, 255)
PREVIEW_PX = 180

# name: (background, mark)
VARIANTS = {
    "Midnight": ((28, 28, 30), (76, 175, 80)),
    "Light": ((255, 255, 255), GREEN),
    "Ocean": ((21, 101, 192), WHITE),
}


def recolour(source, background, mark):
    """Maps green -> background and white -> mark, blending in between."""
    out = Image.new("RGB", source.size)
    src = source.convert("RGB").load()
    dst = out.load()
    span = [w - g for g, w in zip(GREEN, WHITE)]
    norm = sum(s * s for s in span)
    for y in range(source.height):
        for x in range(source.width):
            p = src[x, y]
            # How far this pixel is from green towards white, 0..1.
            t = sum((p[i] - GREEN[i]) * span[i] for i in range(3)) / norm
            t = min(1.0, max(0.0, t))
            dst[x, y] = tuple(
                round(background[i] + (mark[i] - background[i]) * t)
                for i in range(3)
            )
    return out


def main():
    source = Image.open(SOURCE)
    os.makedirs("assets/icon/alt", exist_ok=True)
    preview = source.convert("RGB").resize((PREVIEW_PX, PREVIEW_PX), Image.Resampling.LANCZOS)
    preview.save("assets/icon/alt/default.png", optimize=True)
    for name, (background, mark) in VARIANTS.items():
        icon = recolour(source, background, mark)
        folder = f"ios/Runner/Assets.xcassets/AppIcon-{name}.appiconset"
        os.makedirs(folder, exist_ok=True)
        icon.save(f"{folder}/icon-1024.png", optimize=True)
        with open(f"{folder}/Contents.json", "w") as f:
            json.dump(
                {
                    "images": [
                        {
                            "filename": "icon-1024.png",
                            "idiom": "universal",
                            "platform": "ios",
                            "size": "1024x1024",
                        }
                    ],
                    "info": {"author": "xcode", "version": 1},
                },
                f,
                indent=2,
            )
            f.write("\n")
        icon.resize((PREVIEW_PX, PREVIEW_PX), Image.Resampling.LANCZOS).save(
            f"assets/icon/alt/{name.lower()}.png", optimize=True
        )
        print("wrote", folder)


if __name__ == "__main__":
    main()
