# The Safe Debloat Plan (the thinking behind the utility)

The utility automates this plan. This page is the plain-language version, so anyone can check what the tool does — or do it by hand.

## The rules

1. **Start from an official Windows 11 install.** Never use a ready-made "Tiny11" or similar ISO downloaded from a random site — that is a classic malware route, and it often breaks the Xbox app and Game Pass sign-in.
2. **Restore point first.** Always.
3. **Measure before and after.** Task Manager > Performance > Memory, at the desktop, after a fresh restart. Write both numbers down.
4. **Remove apps, not systems.** The bloat is apps and suggestions. The systems underneath (Update, Defender, Store, Gaming Services) are what keep Game Pass working.

## Remove (safe)

Bing News, Bing Weather, Solitaire Collection, Office Hub, Get Help, Tips, People, Feedback Hub, Windows Maps, Movies & TV, Microsoft To Do, Teams (personal), Clipchamp, Phone Link, Power Automate, Copilot app, Widgets board, and stub shortcuts like Candy Crush / TikTok / Spotify.

## Never touch

| Keep | Why |
|---|---|
| Xbox app, Xbox Game Bar | Your console UI and overlay |
| Gaming Services, Xbox Live services | Game Pass installs and sign-in break without them |
| Microsoft Store + Store Install Service | How Xbox and Gaming Services update |
| Windows Update, BITS | Security patches and downloads |
| Microsoft Defender | Your only antivirus on a clean build |
| .NET, Visual C++ runtimes | Games will not start without them |
| Pagefile | Games crash when it is disabled, it is not "wasted RAM" |

## Background changes that are safe

- Services to Disabled: DiagTrack (telemetry), dmwappushservice, Remote Registry, Retail Demo, Fax. Print Spooler only if the PC will never print.
- Turn off: advertising ID, app suggestions and tips, Widgets, Copilot button, search highlights, background apps you do not use, Game DVR background recording.
- Turn on: Game Mode, hardware-accelerated GPU scheduling (with a real GPU), High Performance power plan while plugged in.

## Boot like a console

1. Settings > Gaming > Full screen experience (newer builds: Xbox mode) → home app = Xbox, "Enter full screen experience on startup" = ON. Restart.
2. Fallback / extra: a logon task that opens the Xbox app (`explorer.exe shell:AppsFolder\<Xbox AppID>` — the utility finds the AppID on your PC with `Get-StartApps`).
3. Skip the lock screen (policy `NoLockScreen`), and for a true console feel, set up Microsoft Sysinternals **Autologon** — only on a living-room PC with no banking or personal files, and understand it means anyone who presses the power button is signed in as you.

## Putting things back (rebloat)

Debloat in the utility removes an app for your user only and keeps the built-in copy on the PC, and every removed app name is saved to `C:\GamingConsoleOS\removed-apps.txt`. So reversal is built in: Tab 5 (Rebloat / Undo) lists the removed apps with tick boxes — tick one and click REBLOAT and the utility re-registers it (or opens its Microsoft Store page). The same tab undoes settings with tick boxes, and System Restore with the "GamingConsoleOS - before changes" point undoes everything at once.

## If something breaks

- A removed app: reinstall it from the Microsoft Store (the utility saves the names in `C:\GamingConsoleOS\removed-apps.txt`).
- Store / Xbox app misbehaving: run `wsreset.exe`, then Store > Library > Get updates.
- Game Pass games will not install: Store > search "Gaming Services" > Repair / reinstall.
- Anything worse: System Restore back to the "before debloat" point, or a clean reinstall of official Windows 11.
