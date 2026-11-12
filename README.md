# Gaming Console OS Utility

Turn a normal Windows 11 mini PC (like a Lenovo Tiny) into a living-room gaming console.

**Power on → no desktop → straight into Xbox.**

One PowerShell file. One window. Tick the boxes you want, click Apply. Built for one job: a Game Pass console PC.

![status](https://img.shields.io/badge/Windows-11-blue) ![powershell](https://img.shields.io/badge/PowerShell-5.1%2B-blue) ![license](https://img.shields.io/badge/License-MIT-green)

## How to run it

Easiest way — nothing to download or save. Open **Terminal** / **Windows PowerShell** (right-click Start), paste this ONE line, and press Enter:

```powershell
irm "https://raw.githubusercontent.com/KishanCodz/PC2GAME_Kizh/main/GamingConsoleOS-Utility.ps1" | iex
```

That pulls the latest version straight from this repo and opens the utility window. If you did not open PowerShell as Admin, the script restarts itself as Admin — just click **Yes** on the Windows prompt.

Or run it from a saved file: download `GamingConsoleOS-Utility.ps1` to the Desktop and run:

```powershell
powershell -STA -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\GamingConsoleOS-Utility.ps1"
```

## What it does

Work through the 5 tabs in order:

### 1. Start Here — system restore point first
Create a system restore point before anything changes. If anything goes wrong later, System Restore puts the whole PC back to that moment. Debloat and Tweaks also ask for a restore point automatically before they run. This tab also checks the Xbox app is ready and shows your RAM use.

### 2. Boot to Xbox (the main one)
Two layers, use both:
- **Official Xbox Mode** — walks you through Settings > Gaming > Full screen experience: set Xbox as your home app and turn on "Enter full screen experience on startup". Windows then boots into the full-screen Xbox shell and holds back background processes (about 1–2 GB of RAM freed vs. the desktop).
- **Fallback launcher (installed by the utility, works on any PC)** — a sign-in task that opens the Xbox app automatically 5 seconds after sign-in, skips the lock screen, and links you to Microsoft's official Autologon tool for password-free sign-in. The utility itself never asks for or stores your password.

### 3. Debloat
Tick the apps to remove — every app is its own tick box, the recommended ones are already ticked, and there are Tick all / Untick all / Tick recommended buttons. The list covers the usual bloat (Bing apps, Solitaire, Clipchamp, Teams personal, Widgets board, Cortana, Dev Home, the new Outlook, stubs like Candy Crush / TikTok / Disney+, and more), plus optional extras that are unticked by default (Netflix, Media Player, Sticky Notes, Clock, Camera, and similar — only tick those if you really do not use them).

Removals are for your user only, and the built-in (provisioned) copy of each app is kept on the PC — that is what makes Tab 5 able to put an app back.

**Protected — this tool will never remove or disable them:** Xbox app, Xbox Game Bar, Gaming Services, Xbox Live services, Microsoft Store, Windows Update, Microsoft Defender, BITS, .NET and Visual C++ runtimes, and the pagefile. Game Pass needs all of them.

### 4. Tweaks
Every tweak is its own tick box: telemetry and other dead services off (each service listed separately, Print Spooler included as an unticked option), Widgets / Copilot button / search highlights off, advertising ID and app suggestions off, Game Mode on, background game recording off, hardware GPU scheduling, High Performance power plan, no sleep while plugged in, stop Edge running in the background, and more.

### 5. Rebloat / Undo — reverse anything
- **Rebloat:** removed apps are listed from the saved record (`C:\GamingConsoleOS\removed-apps.txt`). Tick the ones you want back and click REBLOAT — the utility re-registers the app from the copy kept on the PC, uses winget where it has a known ID, or opens the Microsoft Store page for that app.
- **Undo settings:** tick boxes to put settings back — boot task removed, lock screen back, services back on, buttons and suggestions back, power plan back to Balanced, and more.
- **Full go-back:** one button opens System Restore, where the "GamingConsoleOS - before changes" point undoes everything at once.

Everything the tool does is logged to `C:\GamingConsoleOS\utility-log.txt`.

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
- Made a mistake? Tab 5 (Rebloat / Undo) and System Restore have you covered.

## Roadmap

- [ ] Tab 6 — Install: Steam, Playnite, Epic, RetroArch and more via winget
- [ ] Export / import your tick-box choices as a preset file
- [ ] Controller-first big-picture launcher option (Playnite Fullscreen as home app)

## Credits and disclaimer

Built by Kishan. This is an independent project, not affiliated with Microsoft, Xbox, or Lenovo. Xbox, Windows and Game Pass are trademarks of Microsoft.

## License

MIT — see [LICENSE](LICENSE).
