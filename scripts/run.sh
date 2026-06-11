#!/bin/bash

set -euo pipefail

APP_PACKAGE="network.kalock.myanmar2d"
MAIN_ACTIVITY=".MainActivity"
APK_PATH="app.apk"
OUTPUT_VIDEO="screen.mp4"
RECORD_SECONDS=60
MAX_ATTEMPTS=10
RETRY_DELAY=5

# ── 1. Wait for emulator to fully boot ──────────────────────────
echo "[Run] ADB wait for device..."
adb wait-for-device
until adb shell getprop sys.boot_completed 2>/dev/null | grep -q "1"; do
  sleep 2
done
echo "[Run] Emulator is ready."

# ── 2. Install APK ──────────────────────────────────────────────
echo "[Run] Installing ${APK_PATH}..."
adb install -r "${APK_PATH}"
echo "[Run] Install done."

INSTALLED=$(adb shell pm list packages 2>/dev/null | grep "${APP_PACKAGE}" || true)
if [ -z "$INSTALLED" ]; then
  echo "[Run] ERROR: App not found after install!"
  exit 1
fi
echo "[Run] App confirmed installed."

# ── 3. Launch App ───────────────────────────────────────────────
echo "[Run] Launching ${APP_PACKAGE}..."
adb shell am start \
  -a android.intent.action.MAIN \
  -c android.intent.category.LAUNCHER \
  -n "${APP_PACKAGE}/${MAIN_ACTIVITY}"
sleep 5

# ── 4. Detect scrcpy version ────────────────────────────────────
echo "[Run] Starting stream..."
SCRCPY_MAJOR=$(scrcpy --version 2>&1 | grep -oP '\d+' | head -1 || echo "1")
echo "[Stream] scrcpy major version: ${SCRCPY_MAJOR}"

# ── 5. Try scrcpy with retry loop ───────────────────────────────
STREAM_SUCCESS=false

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "[Stream] Attempt ${attempt} — $(date)"
  echo "[Stream] Waiting for ADB device..."
  adb wait-for-device

  pkill -f scrcpy 2>/dev/null || true
  pkill -f ffmpeg 2>/dev/null || true
  sleep 1

  if [ "$SCRCPY_MAJOR" -ge 2 ]; then
    scrcpy \
      --no-audio \
      --video-codec=h264 \
      --video-encoder=OMX.google.h264.encoder \
      --no-display \
      --output-file="${OUTPUT_VIDEO}" 2>&1 &
  else
    scrcpy \
      --no-display \
      --record="${OUTPUT_VIDEO}" \
      --record-format=mp4 2>&1 &
  fi

  SCRCPY_PID=$!
  echo "[Stream] Started PID=${SCRCPY_PID}"
  sleep 5

  if kill -0 "$SCRCPY_PID" 2>/dev/null; then
    echo "[Stream] scrcpy is running successfully."
    sleep "$RECORD_SECONDS"
    kill "$SCRCPY_PID" 2>/dev/null || true
    wait "$SCRCPY_PID" 2>/dev/null || true
    echo "[Stream] Recording finished. Saved to ${OUTPUT_VIDEO}"
    STREAM_SUCCESS=true
    break
  else
    echo "[Stream] Attempt ${attempt} ended"
    if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
      echo "[Watchdog] Reconnecting in ${RETRY_DELAY}s..."
      sleep "$RETRY_DELAY"
    fi
  fi
done

# ── 6. Fallback: adb screenrecord (no GPU needed) ───────────────
if [ "$STREAM_SUCCESS" = false ]; then
  echo "[Stream] Max attempts (${MAX_ATTEMPTS}) reached. Exiting."
  echo "[Stream] Cleaning up..."
  rm -f "${OUTPUT_VIDEO}"

  RECORD_LIMIT=$RECORD_SECONDS
  [ "$RECORD_LIMIT" -gt 180 ] && RECORD_LIMIT=180

  echo "[Fallback] Starting adb screenrecord for ${RECORD_LIMIT}s..."
  adb shell screenrecord \
    --time-limit "${RECORD_LIMIT}" \
    --bit-rate 4000000 \
    /sdcard/screen.mp4 &

  ADB_RECORD_PID=$!
  echo "[Fallback] screenrecord PID=${ADB_RECORD_PID}"
  wait "$ADB_RECORD_PID" 2>/dev/null || true

  echo "[Fallback] Pulling video from device..."
  adb pull /sdcard/screen.mp4 "${OUTPUT_VIDEO}"
  adb shell rm -f /sdcard/screen.mp4

  if [ -f "${OUTPUT_VIDEO}" ]; then
    echo "[Fallback] Recording saved to ${OUTPUT_VIDEO}"
  else
    echo "[Error] Fallback recording failed. No output file."
    exit 1
  fi
fi

# ── 7. Cleanup ──────────────────────────────────────────────────
echo "[Stream] Cleaning up..."
pkill -f scrcpy 2>/dev/null || true
pkill -f ffmpeg 2>/dev/null || true
echo "[Run] All done. Output: ${OUTPUT_VIDEO}"
