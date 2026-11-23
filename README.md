# Razer DeathAdder Essential Control for macOS

<p align="center">
  <img src="resources/AppIcon.icns" width="128" height="128" alt="RazerDPI Icon">
</p>

<p align="center">
  <b>A lightweight, native macOS menu bar app and CLI to control DPI and lighting effects on the Razer DeathAdder Essential mouse.</b>
  <br>
  <i>No Razer Synapse, No Electron, No background bloat, No kernel extensions.</i>
</p>

<p align="center">
  <a href="https://github.com/fuelforgamers/razer-deathadder-mac/releases/latest"><img src="https://img.shields.io/github/v/release/fuelforgamers/razer-deathadder-mac?style=flat-square&color=00e700&label=Download" alt="Latest Release"></a>
  <img src="https://img.shields.io/badge/Platform-macOS%2011.0%2B-blue?style=flat-square" alt="macOS 11.0+">
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon%20%2F%20Intel-purple?style=flat-square" alt="Apple Silicon & Intel">
  <img src="https://img.shields.io/badge/License-GPL--2.0-yellow?style=flat-square" alt="License GPL-2.0">
</p>

---

## Why this exists

Razer Synapse 3 does not support macOS, and older versions like Synapse 2 do not recognize modern DeathAdder Essential models (PID `0x0098`). Third-party solutions are often heavy Electron apps or unmaintained command-line scripts.

This utility is:
- **Ultra-lightweight**: Pure native Cocoa & IOKit (~160 KB app bundle, uses < 15 MB of RAM).
- **Instant**: Written in clean native Objective-C with direct USB HID communication.
- **Always Active**: Sits quietly in your menu bar, automatically detects mouse hotplug/reconnection, and restores your preferences immediately.
- **Zero Configuration**: Just drag into Applications and run.

---

## Features

- **DPI Sensitivity Control (200 – 6,400 DPI)**:
  - 1-click instant presets: `400`, `800` (default), `1,600`, `3,200`, `6,400`
  - Continuous slider from `200` to `6,400` DPI
  - Direct numerical text field with immediate hardware sync
  - Hardware readback on launch and reconnection
- **Lighting & Effect Control**:
  - **Static**: Solid iconic Razer green
  - **Breathing**: Pulsating rhythmic fade cycle
  - **Off**: Complete LED blackout (ideal for distractions/night)
  - **Brightness Slider**: 0% to 100% fine-grained hardware brightness
- **Convenience**:
  - Optional **Start at Login** toggle in the Control Panel
  - Both **Menu Bar GUI** and scriptable **CLI flags** in the same binary
  - Settings persisted automatically via macOS defaults

---

## Download & Installation

### Option 1: Pre-built App (Recommended)

1. Download **[RazerDPI.dmg](https://github.com/fuelforgamers/razer-deathadder-mac/releases/latest/download/RazerDPI.dmg)** from the [Releases](https://github.com/fuelforgamers/razer-deathadder-mac/releases/latest) tab.
2. Open the downloaded `.dmg` and drag **RazerDPI** into your **Applications** folder.
3. Open `RazerDPI.app` from Applications or Spotlight.

> [!TIP]
> **macOS Gatekeeper Note:**  
> Because this is a community open-source app distributed without a paid Apple Developer certificate, macOS might show a warning on first launch:
> *"cannot be opened because Apple cannot check it for malicious software"*
> - **Solution**: **Right-click (or Control-click)** `RazerDPI.app` in `/Applications` and select **Open**, then click **Open** in the prompt.
> - Or run this one-liner in Terminal:
>   ```bash
>   xattr -cr /Applications/RazerDPI.app
>   ```

---

## Required Permission (Input Monitoring)

To send direct hardware commands to your mouse without third-party drivers, macOS requires **Input Monitoring** permission:

1. When you first launch the app, a banner will notify you if permission is needed. Click **"Open Settings"**.
2. Or go to: **System Settings → Privacy & Security → Input Monitoring**.
3. Toggle the switch ON for **RazerDPI**.
4. That's it! The app will immediately link with your mouse.

---

## Command-Line Usage (CLI)

The app bundle also functions as a full command-line tool. You can control your mouse from terminal scripts, Alfred workflows, or Raycast:

```bash
# Alias for convenience (optional)
alias razer="/Applications/RazerDPI.app/Contents/MacOS/RazerDPI"

# Check mouse connection, active DPI, and lighting state
razer --status

# Change DPI sensitivity
razer --dpi 1600

# Change lighting effect (static, breathing, off)
razer --effect breathing
razer --effect static
razer --effect off

# Set LED brightness (0 to 100)
razer --brightness 80

# Show help
razer --help
```

---

## Building from Source

Requirements: macOS with Xcode Command Line Tools installed (`xcode-select --install`).

```bash
git clone https://github.com/fuelforgamers/razer-deathadder-mac.git
cd razer-deathadder-mac

# Build and automatically install to /Applications
./build.sh --install

# Or package into a standalone DMG
./package-dmg.sh
```

---

## Troubleshooting & FAQ

<details>
<summary><b>Q: My DPI isn't changing or the app says "Input Monitoring permission required"</b></summary>

macOS blocks low-level USB HID writes unless **Input Monitoring** is granted.
1. Open **System Settings → Privacy & Security → Input Monitoring**.
2. Make sure **RazerDPI** is checked / enabled.
3. If it's already checked, toggle it OFF and back ON once, then click the menu bar icon.
</details>

<details>
<summary><b>Q: Which Razer mice are supported?</b></summary>

This app is tailor-made for the **Razer DeathAdder Essential** (`VID 0x1532`, `PID 0x0098` Black & White 2021 editions, and `PID 0x006e` 2018 edition). It uses the exact 90-byte transaction protocol specified by these models.
</details>

<details>
<summary><b>Q: How do I make it start automatically when my Mac turns on?</b></summary>

Click the **Razer** icon in the menu bar → open the **Control Panel** window → check the box **"Start at Login"**.
</details>

<details>
<summary><b>Q: How do I completely uninstall?</b></summary>

```bash
rm -rf /Applications/RazerDPI.app
rm -f ~/Library/LaunchAgents/com.royce.razer-dpi.plist
defaults delete com.royce.razer-dpi
```
</details>

---

## Technical Protocol Details

- **Vendor ID**: `0x1532` (Razer USA, Ltd.)
- **Product ID**: `0x0098` (Razer DeathAdder Essential 2021)
- **Transport**: IOKit `IOHIDManager` using per-device matching on Mouse usage page `0x01` / usage `0x02`.
- **Packet Format**: 90-byte Feature Report (Report ID 0).
- **Transaction ID**: `0x1f` (PID `0x0098`)
- **DPI Setting**: Class `0x04`, Command `0x05`, Size `0x07` (`NOSTORE 0x00` on `0xff` + `VARSTORE 0x01` on `0x1f`).
- **Lighting**: Class `0x0F`, Command `0x02`, targeted to `LOGO_LED (0x04)`.
- **Brightness**: Class `0x0F`, Command `0x04`.

---

## Credits & License

- Built leveraging reverse-engineered protocol discoveries from [SorcRR/MacRazer](https://github.com/SorcRR/MacRazer) and [OpenRazer](https://github.com/openrazer/openrazer).
- Licensed under [GNU General Public License v2.0 (GPL-2.0)](LICENSE).
