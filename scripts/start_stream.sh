#!/bin/bash

# =============================================================================
# start_stream.sh — Stream Raspberry Pi HQ Camera to QGroundControl via UDP
# Usage: bash start_stream.sh <TARGET_IP>
# Example: bash start_stream.sh 192.168.0.125
# =============================================================================

TARGET_IP=${1:-""}
PORT=5600
PIPE=/tmp/h264.pipe

if [ -z "$TARGET_IP" ]; then
  echo "Error: Please provide the target IP address."
  echo "Usage: bash start_stream.sh <TARGET_IP>"
  echo "Example: bash start_stream.sh 192.168.0.125"
  exit 1
fi

echo "Starting stream to $TARGET_IP:$PORT ..."

# Kill any previous instances
sudo killall rpicam-vid gst-launch-1.0 2>/dev/null
sleep 1

# Create named pipe
rm -f $PIPE
mkfifo $PIPE

# Start camera capture with H.264 encoding
rpicam-vid -t 0 \
  --inline \
  --width 1280 \
  --height 720 \
  --framerate 30 \
  --bitrate 4000000 \
  --codec libav \
  --libav-video-codec libx264 \
  --libav-format mpegts \
  --sharpness 1.5 \
  --denoise off \
  -o $PIPE &

sleep 2

# Stream via GStreamer RTP to QGroundControl
gst-launch-1.0 filesrc location=$PIPE ! \
  tsdemux ! \
  h264parse ! \
  rtph264pay config-interval=1 pt=96 ! \
  udpsink host=$TARGET_IP port=$PORT

echo "Stream stopped."
