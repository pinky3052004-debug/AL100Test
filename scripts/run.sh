#!/bin/bash
set -e

echo "[Run] ADB wait for device..."
adb wait-for-device
sleep 3
adb shell input keyevent 82
sleep 5

# ── Install APK ──────────────────────────────────────────────
APK_PATH="app.apk"

if [ ! -f "$APK_PATH" ]; then
  echo "[Run] Downloading Myanmar 2D APK from release..."
  curl -L \
    "https://github.com/pinky3052004-debug/AL100Test/releases/download/v1.0.0/app.apk" \
    -o "$APK_PATH"
fi

echo "[Run] Installing $APK_PATH..."
adb install -r "$APK_PATH"
echo "[Run] Install done."

sleep 5

# ── Verify app is installed ───────────────────────────────────
if ! adb shell pm list packages | grep -q "network.kalock.myanmar2d"; then
  echo "[Run] ERROR: App not found after install. Aborting."
  adb shell pm list packages
  exit 1
fi

echo "[Run] App confirmed installed."

# ── Launch app ────────────────────────────────────────────────
echo "[Run] Launching network.kalock.myanmar2d..."
adb shell am start \
  -n "network.kalock.myanmar2d/.MainActivity" \
  -a android.intent.action.MAIN \
  -c android.intent.category.LAUNCHER

sleep 10

# ── Start stream ──────────────────────────────────────────────
echo "[Run] Starting stream..."
chmod +x scripts/stream.sh
bash scripts/stream.sh
