# Razer DPI & Lighting Control for macOS (DeathAdder Essential)

A fast, lightweight, native macOS menu bar app and CLI utility designed specifically for the **Razer DeathAdder Essential** wired USB mouse (`PID 0x0098`, `VID 0x1532`).

Built on top of the reverse-engineered USB HID protocol from [MacRazer](https://github.com/SorcRR/MacRazer) and [OpenRazer](https://github.com/openrazer/openrazer), without requiring Razer Synapse, Electron, background daemons, or kernel extensions.

---

## Features

- **DPI Control (200 – 6,400 DPI)**:
  - 1-click presets: `400`, `800` (default), `1,600`, `3,200`, `6,400`
  - Smooth slider (200 to 6,400 DPI)
  - Custom direct DPI numerical input with validation
  - Hardware readback on startup & reconnection
- **Lighting & Effect Control**:
  - **Static**: Solid iconic Razer green
  - **Breathing**: Pulsating rhythmic fade effect
  - **Off**: Completely turn off LED lighting
  - **Brightness Slider**: 0% to 100% fine control
- **Ultra-Lightweight & Native**:
  - Pure Cocoa / IOKit implementation (~100 KB binary, < 15 MB RAM)
  - Compiles in 1 second with Apple Clang (zero SwiftPM toolchain mismatch issues)
  - Seamless Dark / Light Mode menu bar icon and popover
  - Hotplug detection: auto-detects mouse disconnect and reconnect
  - Settings persistence via `NSUserDefaults`
- **Dual Interface**:
  - Run as a sleek **Menu Bar Application** with popup Control Panel
  - Or run directly from terminal/scripts via fast **CLI flags**

---

## Screenshots & Interface

- **Menu Bar Status Item**: Displays mouse icon and active DPI (`800`). Clicking opens a quick menu with instant presets, lighting toggles, and brightness submenu.
- **Control Panel Window**: Complete control panel with live hardware connection badge, quick presets, smooth slider, and brightness level adjustments.

---

## Download & Installation

### Option 1: Download Pre-built Release (Recommended)
1. Go to **[Releases](../../releases/latest)** and download **`RazerDPI.dmg`**.
2. Open the DMG and drag **`RazerDPI`** into your **`Applications`** folder.
3. Open `RazerDPI.app` from Applications.

> **Note on macOS Security (Gatekeeper):**
> Because this is a free, open-source app distributed without an Apple Developer ID certificate, macOS might show a prompt saying *"cannot be opened because Apple cannot check it for malicious software"* or *"unidentified developer"*.
> - Simply **Right-click (or Control-click)** `RazerDPI.app` in `/Applications` and select **Open**, then click **Open**.
> - Or run this command once in Terminal:
>   ```bash
>   xattr -cr /Applications/RazerDPI.app
>   ```

---

## macOS Permissions (Required)

To communicate directly with the mouse over USB HID, macOS requires **Input Monitoring** permission:
1. When prompted by the app, or in **System Settings → Privacy & Security → Input Monitoring**.
2. Enable the toggle next to **RazerDPI**.
3. Relaunch or click the status icon in your menu bar.

---

## Building from Source

If you prefer building from source:
```bash
git clone https://github.com/<your-username>/razer-dpi-mac.git
cd razer-dpi-mac
./build.sh --install
```
This compiles the native Objective-C / IOKit code and installs `RazerDPI.app` to `/Applications` in about 1 second.

---

## Command-Line Usage (CLI)

The binary can be invoked with flags for headless scripting or terminal control:

```bash
# Check mouse connection, active DPI, and lighting state:
/Applications/RazerDPI.app/Contents/MacOS/RazerDPI --status

# Change DPI sensitivity:
/Applications/RazerDPI.app/Contents/MacOS/RazerDPI --dpi 1600

# Set lighting effect (static, breathing, off):
/Applications/RazerDPI.app/Contents/MacOS/RazerDPI --effect breathing
/Applications/RazerDPI.app/Contents/MacOS/RazerDPI --effect static
/Applications/RazerDPI.app/Contents/MacOS/RazerDPI --effect off

# Set LED brightness percentage (0 - 100):
/Applications/RazerDPI.app/Contents/MacOS/RazerDPI --brightness 75

# Display help:
/Applications/RazerDPI.app/Contents/MacOS/RazerDPI --help
```

---

## Protocol Details (Technical Summary)

- **Vendor ID**: `0x1532` (Razer USA, Ltd.)
- **Product ID**: `0x0098` (Razer DeathAdder Essential 2021)
- **Transport**: macOS IOKit `IOHIDManager` (Report Type: `Feature`, Report ID: `0`, Report Size: `90` bytes).
- **Transaction ID**: `0x1f` for PID `0x0098` (2021 revision).
- **DPI Control**: Command Class `0x04`, Command ID `0x05` (Set) / `0x85` (Get), Data Size `0x07`.
- **Lighting Effects**: Command Class `0x0F`, Command ID `0x02` (Extended Matrix Effect).
- **Brightness**: Command Class `0x0F`, Command ID `0x04` directed to `LOGO_LED` (`0x04`) / `ZERO_LED` (`0x00`).
- **Checksum**: XOR across bytes 2 through 87.

---

## Credits & License

Built leveraging protocol discoveries from [SorcRR/MacRazer](https://github.com/SorcRR/MacRazer) and [OpenRazer](https://github.com/openrazer/openrazer). Licensed under GPL-2.0.
