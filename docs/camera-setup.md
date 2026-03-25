# Camera Setup Guide

This guide covers two camera options for streaming live video to QGroundControl via Raspberry Pi.

---

## Option Comparison

| | HQ Camera (IMX477) | Dahua IP Camera ✅ Currently Used |
|---|---|---|
| Connection | CSI ribbon cable → Pi | Ethernet (RJ45) |
| Encoding | Pi CPU (~35% per core) | Built-in chip (0% Pi CPU) |
| Resolution | Up to 720p (for low latency) | 4MP native |
| Power | From Pi GPIO | POE or 12V |
| IR night vision | No | Yes |
| Setup complexity | Medium | Simple |
| Recommended for | Testing / learning | Drone use |

---

## Option A — Raspberry Pi HQ Camera (IMX477)

> **Note:** This was the original setup. It works but puts encoding load on the Pi. The Dahua IP camera (Option B) is now used instead.

### Step 1: Connect the Camera

Connect the HQ Camera to the Pi using the CSI ribbon cable. Make sure the cable is fully inserted and the clip is locked.

### Step 2: Install Required Packages

```bash
sudo apt update
sudo apt install -y rpicam-apps libcamera-apps gstreamer1.0-tools \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-libcamera \
  v4l-utils
```

### Step 3: Verify Camera is Detected

```bash
rpicam-hello --list-cameras
```

Expected output:
```
Available cameras
-----------------
0 : imx477 [4056x3040 12-bit RGGB] (...)
```

### Step 4: Run the Stream

```bash
bash scripts/start_stream.sh
```

The script uses a named pipe between `rpicam-vid` and GStreamer:

```
rpicam-vid → /tmp/h264.pipe → GStreamer → UDP → QGC
```

### Known Issues

| Problem | Fix |
|---------|-----|
| Blurry image | Rotate the lens manually while watching the live stream |
| Purple/magenta color | IR cut filter missing or misaligned on the lens mount |
| Video upside down | Add `--rotation 180` to `rpicam-vid` in `start_stream.sh` |
| High latency | Use `preset=ultrafast;tune=zerolatency` in libx264 options |

---

## Option B — Dahua IP Camera (DH-IPC-HFW2431SP-S-S2) ✅ Currently Used

This camera connects via Ethernet and encodes H.264 internally — the Pi only forwards the stream, using near 0% CPU.

### Hardware

- **Model**: Dahua DH-IPC-HFW2431SP-S-S2
- **Resolution**: 4MP (2560×1440)
- **Lens**: 3.6mm fixed
- **Power**: 12V DC or POE (Power over Ethernet)
- **Interface**: RJ45 Ethernet

### Step 1: Connect the Camera

Connect the camera directly to the Pi's ethernet port (`eth0`) using an RJ45 cable. Power the camera via 12V or POE injector.

### Step 2: Set Static IP on Pi's eth0

The camera defaults to `192.168.1.108`. Assign a static IP to the Pi's ethernet port:

```bash
sudo nmcli connection add type ethernet ifname eth0 con-name eth0-static \
  ip4 192.168.1.100/24 ipv4.method manual ipv6.method ignore
sudo nmcli connection up eth0-static
```

Verify the camera is reachable:

```bash
ping -c 3 192.168.1.108
```

### Step 3: First-Time Camera Setup

Open an SSH tunnel to access the camera web UI from your computer:

```bash
ssh -L 8080:192.168.1.108:80 lab2@lab2.local -N
```

Then open `http://localhost:8080` in your browser. Complete the initial setup — set region, video standard (PAL for Middle East), and a strong password.

> **Note:** The region setting only affects timezone and language defaults. It does not lock the camera to a specific location — you can use it anywhere.

### Step 4: Verify RTSP Stream

```bash
ffprobe -v error -rtsp_transport tcp \
  'rtsp://admin:YOUR_PASSWORD@192.168.1.108/cam/realmonitor?channel=1&subtype=0'
```

> **Important:** If your password contains `@`, replace each `@` with `%40` in the URL.
> Example: `my@@password` → `my%40%40password`

### Step 5: Run the Stream

```bash
bash scripts/start_ipcam_stream.sh
```

The pipeline is:

```
Dahua Camera (H.264) → RTSP → Pi → RTP/UDP → QGC
```

The camera encodes video internally. The Pi just re-wraps packets — no decoding or re-encoding.

### Step 6: Enable Auto-Start on Boot

```bash
sudo systemctl enable ipcam-stream
sudo systemctl start ipcam-stream
sudo systemctl status ipcam-stream
```

To restart or stop:

```bash
sudo systemctl restart ipcam-stream
sudo systemctl stop ipcam-stream
```

### Stream Configuration

Edit `scripts/start_ipcam_stream.sh` to update the camera IP, credentials, or target IP:

```bash
CAMERA_IP=192.168.1.108
CAMERA_USER=admin
CAMERA_PASS='YOUR_PASSWORD'     # use %40 instead of @ in password
TARGET_IP=192.168.0.125         # IP of the device running QGroundControl
PORT=5600
```
