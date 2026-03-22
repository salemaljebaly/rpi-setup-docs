#!/bin/bash

# =============================================================================
# install_service.sh — Install camera stream as a systemd service
# Run this once on the Raspberry Pi after cloning the repo
# Usage: bash scripts/install_service.sh
# =============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_NAME=camera-stream
CONFIG_FILE="$REPO_DIR/config/stream.conf"

# Check config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: config/stream.conf not found."
  echo "Please create it first:"
  echo "  cp config/stream.conf.example config/stream.conf"
  echo "  nano config/stream.conf   # set your TARGET_IP"
  exit 1
fi

# Make script executable
chmod +x "$REPO_DIR/scripts/start_stream.sh"

# Update service file with correct repo path and current user
USERNAME=$(whoami)
sed "s|/home/lab2/rpi-setup-docs|$REPO_DIR|g; s|User=lab2|User=$USERNAME|g" \
  "$REPO_DIR/scripts/camera-stream.service" > /tmp/$SERVICE_NAME.service

# Install service
sudo cp /tmp/$SERVICE_NAME.service /etc/systemd/system/$SERVICE_NAME.service
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo ""
echo "Service installed and started."
echo "Check status with: sudo systemctl status $SERVICE_NAME"
