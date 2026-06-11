#!/bin/bash

MAX_ATTEMPTS=10
ATTEMPT=0
SCRCPY_LOG="/tmp/scrcpy.log"
FFMPEG_LOG="/tmp/ffmpeg.log"
STREAM_URL="${STREAM_URL:-rtmp://localhost/live/stream}"

cleanup() {
  echo "[Stream] Cleaning up..."
  pkill -f scrcpy || true
  pkill -f ffmpeg || true
}

trap cleanup EXIT

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "[Stream] Attempt $ATTEMPT — $(date)"

  pkill -f scrcpy 2>/dev/null || true
  pkill -f ffmpeg 2>/dev/null || true
  sleep 1

  echo "[Stream] Waiting for ADB device..."
  adb wait-for-device
  sleep 2

  scrcpy \
    --no-sound \
    --video-codec=h264 \
    --video-bit-rate=2M \
    --max-fps=25 \
    --no-window \
    --record=- \
    --record-format=mkv 2>"$SCRCPY_LOG" | \
  ffmpeg -y \
    -re \
    -i pipe:0 \
    -c:v copy \
    -f flv \
    "$STREAM_URL" \
    > "$FFMPEG_LOG" 2>&1 &

  STREAM_PID=$!
  echo "[Stream] Started PID=$STREAM_PID"
  sleep 5

  if kill -0 $STREAM_PID 2>/dev/null; then
    echo "[Stream] Stream running OK — PID=$STREAM_PID"
    wait $STREAM_PID
    echo "[Stream] Stream ended"
  else
    echo "[Stream] Attempt $ATTEMPT ended"
  fi

  echo "--- scrcpy (last 10) ---"
  tail -n 10 "$SCRCPY_LOG" 2>/dev/null || echo "(no log)"

  echo "--- ffmpeg (last 10) ---"
  tail -n 10 "$FFMPEG_LOG" 2>/dev/null || echo "(no log)"

  if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
    echo "[Watchdog] Reconnecting in 5s..."
    sleep 5
  fi
done

echo "[Stream] Max attempts ($MAX_ATTEMPTS) reached. Exiting."
