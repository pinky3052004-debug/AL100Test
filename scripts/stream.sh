#!/bin/bash
set -e

echo "[Run] ADB wait for device..."
adb wait-for-device
adb shell input keyevent 82
sleep 5

# Install APK if present
if [ -f app.apk ]; then
  echo "[Run] Installing app.apk..."
  adb install -r app.apk
else
  echo "[Run] No app.apk found, skipping install."
fi

# Launch Myanmar 2D app
echo "[Run] Launching network.kalock.myanmar2d..."
adb shell monkey \
  -p network.kalock.myanmar2d \
  -c android.intent.category.LAUNCHER 1

sleep 10

# Start stream
echo "[Run] Starting stream..."
chmod +x scripts/stream.sh
bash scripts/stream.sh
