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

Two camera options are supported. See the full guide for both:

👉 **[docs/camera-setup.md](docs/camera-setup.md)**

| Option | Status | Detail |
|--------|--------|--------|
| Raspberry Pi HQ Camera (IMX477) | Legacy | CSI ribbon cable, Pi handles encoding |
| Dahua IP Camera (DH-IPC-HFW2431SP-S-S2) | ✅ Currently used | Ethernet, 4MP, 0% Pi CPU |

### Quick Start (Dahua IP Camera)

Clone the repo on the Pi, then start the stream:

```bash
git clone https://github.com/salemaljebaly/rpi-setup-docs.git
cd rpi-setup-docs
bash scripts/start_ipcam_stream.sh
```

Enable auto-start on boot:

```bash
sudo systemctl enable ipcam-stream
sudo systemctl start ipcam-stream
```

Open QGroundControl → **Application Settings** → **Video** → `UDP h.264 Video Stream` → port `5600`.

---

## Part 6 — Remote Access over the Internet (Tailscale)

By default, the setup works on a **local network**. If the Pi and your device are on **different networks** (e.g. Pi on a drone field, you on a laptop elsewhere), install [Tailscale](https://tailscale.com) on both devices. Tailscale creates a private VPN between them so they behave as if they are on the same network — no port forwarding or firewall rules needed.

### Step 1: Install Tailscale on the Pi

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### Step 2: Install Tailscale on your device

Download from [tailscale.com/download](https://tailscale.com/download) and sign in with the same account.

### Step 3: Find your device's Tailscale IP

```bash
tailscale ip -4
```

The IP will start with `100.x.x.x`.

### Step 4: Update the two config files on the Pi

**Camera stream** — `config/stream.conf`:
```
TARGET_IP=100.x.x.x
```

**MAVLink router** — `/etc/mavlink-router/main.conf`:
```ini
[UdpEndpoint qgc]
Mode=Normal
Address=100.x.x.x
Port=14550
```

Everything else stays the same — same ports, same QGroundControl settings. Tailscale handles the rest.

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
