#!/bin/bash
set -e

echo "[Run] ADB wait for device..."
adb wait-for-device
sleep 3
adb shell input keyevent 82
sleep 5

# ── Install APK ───────────────────────────────────────────────
APK_PATH="app.apk"

if [ ! -f "$APK_PATH" ]; then
  echo "[Run] ERROR: app.apk not found. Should have been downloaded in workflow."
  exit 1
fi

echo "[Run] Installing $APK_PATH..."
adb install -r --no-incremental "$APK_PATH"
echo "[Run] Install done."
sleep 5

# ── Verify installed ──────────────────────────────────────────
if ! adb shell pm list packages | grep -q "network.kalock.myanmar2d"; then
  echo "[Run] ERROR: App not found after install."
  adb shell pm list packages | grep -i kalock || true
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
