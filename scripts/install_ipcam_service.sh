#!/bin/bash

# =============================================================================
# install_ipcam_service.sh — Install Dahua IP camera stream as a systemd service
# Run this once on the Raspberry Pi after cloning the repo
# Usage: bash scripts/install_ipcam_service.sh
# =============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_NAME=ipcam-stream
SCRIPT_FILE="$REPO_DIR/scripts/start_ipcam_stream.sh"

# Check stream script exists
if [ ! -f "$SCRIPT_FILE" ]; then
  echo "Error: scripts/start_ipcam_stream.sh not found."
  exit 1
fi

# Check TARGET_IP has been configured
if grep -q "YOUR_PASSWORD" "$SCRIPT_FILE"; then
  echo "Error: Please update CAMERA_PASS in scripts/start_ipcam_stream.sh before installing."
  exit 1
fi

# Make script executable
chmod +x "$SCRIPT_FILE"

# Update service file with correct repo path and current user
USERNAME=$(whoami)
sed "s|/home/lab2/rpi-setup-docs|$REPO_DIR|g; s|User=lab2|User=$USERNAME|g" \
  "$REPO_DIR/scripts/ipcam-stream.service" > /tmp/$SERVICE_NAME.service

# Install service
sudo cp /tmp/$SERVICE_NAME.service /etc/systemd/system/$SERVICE_NAME.service
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo ""
echo "Service installed and started."
echo "Check status with: sudo systemctl status $SERVICE_NAME"
