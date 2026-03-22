# Raspberry Pi Setup Guide — Camera Streaming to QGroundControl

A complete guide to set up a Raspberry Pi 5 with an HQ Camera (IMX477), stream live video to QGroundControl on your Mac/PC, and access the device remotely over the internet using Tailscale.

---

## Hardware Requirements

- Raspberry Pi 5
- Raspberry Pi HQ Camera (IMX477) with a compatible lens
- MicroSD card (16GB or more)
- MicroSD card USB reader
- Power supply (USB-C, 5V/5A for RPi 5)
- Your Mac or PC

---

## Part 1 — Install Raspberry Pi OS

### Step 1: Download Raspberry Pi Imager

Download and install [Raspberry Pi Imager](https://www.raspberrypi.com/software/) on your Mac or PC.

### Step 2: Configure Settings Before Writing

Open Raspberry Pi Imager, select your device and OS, then click the **gear icon ⚙️** (Edit Settings) before writing.

Fill in the following:

| Field | Value |
|-------|-------|
| Hostname | `lab2` (or any name you prefer) |
| Username | `lab2` (or any name you prefer) |
| Password | Set a strong password |
| WiFi SSID | Your WiFi network name |
| WiFi Password | Your WiFi password |
| Enable SSH | ✅ Checked |
| SSH Authentication | Public key (recommended) |

> **Note:** Hostname and username do not have to match. But keeping them the same makes it easier to remember.

### Step 3: Add Your SSH Public Key

On your Mac, open Terminal and run:

```bash
cat ~/.ssh/id_rsa.pub
```

If the file does not exist, generate a new key first:

```bash
ssh-keygen -t rsa -b 4096
```

Copy the output and paste it into the **SSH public key** field in RPi Imager settings.

### Step 4: Enable Raspberry Pi Connect (Remote Access)

In the same RPi Imager settings, enable **Raspberry Pi Connect**. Sign in with your Raspberry Pi account to link the device automatically.

If you do not have an account yet, create one first at: https://www.raspberrypi.com/software/connect/

> **Why this matters:** Raspberry Pi Connect gives you browser-based shell access from anywhere — very useful if SSH is not working yet or you need to debug the Pi without a screen.

### Step 5: Write the SD Card

Click **Save**, then click **Write**. Wait for it to finish, then insert the SD card into your Raspberry Pi and power it on.

Once booted, go to [connect.raspberrypi.com](https://connect.raspberrypi.com) to access your Pi from anywhere.

---

## Part 2 — Connect to Your Raspberry Pi

### Step 1: Connect via SSH

After the Pi boots (wait 1–2 minutes), connect directly using the hostname you set in RPi Imager:

```bash
ssh lab2@lab2.local
```

The format is always `username@hostname.local`. This works automatically — no need to find the IP address.

> **How it works:** The Pi broadcasts its hostname on the local network via mDNS. As long as your Mac and the Pi are on the same WiFi network, this will resolve automatically.

### Step 2: If hostname does not work

If `lab2.local` does not resolve, find the IP manually using one of these methods:

**Option A — Parallel network scan (fast):**
```bash
for i in $(seq 1 254); do (nc -zv -w 1 192.168.0.$i 22 2>&1 | grep -q succeeded && echo "SSH open: 192.168.0.$i") & done; wait
```

**Option B — Check your router's admin page** at `192.168.0.1` and look for the Pi in the connected devices list.

Then connect using the IP:
```bash
ssh lab2@192.168.0.127
```

> **Tip:** To always get the same IP, set a static IP reservation in your router's DHCP settings using the Pi's MAC address.

---

## Part 3 — Camera Setup

### Step 1: Connect the Camera

Connect the Raspberry Pi HQ Camera to the Pi using the CSI ribbon cable. Make sure the cable is inserted correctly and the clip is locked.

### Step 2: Install Required Packages

```bash
sudo apt update
sudo apt install -y rpicam-apps libcamera-apps gstreamer1.0-tools \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-libcamera \
  v4l-utils
```

### Step 3: Verify the Camera is Detected

```bash
rpicam-hello --list-cameras
```

Expected output:
```
Available cameras
-----------------
0 : imx477 [4056x3040 12-bit RGGB] (...)
```

If the camera is detected, you are ready to proceed.

### Step 4: Capture a Test Image

```bash
rpicam-still -o test.jpg
```

To copy the image to your Mac and view it:

```bash
scp lab2@192.168.0.127:~/test.jpg ~/Desktop/test.jpg
```

---

## Part 4 — Known Camera Issues and Fixes

### Issue 1: Blurry Image

The Raspberry Pi HQ Camera uses a **manual focus lens**. If the image is blurry, you need to physically rotate the lens until the image is in focus.

- Start the video stream (see Part 6)
- Watch the live feed in QGroundControl
- Slowly rotate the lens clockwise or counter-clockwise
- Stop when the image is sharp

### Issue 2: Purple or Magenta Color in Images

The IMX477 HQ Camera has a removable **IR cut filter** on the lens mount. If the filter is missing or not seated correctly, all images will appear purple or magenta.

- Check the lens mount on the camera board for a small glass filter
- Make sure it is screwed in properly
- If the filter is missing, you need to purchase a replacement

> **Note:** The live video stream may appear with correct colors even without the IR filter, depending on the encoding pipeline used. However, still images will always appear purple without the filter.

---

## Part 5 — Live Video Stream to QGroundControl

### Step 1: Download the Stream Script

On the Raspberry Pi, clone this repository:

```bash
git clone https://github.com/salemaljebaly/rpi-setup-docs.git
cd rpi-setup-docs
```

### Step 2: Run the Stream Script

```bash
bash scripts/start_stream.sh 192.168.0.125
```

Replace `192.168.0.125` with your Mac's IP address.

To find your Mac's IP:

```bash
ipconfig getifaddr en0
```

### Step 3: Configure QGroundControl

1. Open QGroundControl on your Mac
2. Click the **Q icon** (top left) → **Application Settings** → **Video**
3. Set **Video Source** to `UDP h.264 Video Stream`
4. Set **UDP Port** to `5600`
5. Close settings — the video should appear in the main HUD

### Step 4: Stop the Stream

```bash
sudo killall rpicam-vid gst-launch-1.0
```

---

## Part 6 — Remote Streaming over Tailscale

For remote access over the internet (when the Pi and your Mac are on different networks), use Tailscale VPN.

This setup is documented in a separate repository:

👉 [mavlink-router-raspberrypi](https://github.com/salemaljebaly/mavlink-router-raspberrypi)

The same approach applies for camera streaming — replace the target IP address with your Mac's **Tailscale IP** when running the stream script.

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Pi not found on network | Not booted yet or wrong WiFi credentials | Wait 2 min, check WiFi settings in RPi Imager |
| SSH permission denied | Wrong username or key not added | Check username in RPi Imager, re-add public key |
| SSH key negotiation error | Wrong IP, connecting to a different device | Confirm Pi IP with `ip addr show` on the Pi |
| Camera not detected | Cable not connected properly | Re-seat the CSI ribbon cable |
| Blurry stream | Lens not focused | Rotate lens manually while watching the stream |
| Purple image | IR cut filter missing or misaligned | Check and reseat the IR filter on the lens mount |
| "Waiting for video" in QGC | Stream stopped or wrong settings | Restart stream script, verify UDP port 5600 |
| High video latency | Software encoding is slow | Future improvement: switch to RTSP with mediamtx |

---

## Next Improvements

- [ ] Switch from RTP/UDP to RTSP using [mediamtx](https://github.com/bluenviron/mediamtx) for lower latency
- [ ] Auto-start stream on boot using systemd service
- [ ] Set static IP via router DHCP reservation
