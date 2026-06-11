#!/usr/bin/env bash
set -euo pipefail

STREAM_END=$(( $(date +%s) + 19800 ))   # 5h 30m
RETRY_DELAY=5
ATTEMPT=0

stream_once() {
  echo "[Stream] Attempt $ATTEMPT — $(date)"

  FIFO=$(mktemp -u /tmp/stream_pipe_XXXXXX)
  mkfifo "$FIFO"
  trap "rm -f '$FIFO'" RETURN

  scrcpy \
    --no-audio \
    --no-window \
    --max-size=1280 \
    --video-bit-rate=2M \
    --video-codec=h264 \
    --push-target=none \
    --record=- \
    > "$FIFO" 2>/tmp/scrcpy.log &
  SCRCPY_PID=$!

  ffmpeg \
    -thread_queue_size 1024 \
    -i "$FIFO" \
    -f lavfi \
      -thread_queue_size 1024 \
      -i anullsrc=channel_layout=stereo:sample_rate=44100 \
    -c:v libx264 \
    -preset veryfast \
    -tune zerolatency \
    -g 60 \
    -vf "scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,format=yuv420p" \
    -b:v 2M -maxrate 2M -bufsize 4M \
    -c:a aac -b:a 128k \
    -reconnect 1 \
    -reconnect_at_eof 1 \
    -reconnect_streamed 1 \
    -reconnect_delay_max 5 \
    -f flv \
    "rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_STREAM_KEY}" \
    2>/tmp/ffmpeg.log &
  FFMPEG_PID=$!

  wait -n $SCRCPY_PID $FFMPEG_PID 2>/dev/null || true

  kill $SCRCPY_PID $FFMPEG_PID 2>/dev/null || true
  wait $SCRCPY_PID $FFMPEG_PID 2>/dev/null || true

  echo "[Stream] Attempt $ATTEMPT ended"
  echo "--- scrcpy (last 10) ---"; tail -10 /tmp/scrcpy.log || true
  echo "--- ffmpeg (last 10) ---"; tail -10 /tmp/ffmpeg.log || true
}

while [ "$(date +%s)" -lt "$STREAM_END" ]; do
  ATTEMPT=$(( ATTEMPT + 1 ))
  stream_once || true

  REMAINING=$(( STREAM_END - $(date +%s) ))
  [ "$REMAINING" -le 0 ] && { echo "Window elapsed."; break; }

  echo "[Watchdog] Reconnecting in ${RETRY_DELAY}s..."
  sleep "$RETRY_DELAY"
  adb shell input keyevent KEYCODE_WAKEUP || true
done

echo "==== Stream session complete ===="
