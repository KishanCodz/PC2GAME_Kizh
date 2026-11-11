# Gaming Console OS Utility

Turn a normal Windows 11 mini PC (like a Lenovo Tiny) into a living-room gaming console.

**Power on → no desktop → straight into Xbox.**

One PowerShell file. One window. Tick boxes, click Apply — the same style as Chris Titus Tech's WinUtil, but built for one job: a Game Pass console PC.

![status](https://img.shields.io/badge/Windows-11-blue) ![powershell](https://img.shields.io/badge/PowerShell-5.1%2B-blue) ![license](https://img.shields.io/badge/License-MIT-green)

## What it does

The utility window has 4 tabs:

### 1. Boot to Xbox (the main one)
Two layers, use both:
- **Official Xbox Mode** — walks you through Settings > Gaming > Full screen experience: set Xbox as your home app and turn on "Enter full screen experience on startup". Windows then boots into the full-screen Xbox shell and holds back background processes (about 1–2 GB of RAM freed vs. the desktop).
- **Fallback launcher (installed by the utility, works on any PC)** — a sign-in task that opens the Xbox app automatically 5 seconds after sign-in, skips the lock screen, and links you to Microsoft's official Autologon tool for password-free sign-in. The utility itself never asks for or stores your password.

### 2. Debloat
Create a restore point, then tick and remove apps from a safe list only (Bing News/Weather, Solitaire, Clipchamp, Teams personal, Widgets board, stubs, and similar).

**Protected — this tool will never remove or disable them:** Xbox app, Xbox Game Bar, Gaming Services, Xbox Live services, Microsoft Store, Windows Update, Microsoft Defender, BITS, .NET and Visual C++ runtimes, and the pagefile. Game Pass needs all of them.

### 3. Tweaks
Telemetry services off, Widgets / Copilot button / app suggestions / advertising ID off, Game Mode on, background game recording off, hardware GPU scheduling, High Performance power plan, stop Edge running in the background, and a few dead services (Remote Registry, Retail Demo, Fax) disabled.

### 4. Undo
Remove the boot task, turn services back on, Balanced power plan back, open System Restore. Everything the tool does is logged to `C:\GamingConsoleOS`, and removed app names are saved there so you can reinstall them from the Microsoft Store.

## How to run it

1. Download `GamingConsoleOS-Utility.ps1` (green **Code** button > Download ZIP, or clone this repo) and put it on the PC's Desktop.
2. Right-click Start > **Terminal (Admin)**.
3. Run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
powershell -STA -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\GamingConsoleOS-Utility.ps1"
```

If you forget Admin, the script restarts itself as Admin. Work through the tabs in order: **Boot to Xbox → Debloat (restore point first) → Tweaks**, then restart and pick up the controller.

## What you need

- Windows 11 (Pro recommended), fully updated
- Xbox app + Gaming Services + Xbox Identity Provider from the Microsoft Store, signed in with your Xbox / Microsoft account
- A PC Game Pass subscription for installed games (console-only games play via Xbox Cloud Gaming)
- Recommended hardware: 16 GB RAM in dual channel (2 sticks), 1 TB NVMe SSD. Most Lenovo Tiny PCs (M720q / M920q) have a weak built-in Intel UHD 630 GPU — a low-profile GPU (RX 6400, RTX 3050 6GB LP, RTX A2000) on the PCIe riser with a 135W power brick makes them real gaming machines.

## Honest numbers

- Stock Windows 11 desktop at idle: ~7.7 GB RAM used
- Xbox Mode / Full Screen Experience: ~5.7 GB
- After this utility's safe debloat + tweaks: roughly 4–4.5 GB on a 16 GB system *(estimate — measure yours with the RAM readout in the tool, before and after)*

This tool will not double your FPS. It gives your games back the RAM and CPU time that background apps were holding, and it makes the PC feel like a console instead of a desktop.

## Safety

- No ready-made Windows ISOs. No ViVeTool / registry hacks to force Xbox Mode — the feature IDs change between builds, it is unsupported, and updates can break it. If the Xbox Mode setting hasn't reached your PC yet, the fallback launcher still boots you straight into Xbox.
- No downloads of code from the internet. No telemetry added. Read the one `.ps1` file yourself — it is the whole tool.
- Made a mistake? Tab 4 (Undo) and System Restore have you covered.

## Roadmap

- [ ] Tab 5 — Install: Steam, Playnite, Epic, RetroArch and more via winget, WinUtil-style
- [ ] Export / import your tick-box choices as a preset file
- [ ] Controller-first big-picture launcher option (Playnite Fullscreen as home app)

## Credits and disclaimer

Built by Kishan. Inspired by the one-window, tick-box style of [Chris Titus Tech's WinUtil](https://github.com/ChrisTitusTech/winutil) — this is an independent project, not affiliated with Chris Titus Tech, Microsoft, Xbox, or Lenovo. Xbox, Windows and Game Pass are trademarks of Microsoft.

## License

MIT — see [LICENSE](LICENSE).
