#!/bin/bash

set -e

APP_PACKAGE="network.kalock.myanmar2d"
MAIN_ACTIVITY=".MainActivity"
APK_PATH="app.apk"
MAX_ATTEMPTS=10
RETRY_DELAY=5
OUTPUT_VIDEO="screen.mp4"

echo "[Run] ADB wait for device..."
adb wait-for-device

echo "[Run] Installing ${APK_PATH}..."
adb install -r "${APK_PATH}"
echo "[Run] Install done."

# Confirm install
INSTALLED=$(adb shell pm list packages | grep "${APP_PACKAGE}" || true)
if [ -z "$INSTALLED" ]; then
  echo "[Run] ERROR: App not found after install!"
  exit 1
fi
echo "[Run] App confirmed installed."

echo "[Run] Launching ${APP_PACKAGE}..."
adb shell am start -a android.intent.action.MAIN \
  -c android.intent.category.LAUNCHER \
  -n "${APP_PACKAGE}/${MAIN_ACTIVITY}"

# Wait a moment for the app to launch
sleep 3

echo "[Run] Starting stream..."

# ─── Detect scrcpy version ───────────────────────────────────────────────────
SCRCPY_MAJOR=$(scrcpy --version 2>&1 | grep -oP '(?<=scrcpy )\d+' | head -1)
echo "[Stream] Detected scrcpy major version: ${SCRCPY_MAJOR}"

if [ -z "$SCRCPY_MAJOR" ]; then
  echo "[Stream] WARNING: Could not detect scrcpy version, assuming v1.x"
  SCRCPY_MAJOR=1
fi

# ─── Build scrcpy command based on version ───────────────────────────────────
if [ "$SCRCPY_MAJOR" -ge 2 ]; then
  echo "[Stream] Using scrcpy v2+ options"
  SCRCPY_OPTS="--no-audio --video-codec=h264 --no-display"
else
  echo "[Stream] Using scrcpy v1.x options"
  SCRCPY_OPTS="--no-display"
fi

# ─── Streaming loop ──────────────────────────────────────────────────────────
attempt=1
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
  echo "[Stream] Attempt ${attempt} — $(date)"

  echo "[Stream] Waiting for ADB device..."
  adb wait-for-device

  # Start scrcpy piped to ffmpeg
  if [ "$SCRCPY_MAJOR" -ge 2 ]; then
    scrcpy $SCRCPY_OPTS --output-file="${OUTPUT_VIDEO}" &
  else
    scrcpy $SCRCPY_OPTS --record="${OUTPUT_VIDEO}" &
  fi

  SCRCPY_PID=$!
  echo "[Stream] Started PID=${SCRCPY_PID}"

  # Wait briefly and check if scrcpy is still running
  sleep 5

  if kill -0 "$SCRCPY_PID" 2>/dev/null; then
    echo "[Stream] scrcpy is running successfully."
    wait "$SCRCPY_PID"
    echo "[Stream] scrcpy finished."
    break
  else
    echo "[Stream] Attempt ${attempt} ended"

    # Print last 10 lines of scrcpy output for debug
    echo "--- scrcpy (last 10) ---"
    scrcpy $SCRCPY_OPTS --output-file=/dev/null 2>&1 | tail -10 || true

    if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
      echo "[Watchdog] Reconnecting in ${RETRY_DELAY}s..."
      sleep "$RETRY_DELAY"
    fi
  fi

  attempt=$((attempt + 1))
done

if [ "$attempt" -gt "$MAX_ATTEMPTS" ]; then
  echo "[Stream] Max attempts (${MAX_ATTEMPTS}) reached. Exiting."
fi

echo "[Stream] Cleaning up..."
# Kill any leftover scrcpy processes
pkill -f scrcpy 2>/dev/null || true
pkill -f ffmpeg 2>/dev/null || true

echo "[Stream] Done."
