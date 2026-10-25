#!/bin/bash
# Builds a signed release of Nutriton and installs it on a paired iPhone,
# over USB or Wi-Fi. Run from anywhere: ./install.sh [device-id]
#
# Installs with devicectl, which updates the app in place. `flutter install`
# uninstalls first, which wipes the app's on-device database.
set -euo pipefail

BUNDLE_ID="com.nutriton.app"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
APP="$ROOT/build/ios/iphoneos/Runner.app"
cd "$ROOT"

DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  DEVICE="$(flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
devices = [d for d in json.load(sys.stdin)
           if d["targetPlatform"] == "ios" and not d["emulator"]]
if devices:
    print(devices[0]["id"])
')"
fi
if [ -z "$DEVICE" ]; then
  echo "No physical iPhone found. Unlock it, check it is on the same Wi-Fi" >&2
  echo "as this Mac (or plug it in), and run 'flutter devices'." >&2
  exit 1
fi
echo "==> Device: $DEVICE"

echo "==> Building release"
flutter build ios --release

echo "==> Installing"
xcrun devicectl device install app --device "$DEVICE" "$APP"

echo "==> Launching"
if ! xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID"; then
  echo "Installed, but could not launch. Either the phone is locked, or the" >&2
  echo "developer profile is not trusted yet (Settings > General >" >&2
  echo "VPN & Device Management). Open Nutriton on the phone." >&2
fi
