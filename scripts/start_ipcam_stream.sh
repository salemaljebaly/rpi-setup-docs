#!/bin/bash

# ── IP Camera Stream Configuration ──
# Update these values before running
CAMERA_IP=192.168.1.108       # Default Dahua IP
CAMERA_USER=admin
CAMERA_PASS='YOUR_PASSWORD'   # If password contains @, replace each @ with %40
                              # Example: my@@pass → my%40%40pass

TARGET_IP=192.168.0.125       # IP of the device running QGroundControl
PORT=5600

RTSP_URL="rtsp://${CAMERA_USER}:${CAMERA_PASS}@${CAMERA_IP}/cam/realmonitor?channel=1&subtype=0"

echo "Starting IP camera stream → ${TARGET_IP}:${PORT}"

exec gst-launch-1.0 \
  rtspsrc location="${RTSP_URL}" latency=0 \
  ! rtph264depay \
  ! h264parse \
  ! rtph264pay config-interval=1 pt=96 \
  ! udpsink host=${TARGET_IP} port=${PORT} sync=false async=false
