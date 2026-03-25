# Raspberry Pi Setup Guide — Drone Ground Control System

A complete guide to set up a Raspberry Pi 5 with a Dahua IP Camera, stream live video to QGroundControl, connect a flight controller (Cube Orange+) via MAVLink, and access everything remotely over the internet using Tailscale.

---

## Hardware Requirements

- Raspberry Pi 5
- Dahua IP Camera (DH-IPC-HFW2431SP-S-S2) — or any RTSP IP camera
- MicroSD card (16GB or more)
- MicroSD card USB reader
- Power supply (USB-C, 5V/5A for RPi 5)
- RJ45 Ethernet cable (Pi ↔ Camera)
- 12V power supply or POE injector for the camera
- Your Mac, Windows, or Linux device

---

## Part 1 — Install Raspberry Pi OS

### Step 1: Download Raspberry Pi Imager

Download and install [Raspberry Pi Imager](https://www.raspberrypi.com/software/) on your device.

### Step 2: Configure Settings Before Writing

Open Raspberry Pi Imager, select your device and OS, click **Next**, then choose **Edit Settings**.

Fill in the following:

| Field | Value |
|-------|-------|
| Hostname | `lab2` (or any name you prefer) |
| Username | `lab2` (or any name you prefer) |
| Password | Set a strong password |
| WiFi SSID | Your WiFi network name |
| WiFi Password | Your WiFi password |
| Enable SSH | ✅ Checked (Services tab) |
| SSH Authentication | Public key (recommended) |

> **Note:** Hostname and username do not have to match, but keeping them the same makes it easier to remember.

### Step 3: Add Your SSH Public Key (Optional)

This step lets you connect via SSH without entering a password every time.

Open Terminal on your device and run:

```bash
cat ~/.ssh/id_rsa.pub
```

If the key does not exist yet, follow the [GitHub SSH key guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) to generate one.

Copy the output and paste it into the **SSH public key** field in RPi Imager settings.

### Step 4: Enable Raspberry Pi Connect (Remote Access)

In the same settings window, enable **Raspberry Pi Connect**. Sign in with your Raspberry Pi account to link the device automatically.

> **Why this matters:** Raspberry Pi Connect gives you browser-based shell access from anywhere — very useful if SSH is not working yet or you need to debug the Pi without a screen.

### Step 5: Write the SD Card

Click **Save**, then **Yes** to start writing. Once done, insert the SD card into your Raspberry Pi and power it on.

After booting, access your Pi from anywhere at [connect.raspberrypi.com](https://connect.raspberrypi.com).

---

## Part 2 — Connect to Your Raspberry Pi via SSH

### Step 1: Connect via hostname

After the Pi boots (wait 1–2 minutes), open Terminal and run:

```bash
ssh lab2@lab2.local
```

The format is always `username@hostname.local` — works automatically on the same WiFi network without knowing the IP.

### Step 2: If hostname does not work

Find the IP manually:

**Option A — Parallel network scan:**
```bash
for i in $(seq 1 254); do (nc -zv -w 1 192.168.0.$i 22 2>&1 | grep -q succeeded && echo "SSH open: 192.168.0.$i") & done; wait
```

**Option B —** Check your router's admin page at `192.168.0.1` and look for the Pi in the connected devices list.

Then connect using the IP:
```bash
ssh lab2@192.168.0.127
```

> **Tip:** To always get the same IP, set a static DHCP reservation in your router using the Pi's MAC address.

---

## Part 3 — Camera Setup

Two camera options are documented. See the full guide:

👉 **[docs/camera-setup.md](docs/camera-setup.md)**

| Option | Status | Detail |
|--------|--------|--------|
| Raspberry Pi HQ Camera (IMX477) | Legacy | CSI ribbon cable, Pi handles encoding |
| Dahua IP Camera (DH-IPC-HFW2431SP-S-S2) | ✅ Currently used | Ethernet, 4MP, 0% Pi CPU |

### Quick Start (Dahua IP Camera)

**1. Set static IP on Pi's ethernet port:**
```bash
sudo nmcli connection add type ethernet ifname eth0 con-name eth0-static \
  ip4 192.168.1.100/24 ipv4.method manual ipv6.method ignore
sudo nmcli connection up eth0-static
```

**2. Clone the repo and start the stream:**
```bash
git clone https://github.com/salemaljebaly/rpi-setup-docs.git
cd rpi-setup-docs
bash scripts/start_ipcam_stream.sh
```

**3. Enable auto-start on boot:**
```bash
sudo systemctl enable ipcam-stream
sudo systemctl start ipcam-stream
```

**4. Open QGroundControl** → **Application Settings** → **Video** → `UDP h.264 Video Stream` → port `5600`.

---

## Part 4 — MAVLink Router (Flight Controller)

To connect a flight controller (e.g. Cube Orange+) to QGroundControl via the Pi, use [mavlink-router](https://github.com/mavlink-router/mavlink-router).

### Step 1: Install dependencies

```bash
sudo apt install -y git meson ninja-build pkg-config gcc g++ libsystemd-dev python3-pip
```

### Step 2: Build and install

```bash
git clone https://github.com/mavlink-router/mavlink-router.git
cd mavlink-router
git submodule update --init --recursive
meson setup build -Dsystemdsystemunitdir=/lib/systemd/system
ninja -C build
sudo ninja -C build install
```

### Step 3: Configure

```bash
sudo mkdir -p /etc/mavlink-router
sudo nano /etc/mavlink-router/main.conf
```

```ini
[General]
Log=/var/log/mavlink-router
MavlinkDialect=ardupilotmega

[UartEndpoint cube]
Device=/dev/ttyACM0
Baud=115200
FlowControl=false

[UdpEndpoint qgc]
Mode=Normal
Address=192.168.0.125
Port=14550
```

Replace `192.168.0.125` with your device's IP.

### Step 4: Enable the service

```bash
sudo systemctl enable mavlink-router
sudo systemctl start mavlink-router
```

---

## Part 5 — Remote Access over the Internet (Tailscale)

For remote access when the Pi and your device are on different networks, use [Tailscale](https://tailscale.com).

### Step 1: Install Tailscale on the Pi

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### Step 2: Install Tailscale on your device

Download from [tailscale.com/download](https://tailscale.com/download) and sign in with the same account.

### Step 3: Find your device's Tailscale IP

Run this on your device (Mac/Windows/Linux):

```bash
tailscale ip -4
```

The IP will start with `100.x.x.x`.

### Step 4: Verify both devices are connected

On the Pi, confirm your device shows as online:

```bash
tailscale status
```

Your device should appear with its `100.x.x.x` IP and **no "offline" label**. If it shows offline, open Tailscale on your device and make sure it is connected with the same account.

### Step 5: Update the two config files on the Pi

**Camera stream** — `scripts/start_ipcam_stream.sh`:
```bash
TARGET_IP=100.x.x.x   # your device's Tailscale IP
```

**MAVLink router** — `/etc/mavlink-router/main.conf`:
```ini
[UdpEndpoint qgc]
Mode=Normal
Address=100.x.x.x     # your device's Tailscale IP
Port=14550
```

Then restart the stream:
```bash
sudo systemctl restart ipcam-stream
```

Everything else stays the same — same ports, same QGroundControl settings. Tailscale handles the routing over the internet transparently.

> **Note:** The stream requires a stable upload connection on the Pi side. If video is choppy over the internet, switch to sub stream by changing `subtype=0` to `subtype=1` in the RTSP URL inside `start_ipcam_stream.sh`.

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Pi not found on network | Not booted yet or wrong WiFi credentials | Wait 2 min, check WiFi settings in RPi Imager |
| SSH permission denied | Wrong username or key not added | Check username, re-add public key |
| Camera not reachable (ping fails) | eth0 has no IP or camera unpowered | Run `nmcli connection up eth0-static`, check camera power |
| "Waiting for video" in QGC | Stream stopped or wrong settings | Run `sudo systemctl restart ipcam-stream` |
| Stream works manually but not on boot | Service not enabled | Run `sudo systemctl enable ipcam-stream` |
| QGC not receiving MAVLink | Wrong IP in mavlink-router config | Update `Address` in `/etc/mavlink-router/main.conf` |
| Cannot access camera web UI | Mac not on same subnet as camera | Use SSH tunnel: `ssh -L 8080:192.168.1.108:80 lab2@lab2.local -N` |
