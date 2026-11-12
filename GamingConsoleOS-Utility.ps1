<#
================================================================================
 Gaming Console OS Utility  v2.1   (one window, tick boxes)
 For: Lenovo Tiny PC as a living-room gaming console - boot straight to Xbox
 Made for: Kishan  |  Updated Nov 12, 2026

 HOW TO RUN  (easiest way - one line, straight from GitHub, nothing to save)
 1. Right-click Start > Terminal / Windows PowerShell (Admin is best,
    but the script restarts itself as Admin if you forget).
 2. Paste this ONE line and press Enter:
        irm "https://raw.githubusercontent.com/KishanCodz/PC2GAME_Kizh/main/GamingConsoleOS-Utility.ps1" | iex
    Click Yes on the Windows Admin prompt, and the utility window opens.

 Or run it from a saved file instead:
        powershell -STA -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\GamingConsoleOS-Utility.ps1"

 THE 5 TABS - WORK IN THIS ORDER
 1. Start Here    - Create a system restore point FIRST. Nothing else until
                    this is done. Also shows your RAM and checks Xbox is ready.
 2. Boot to Xbox  - Power on > no desktop > straight into the Xbox app.
 3. Debloat       - Tick the apps you want gone, click Apply Debloat.
                    (Debloat asks for a restore point first, every time.)
 4. Tweaks        - Tick the gaming / privacy tweaks you want, click Run.
 5. Rebloat / Undo- REVERSE everything: tick removed apps to reinstall them,
                    tick settings to put them back, or use System Restore.

 SAFETY RULES BUILT INTO THIS FILE
 - Xbox app, Xbox Game Bar, Gaming Services, Xbox Live services, Microsoft
   Store, Windows Update, Microsoft Defender, BITS, .NET and Visual C++
   runtimes are PROTECTED. This utility will not remove or disable them -
   Game Pass needs all of them.
 - Debloat removes apps for YOUR user only and keeps the built-in
   (provisioned) copy on the PC, so Rebloat can put an app back.
 - The only thing this file ever downloads is ITSELF, from the GitHub link
   above, when it restarts itself as Admin after the one-line run.
   It never asks for your password.
 - Every change is written to a log in C:\GamingConsoleOS, and removed app
   names are saved there too, so nothing is ever lost.
================================================================================
#>

# --------------------------------------- self-launch: Admin rights + STA mode
# This works BOTH ways the utility is started:
#  - from a saved file (-File, $PSCommandPath has the path), and
#  - straight from GitHub with:  irm "<github raw link>" | iex
#    (iex has NO file path, so the restart downloads this same file again
#     from Kishan's own GitHub, inside the new Admin window.)
$ScriptUrl = 'https://raw.githubusercontent.com/KishanCodz/PC2GAME_Kizh/main/GamingConsoleOS-Utility.ps1'
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isSTA = ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA')
if (-not $isAdmin -or -not $isSTA) {
    $argList = '-STA -NoProfile -ExecutionPolicy Bypass'
    if ($PSCommandPath) {
        $argList += (' -File "{0}"' -f $PSCommandPath)
    } else {
        $argList += (' -Command "irm ''{0}'' | iex"' -f $ScriptUrl)
    }
    try {
        if ($isAdmin) {
            Start-Process -FilePath 'powershell.exe' -ArgumentList $argList
        } else {
            Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
        }
        Write-Host 'Restarting as Admin - click Yes on the Windows prompt, the utility window will open there.'
    } catch {
        Write-Host 'Please right-click Start > Terminal (Admin), then paste the run line from the top of this file.'
    }
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$ErrorActionPreference = 'Continue'

# ------------------------------------------------------------ folders / files
$WorkDir    = 'C:\GamingConsoleOS'
$LogFile    = Join-Path $WorkDir 'utility-log.txt'
$RemovedTxt = Join-Path $WorkDir 'removed-apps.txt'
if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null }

# ------------------------------------------------------------ helper functions
$script:LogBox = $null
$script:RestoreDone = $false
function Log {
    param([string]$Text)
    $line = ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Text)
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
    if ($script:LogBox) {
        $script:LogBox.AppendText($line + [Environment]::NewLine)
        $script:LogBox.ScrollToCaret()
    }
}

function Set-Reg {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        Log "Set registry: $Path\$Name = $Value"
    } catch { Log "Registry FAILED: $Path\$Name - $($_.Exception.Message)" }
}

function Remove-RegValue {
    param([string]$Path, [string]$Name)
    try {
        if (Test-Path $Path) {
            Remove-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
            Log "Removed registry value: $Path\$Name"
        }
    } catch { Log "Registry value not present (ok): $Path\$Name" }
}

function Set-ServiceStart {
    param([string]$Name, [string]$Mode)
    try {
        $svc = Get-Service -Name $Name -ErrorAction Stop
        Set-Service -Name $Name -StartupType $Mode -ErrorAction Stop
        Log "Service $Name ($($svc.DisplayName)) startup set to $Mode"
    } catch { Log "Service not found / not changed: $Name" }
}

function New-RestorePoint {
    try {
        Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'GamingConsoleOS - before changes' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        $script:RestoreDone = $true
        Log 'Restore point created: "GamingConsoleOS - before changes".'
        return $true
    } catch {
        Log "Restore point not created: $($_.Exception.Message) (Windows allows one restore point per 24 hours - an earlier one may already cover you.)"
        return $false
    }
}

function Ensure-RestorePoint {
    # Called before Debloat and before Tweaks. Returns $true = go ahead.
    if ($script:RestoreDone) { return $true }
    if (-not $chkAutoRP.Checked) {
        Log 'Restore point skipped by your choice (auto restore point is unticked on Tab 1).'
        return $true
    }
    Log 'No restore point yet in this session - creating one first...'
    if (New-RestorePoint) { return $true }
    $ans = [System.Windows.Forms.MessageBox]::Show(
        'A new restore point could not be created (Windows allows one per 24 hours, so an earlier one may already exist). Continue anyway?',
        'Gaming Console OS', 'YesNo', 'Warning')
    return ($ans -eq 'Yes')
}

$Protected = @('*Xbox*','*GamingApp*','*GamingServices*','*WindowsStore*','*StorePurchaseApp*',
               '*SecHealthUI*','*DesktopAppInstaller*','*WindowsTerminal*','*MicrosoftEdge*')

function Remove-SafeApp {
    param([string]$Pattern, [string]$Friendly)
    foreach ($p in $Protected) {
        if ($Pattern -like $p) { Log "PROTECTED - refused: $Friendly"; return }
    }
    $pkgs = Get-AppxPackage -Name $Pattern -ErrorAction SilentlyContinue
    if (-not $pkgs) {
        Log "Not installed for this user: $Friendly (nothing removed)"
        return
    }
    foreach ($pkg in $pkgs) {
        # Save the name BEFORE removing, so Rebloat knows what to put back.
        $already = $false
        if (Test-Path $RemovedTxt) {
            $already = [bool](Get-Content $RemovedTxt | Where-Object { $_ -like "$($pkg.Name)|*" })
        }
        if (-not $already) {
            Add-Content -Path $RemovedTxt -Value "$($pkg.Name)|$Friendly" -ErrorAction SilentlyContinue
        }
        try {
            # Current user only, and the provisioned copy is KEPT on purpose -
            # that is what makes Rebloat (Tab 5) able to restore the app.
            Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
            Log "Removed: $Friendly (provisioned copy kept - Rebloat can restore it)"
        } catch { Log "Could not remove $Friendly - $($_.Exception.Message)" }
    }
}

$WingetIds = @{
    'SpotifyAB.SpotifyMusic' = 'Spotify.Spotify'
}

function Restore-App {
    param([string]$Name, [string]$Friendly)
    # 1) Best way: the package files are still on the PC - re-register the app.
    $pkg = Get-AppxPackage -AllUsers -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pkg -and $pkg.InstallLocation -and (Test-Path (Join-Path $pkg.InstallLocation 'AppXManifest.xml'))) {
        try {
            Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $pkg.InstallLocation 'AppXManifest.xml') -ErrorAction Stop
            Log "Rebloated (re-registered): $Friendly"
            return
        } catch { Log "Re-register failed for $Friendly - $($_.Exception.Message)" }
    }
    # 2) winget, for the few apps with a known winget ID.
    if ($WingetIds.ContainsKey($Name)) {
        try {
            winget install --id $WingetIds[$Name] --exact --silent --accept-package-agreements --accept-source-agreements | Out-Null
            Log "Rebloated (winget): $Friendly"
            return
        } catch { Log "winget failed for $Friendly - $($_.Exception.Message)" }
    }
    # 3) Fallback: open the Microsoft Store search so one click installs it.
    Start-Process ("ms-windows-store://search/?query=" + [uri]::EscapeDataString($Friendly))
    Log "Opened Microsoft Store search for: $Friendly - click Install/Get there to finish the rebloat."
}

function Get-XboxAppId {
    # Find the real launch ID on THIS pc instead of trusting a hard-coded one.
    $app = Get-StartApps | Where-Object { $_.Name -eq 'Xbox' } | Select-Object -First 1
    if ($app) { return $app.AppID }
    return 'Microsoft.GamingApp_8wekyb3d8bbwe!Microsoft.Xbox.App'
}

function Show-RamNow {
    $os   = Get-CimInstance Win32_OperatingSystem
    $tot  = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $free = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $used = [math]::Round($tot - $free, 2)
    Log "RAM now: total $tot GB | used $used GB | free $free GB | processes: $((Get-Process).Count)"
}

function Check-XboxReady {
    $os = Get-CimInstance Win32_OperatingSystem
    Log "Windows: $($os.Caption) build $($os.BuildNumber)"
    foreach ($n in @('Microsoft.GamingApp','Microsoft.GamingServices','Microsoft.XboxIdentityProvider','Microsoft.XboxGamingOverlay')) {
        $p = Get-AppxPackage -Name $n -ErrorAction SilentlyContinue
        if ($p) { Log "OK - $n  version $($p.Version)" } else { Log "MISSING - $n  (install/update it from Microsoft Store)" }
    }
    Log "Xbox launch ID on this PC: $(Get-XboxAppId)"
    Show-RamNow
}

# ------------------------------------------------------------ debloat app list
# R = $true means "recommended" - ticked by default. Everything else is an
# option you can tick yourself. Protected apps are never listed here.
$DebloatApps = @(
    @{ P = 'Microsoft.BingNews';                     F = 'Bing News';                              R = $true },
    @{ P = 'Microsoft.BingWeather';                  F = 'Bing Weather';                           R = $true },
    @{ P = 'Microsoft.BingSearch';                   F = 'Web Search from Microsoft (Bing Search)'; R = $true },
    @{ P = 'Microsoft.BingFinance';                  F = 'Bing Finance (old app, if present)';      R = $true },
    @{ P = 'Microsoft.BingSports';                   F = 'Bing Sports (old app, if present)';       R = $true },
    @{ P = 'Microsoft.BingTravel';                   F = 'Bing Travel (old app, if present)';       R = $true },
    @{ P = 'Microsoft.BingHealthAndFitness';         F = 'Bing Health (old app, if present)';       R = $true },
    @{ P = 'Microsoft.BingFoodAndDrink';             F = 'Bing Food and Drink (old app, if present)'; R = $true },
    @{ P = 'Microsoft.MicrosoftSolitaireCollection'; F = 'Solitaire Collection';                    R = $true },
    @{ P = 'Microsoft.MicrosoftOfficeHub';           F = 'Office Hub / Microsoft 365 app';          R = $true },
    @{ P = 'Microsoft.GetHelp';                      F = 'Get Help';                                R = $true },
    @{ P = 'Microsoft.Getstarted';                   F = 'Tips / Get Started';                      R = $true },
    @{ P = 'Microsoft.People';                       F = 'People';                                  R = $true },
    @{ P = 'Microsoft.WindowsFeedbackHub';           F = 'Feedback Hub';                            R = $true },
    @{ P = 'Microsoft.WindowsMaps';                  F = 'Windows Maps';                            R = $true },
    @{ P = 'Microsoft.ZuneVideo';                    F = 'Movies and TV';                           R = $true },
    @{ P = 'Microsoft.Todos';                        F = 'Microsoft To Do';                         R = $true },
    @{ P = 'MicrosoftTeams';                         F = 'Teams (personal)';                        R = $true },
    @{ P = 'Microsoft.SkypeApp';                     F = 'Skype';                                   R = $true },
    @{ P = 'Microsoft.Messaging';                    F = 'Messaging';                               R = $true },
    @{ P = 'Microsoft.OneConnect';                   F = 'Mobile Plans';                            R = $true },
    @{ P = 'Microsoft.Print3D';                      F = 'Print 3D';                                R = $true },
    @{ P = 'Microsoft.MixedReality.Portal';          F = 'Mixed Reality Portal';                    R = $true },
    @{ P = 'Clipchamp.Clipchamp';                    F = 'Clipchamp video editor';                  R = $true },
    @{ P = 'Microsoft.YourPhone';                    F = 'Phone Link';                              R = $true },
    @{ P = 'Microsoft.PowerAutomateDesktop';         F = 'Power Automate';                          R = $true },
    @{ P = 'Microsoft.Copilot';                      F = 'Copilot app';                             R = $true },
    @{ P = 'MicrosoftWindows.Client.WebExperience';  F = 'Widgets board (news / weather panel)';    R = $true },
    @{ P = 'Microsoft.549981C3F5F10';                F = 'Cortana';                                 R = $true },
    @{ P = 'Microsoft.Windows.DevHome';              F = 'Dev Home (developer tool)';               R = $true },
    @{ P = 'Microsoft.OutlookForWindows';            F = 'Outlook (new mail app)';                  R = $true },
    @{ P = '*CandyCrush*';                           F = 'Candy Crush stub';                        R = $true },
    @{ P = '*TikTok*';                               F = 'TikTok stub';                             R = $true },
    @{ P = '*Disney*';                               F = 'Disney+ stub';                            R = $true },
    @{ P = 'SpotifyAB.SpotifyMusic';                 F = 'Spotify stub (reinstall real Spotify if you use it)'; R = $true },
    @{ P = '*Netflix*';                              F = 'Netflix stub / app (only if you do not watch here)'; R = $false },
    @{ P = 'Microsoft.ZuneMusic';                    F = 'Media Player (only if you never play local music/video)'; R = $false },
    @{ P = 'Microsoft.MicrosoftStickyNotes';         F = 'Sticky Notes (only if you never use it)'; R = $false },
    @{ P = 'Microsoft.WindowsAlarms';                F = 'Clock / Alarms (only if you never use it)'; R = $false },
    @{ P = 'Microsoft.WindowsSoundRecorder';         F = 'Voice Recorder (only if you never use it)'; R = $false },
    @{ P = 'Microsoft.WindowsCamera';                F = 'Camera (only if this PC has no camera use)'; R = $false },
    @{ P = 'Microsoft.MSPaint';                      F = 'Paint 3D (old app, if present)';          R = $false },
    @{ P = 'Microsoft.Wallet';                       F = 'Microsoft Wallet (only if you never use it)'; R = $false }
)

# ------------------------------------------------------------ the window
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Gaming Console OS Utility v2.1 - Boot Straight to Xbox'
$form.Size = New-Object System.Drawing.Size(920, 790)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$header = New-Object System.Windows.Forms.Label
$header.Text = 'Work in tab order: 1 Restore Point, 2 Boot to Xbox, 3 Debloat, 4 Tweaks - and Tab 5 (Rebloat / Undo) reverses anything. Xbox / Game Pass / Store / Defender / Update are protected.'
$header.Location = New-Object System.Drawing.Point(10, 8)
$header.Size = New-Object System.Drawing.Size(880, 30)
$form.Controls.Add($header)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(10, 42)
$tabs.Size = New-Object System.Drawing.Size(880, 520)
$form.Controls.Add($tabs)

$tabStart   = New-Object System.Windows.Forms.TabPage; $tabStart.Text   = '1. Start Here'
$tabBoot    = New-Object System.Windows.Forms.TabPage; $tabBoot.Text    = '2. Boot to Xbox'
$tabDebloat = New-Object System.Windows.Forms.TabPage; $tabDebloat.Text = '3. Debloat'
$tabTweaks  = New-Object System.Windows.Forms.TabPage; $tabTweaks.Text  = '4. Tweaks'
$tabUndo    = New-Object System.Windows.Forms.TabPage; $tabUndo.Text    = '5. Rebloat / Undo'
$tabs.TabPages.AddRange(@($tabStart, $tabBoot, $tabDebloat, $tabTweaks, $tabUndo))

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location = New-Object System.Drawing.Point(10, 570)
$logBox.Size = New-Object System.Drawing.Size(880, 165)
$logBox.ReadOnly = $true
$form.Controls.Add($logBox)
$script:LogBox = $logBox

# ================================================================ TAB 1: START HERE
$lblStart = New-Object System.Windows.Forms.Label
$lblStart.Text = "STEP 1 - CREATE A SYSTEM RESTORE POINT FIRST. Before any debloat or tweak.`r`nIf anything goes wrong later, System Restore puts the whole PC back to this moment.`r`nDebloat and Tweaks will also ask for a restore point automatically before they run."
$lblStart.Location = New-Object System.Drawing.Point(10, 10)
$lblStart.Size = New-Object System.Drawing.Size(850, 55)
$tabStart.Controls.Add($lblStart)

$btnRestoreFirst = New-Object System.Windows.Forms.Button
$btnRestoreFirst.Text = 'CREATE SYSTEM RESTORE POINT'
$btnRestoreFirst.Location = New-Object System.Drawing.Point(10, 75)
$btnRestoreFirst.Size = New-Object System.Drawing.Size(340, 45)
$btnRestoreFirst.BackColor = [System.Drawing.Color]::LightGreen
$btnRestoreFirst.Add_Click({
    if (New-RestorePoint) {
        [System.Windows.Forms.MessageBox]::Show('Restore point created. You are safe to continue to Tab 2.', 'Gaming Console OS')
    } else {
        [System.Windows.Forms.MessageBox]::Show('A new restore point was not created - Windows allows one per 24 hours, so an earlier one may already cover you. See the log below.', 'Gaming Console OS')
    }
    Show-RamNow
})
$tabStart.Controls.Add($btnRestoreFirst)

$chkAutoRP = New-Object System.Windows.Forms.CheckBox
$chkAutoRP.Text = 'Automatically create a restore point before Debloat and Tweaks run (recommended)'
$chkAutoRP.Location = New-Object System.Drawing.Point(10, 135); $chkAutoRP.Size = New-Object System.Drawing.Size(850, 22)
$chkAutoRP.Checked = $true
$tabStart.Controls.Add($chkAutoRP)

$grpHow = New-Object System.Windows.Forms.GroupBox
$grpHow.Text = 'How you opened this window (for next time)'
$grpHow.Location = New-Object System.Drawing.Point(10, 170)
$grpHow.Size = New-Object System.Drawing.Size(850, 105)
$tabStart.Controls.Add($grpHow)

$txtHow = New-Object System.Windows.Forms.TextBox
$txtHow.Multiline = $true; $txtHow.ReadOnly = $true
$txtHow.Location = New-Object System.Drawing.Point(10, 20)
$txtHow.Size = New-Object System.Drawing.Size(830, 75)
$txtHow.Text = "Right-click Start > Terminal (Admin), then paste:`r`n   powershell -STA -ExecutionPolicy Bypass -File `"$env:USERPROFILE\Desktop\GamingConsoleOS-Utility.ps1`"`r`nChange the path if you saved the file somewhere else. Forgot Admin? The script restarts itself as Admin."
$grpHow.Controls.Add($txtHow)

$btnCheckStart = New-Object System.Windows.Forms.Button
$btnCheckStart.Text = 'Check Xbox is ready + show RAM'
$btnCheckStart.Location = New-Object System.Drawing.Point(10, 290); $btnCheckStart.Size = New-Object System.Drawing.Size(280, 35)
$btnCheckStart.Add_Click({ Check-XboxReady })
$tabStart.Controls.Add($btnCheckStart)

$btnOpenLog = New-Object System.Windows.Forms.Button
$btnOpenLog.Text = 'Open the log + removed-apps folder'
$btnOpenLog.Location = New-Object System.Drawing.Point(300, 290); $btnOpenLog.Size = New-Object System.Drawing.Size(280, 35)
$btnOpenLog.Add_Click({ Start-Process 'explorer.exe' -ArgumentList $WorkDir })
$tabStart.Controls.Add($btnOpenLog)

$lblOrder = New-Object System.Windows.Forms.Label
$lblOrder.Text = "Order to work in:  Tab 1 restore point  >  Tab 2 Boot to Xbox  >  Tab 3 Debloat (tick + Apply)  >  Tab 4 Tweaks (tick + Run)  >  restart and test with the controller.`r`nChanged your mind about anything? Tab 5 puts it back."
$lblOrder.Location = New-Object System.Drawing.Point(10, 340); $lblOrder.Size = New-Object System.Drawing.Size(850, 40)
$tabStart.Controls.Add($lblOrder)

# ================================================================ TAB 2: BOOT TO XBOX
$lblBoot = New-Object System.Windows.Forms.Label
$lblBoot.Text = "There are 2 layers. Use BOTH and this Tiny PC feels like a real console:`r`nA) Official Xbox Mode - Windows boots into the full-screen Xbox shell and holds back background processes.`r`nB) Fallback launcher (this utility installs it) - works on every PC: sign-in goes straight to the Xbox app."
$lblBoot.Location = New-Object System.Drawing.Point(10, 10)
$lblBoot.Size = New-Object System.Drawing.Size(850, 55)
$tabBoot.Controls.Add($lblBoot)

$grpA = New-Object System.Windows.Forms.GroupBox
$grpA.Text = 'A - Official Xbox Mode (Full Screen Experience)'
$grpA.Location = New-Object System.Drawing.Point(10, 70)
$grpA.Size = New-Object System.Drawing.Size(850, 150)
$tabBoot.Controls.Add($grpA)

$txtA = New-Object System.Windows.Forms.TextBox
$txtA.Multiline = $true; $txtA.ReadOnly = $true; $txtA.ScrollBars = 'Vertical'
$txtA.Location = New-Object System.Drawing.Point(10, 20)
$txtA.Size = New-Object System.Drawing.Size(830, 80)
$txtA.Text = "Do this once, by hand - Microsoft gives no safe script switch for it:`r`n1. Settings > Windows Update - install everything, restart.`r`n2. Microsoft Store - update the Xbox app.`r`n3. Settings > Gaming > Full screen experience (newer builds call it Xbox mode).`r`n4. Set your home app = Xbox.  5. Turn ON 'Enter full screen experience on startup'.  6. Restart.`r`nIn Xbox Mode: Win+F11 or Win+Tab = back to desktop, Xbox button / Win+G = Game Bar.`r`nIf the setting is missing, your build/region has not got the rollout yet - use Layer B below. Do NOT use ViVeTool / registry hacks to force it: the feature IDs change between builds, it is unsupported, and updates can break it."
$grpA.Controls.Add($txtA)

$btnSettings = New-Object System.Windows.Forms.Button
$btnSettings.Text = 'Open Settings > Gaming'
$btnSettings.Location = New-Object System.Drawing.Point(10, 110)
$btnSettings.Size = New-Object System.Drawing.Size(220, 30)
$btnSettings.Add_Click({ Start-Process 'ms-settings:gaming'; Log 'Opened Settings > Gaming. Look for: Full screen experience / Xbox mode.' })
$grpA.Controls.Add($btnSettings)

$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = 'Check Xbox is ready'
$btnCheck.Location = New-Object System.Drawing.Point(240, 110)
$btnCheck.Size = New-Object System.Drawing.Size(220, 30)
$btnCheck.Add_Click({ Check-XboxReady })
$grpA.Controls.Add($btnCheck)

$grpB = New-Object System.Windows.Forms.GroupBox
$grpB.Text = 'B - Boot Straight to Xbox (installed by this utility, works on any PC)'
$grpB.Location = New-Object System.Drawing.Point(10, 230)
$grpB.Size = New-Object System.Drawing.Size(850, 235)
$tabBoot.Controls.Add($grpB)

$chkAutoXbox = New-Object System.Windows.Forms.CheckBox
$chkAutoXbox.Text = 'Auto-open the Xbox app at sign-in (scheduled task, 5 seconds after sign-in)'
$chkAutoXbox.Location = New-Object System.Drawing.Point(15, 25); $chkAutoXbox.Size = New-Object System.Drawing.Size(820, 22)
$chkAutoXbox.Checked = $true
$grpB.Controls.Add($chkAutoXbox)

$chkNoLock = New-Object System.Windows.Forms.CheckBox
$chkNoLock.Text = 'Skip the lock screen (power on goes straight to sign-in, no photo screen to click past)'
$chkNoLock.Location = New-Object System.Drawing.Point(15, 50); $chkNoLock.Size = New-Object System.Drawing.Size(820, 22)
$chkNoLock.Checked = $true
$grpB.Controls.Add($chkNoLock)

$chkHideIcons = New-Object System.Windows.Forms.CheckBox
$chkHideIcons.Text = 'Hide desktop icons (clean TV look - files are not deleted, icons are just hidden)'
$chkHideIcons.Location = New-Object System.Drawing.Point(15, 75); $chkHideIcons.Size = New-Object System.Drawing.Size(820, 22)
$chkHideIcons.Checked = $false
$grpB.Controls.Add($chkHideIcons)

$lblAuto = New-Object System.Windows.Forms.Label
$lblAuto.Text = "For true 'power on, no password, straight in' you also need auto sign-in. This utility will NOT ask for or store your password. Use Microsoft's own free Autologon tool (button below) - it stores the password protected, and holding Shift at boot skips it once."
$lblAuto.Location = New-Object System.Drawing.Point(15, 105); $lblAuto.Size = New-Object System.Drawing.Size(820, 40)
$grpB.Controls.Add($lblAuto)

$btnAutologon = New-Object System.Windows.Forms.Button
$btnAutologon.Text = 'Get Microsoft Autologon (official page)'
$btnAutologon.Location = New-Object System.Drawing.Point(15, 150); $btnAutologon.Size = New-Object System.Drawing.Size(300, 30)
$btnAutologon.Add_Click({
    Start-Process 'https://learn.microsoft.com/en-us/sysinternals/downloads/autologon'
    Log 'Opened the official Microsoft Sysinternals Autologon page. Download it, run Autologon64.exe as Admin, type your Windows password once, click Enable. Only use auto sign-in on a living-room console PC with no banking or personal files.'
})
$grpB.Controls.Add($btnAutologon)

$btnApplyBoot = New-Object System.Windows.Forms.Button
$btnApplyBoot.Text = 'APPLY - Boot Straight to Xbox'
$btnApplyBoot.Location = New-Object System.Drawing.Point(15, 190); $btnApplyBoot.Size = New-Object System.Drawing.Size(300, 35)
$btnApplyBoot.BackColor = [System.Drawing.Color]::LightGreen
$btnApplyBoot.Add_Click({
    if ($chkAutoXbox.Checked) {
        try {
            $appId = Get-XboxAppId
            $action  = New-ScheduledTaskAction -Execute 'explorer.exe' -Argument ("shell:AppsFolder\" + $appId)
            $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
            $trigger.Delay = 'PT5S'
            $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
            Register-ScheduledTask -TaskName 'GamingConsoleOS-BootToXbox' -Action $action -Trigger $trigger `
                -Settings $set -Description 'Gaming Console OS: open Xbox app at sign-in' -Force | Out-Null
            Log "Boot task installed: sign-in now opens Xbox automatically ($appId)"
        } catch { Log "Boot task FAILED - $($_.Exception.Message)" }
    }
    if ($chkNoLock.Checked) {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' 'NoLockScreen' 1
    }
    if ($chkHideIcons.Checked) {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideIcons' 1
        Log 'Desktop icons will hide after restart / Explorer restart.'
    }
    Log 'BOOT SETUP DONE. Next: 1) set Xbox as home app in Settings (Layer A), 2) run Autologon once, 3) restart and test with the controller.'
    [System.Windows.Forms.MessageBox]::Show('Boot-to-Xbox applied. Restart the PC to test it.', 'Gaming Console OS')
})
$grpB.Controls.Add($btnApplyBoot)

$btnTestXbox = New-Object System.Windows.Forms.Button
$btnTestXbox.Text = 'Test now - open Xbox'
$btnTestXbox.Location = New-Object System.Drawing.Point(330, 190); $btnTestXbox.Size = New-Object System.Drawing.Size(220, 35)
$btnTestXbox.Add_Click({
    $appId = Get-XboxAppId
    Start-Process 'explorer.exe' -ArgumentList ("shell:AppsFolder\" + $appId)
    Log "Launched Xbox for a test: $appId"
})
$grpB.Controls.Add($btnTestXbox)

# ================================================================ TAB 3: DEBLOAT
$lblDeb = New-Object System.Windows.Forms.Label
$lblDeb.Text = "Tick the apps to remove, then click APPLY DEBLOAT. Recommended apps are already ticked; untick anything you use.`r`nXbox, Game Bar, Gaming Services, Store, Edge, Terminal, Calculator, Notepad, Paint, Photos and Snipping Tool are protected and are NOT in this list. Removals are for your user only, and the built-in copy is kept - Tab 5 can put any app back."
$lblDeb.Location = New-Object System.Drawing.Point(10, 10); $lblDeb.Size = New-Object System.Drawing.Size(850, 55)
$tabDebloat.Controls.Add($lblDeb)

$lstDebloat = New-Object System.Windows.Forms.CheckedListBox
$lstDebloat.Location = New-Object System.Drawing.Point(10, 70); $lstDebloat.Size = New-Object System.Drawing.Size(850, 310)
$lstDebloat.CheckOnClick = $true
foreach ($a in $DebloatApps) { [void]$lstDebloat.Items.Add($a.F, [bool]$a.R) }
$tabDebloat.Controls.Add($lstDebloat)

$btnDebRecommended = New-Object System.Windows.Forms.Button
$btnDebRecommended.Text = 'Tick recommended'
$btnDebRecommended.Location = New-Object System.Drawing.Point(10, 395); $btnDebRecommended.Size = New-Object System.Drawing.Size(150, 35)
$btnDebRecommended.Add_Click({ for ($i = 0; $i -lt $lstDebloat.Items.Count; $i++) { $lstDebloat.SetItemChecked($i, [bool]$DebloatApps[$i].R) } })
$tabDebloat.Controls.Add($btnDebRecommended)

$btnDebAll = New-Object System.Windows.Forms.Button
$btnDebAll.Text = 'Tick all'
$btnDebAll.Location = New-Object System.Drawing.Point(170, 395); $btnDebAll.Size = New-Object System.Drawing.Size(110, 35)
$btnDebAll.Add_Click({ for ($i = 0; $i -lt $lstDebloat.Items.Count; $i++) { $lstDebloat.SetItemChecked($i, $true) } })
$tabDebloat.Controls.Add($btnDebAll)

$btnDebNone = New-Object System.Windows.Forms.Button
$btnDebNone.Text = 'Untick all'
$btnDebNone.Location = New-Object System.Drawing.Point(290, 395); $btnDebNone.Size = New-Object System.Drawing.Size(110, 35)
$btnDebNone.Add_Click({ for ($i = 0; $i -lt $lstDebloat.Items.Count; $i++) { $lstDebloat.SetItemChecked($i, $false) } })
$tabDebloat.Controls.Add($btnDebNone)

$btnApplyDebloat = New-Object System.Windows.Forms.Button
$btnApplyDebloat.Text = 'APPLY DEBLOAT'
$btnApplyDebloat.Location = New-Object System.Drawing.Point(560, 395); $btnApplyDebloat.Size = New-Object System.Drawing.Size(240, 35)
$btnApplyDebloat.BackColor = [System.Drawing.Color]::LightGreen
$btnApplyDebloat.Add_Click({
    if (-not (Ensure-RestorePoint)) { Log 'Debloat stopped - no restore point. Create one on Tab 1 first.'; return }
    Log '--- Debloat started ---'
    foreach ($idx in $lstDebloat.CheckedIndices) {
        $app = $DebloatApps[$idx]
        Remove-SafeApp -Pattern $app.P -Friendly $app.F
    }
    Show-RamNow
    Log '--- Debloat finished. Restart, then check the Xbox app still signs in and a Game Pass game still installs. Removed apps are listed in C:\GamingConsoleOS\removed-apps.txt and can be put back on Tab 5. ---'
})
$tabDebloat.Controls.Add($btnApplyDebloat)

# ================================================================ TAB 4: TWEAKS
$lblTwk = New-Object System.Windows.Forms.Label
$lblTwk.Text = "Tick each tweak you want - every tweak is its own tick box - then click RUN TWEAKS. Recommended ones are already ticked.`r`nNothing here touches Defender, Windows Update, the Store, Xbox services or the pagefile. Every tweak can be reversed on Tab 5."
$lblTwk.Location = New-Object System.Drawing.Point(10, 10); $lblTwk.Size = New-Object System.Drawing.Size(850, 40)
$tabTweaks.Controls.Add($lblTwk)

# R = recommended (ticked by default)
$Tweaks = @(
    @{ F = 'Disable telemetry service (DiagTrack)';                                   R = $true;  Id = 'SvcDiagTrack' },
    @{ F = 'Disable connected-user / push service (dmwappushservice)';                R = $true;  Id = 'SvcDmwap' },
    @{ F = 'Disable Remote Registry service';                                         R = $true;  Id = 'SvcRemoteReg' },
    @{ F = 'Disable Retail Demo service';                                             R = $true;  Id = 'SvcRetailDemo' },
    @{ F = 'Disable Fax service';                                                     R = $true;  Id = 'SvcFax' },
    @{ F = 'Disable Downloaded Maps Manager service (MapsBroker)';                    R = $true;  Id = 'SvcMapsBroker' },
    @{ F = 'Disable Print Spooler service (only if this console will NEVER print)';   R = $false; Id = 'SvcSpooler' },
    @{ F = 'Turn off the Widgets button on the taskbar';                              R = $true;  Id = 'WidgetsOff' },
    @{ F = 'Turn off the Copilot button + Copilot policy off';                        R = $true;  Id = 'CopilotOff' },
    @{ F = 'Turn off search highlights (the picture in the search box)';              R = $true;  Id = 'SearchHighlightsOff' },
    @{ F = 'Turn off advertising ID';                                                 R = $true;  Id = 'AdIdOff' },
    @{ F = 'Turn off app suggestions, Start menu ads and tips';                       R = $true;  Id = 'SuggestionsOff' },
    @{ F = 'Turn off tailored experiences (personalised tips from your data)';        R = $true;  Id = 'TailoredOff' },
    @{ F = 'Turn off Windows consumer features (auto-installed sponsored apps)';      R = $true;  Id = 'ConsumerFeaturesOff' },
    @{ F = 'Game Mode ON';                                                            R = $true;  Id = 'GameModeOn' },
    @{ F = 'Turn off background game recording (Game DVR capture)';                   R = $true;  Id = 'GameDvrOff' },
    @{ F = 'Hardware GPU scheduling ON (needs a restart, best with a real GPU)';      R = $true;  Id = 'GpuSchedOn' },
    @{ F = 'High Performance power plan';                                             R = $true;  Id = 'HighPerf' },
    @{ F = 'Never sleep or hibernate while plugged in';                               R = $true;  Id = 'NoSleep' },
    @{ F = 'Stop Microsoft Edge running in the background (startup boost off)';       R = $true;  Id = 'EdgeBgOff' },
    @{ F = 'Stop OneDrive starting at sign-in (does not delete your files)';          R = $false; Id = 'OneDriveOff' }
)
$lstTweaks = New-Object System.Windows.Forms.CheckedListBox
$lstTweaks.Location = New-Object System.Drawing.Point(10, 55); $lstTweaks.Size = New-Object System.Drawing.Size(850, 320)
$lstTweaks.CheckOnClick = $true
foreach ($t in $Tweaks) { [void]$lstTweaks.Items.Add($t.F, [bool]$t.R) }
$tabTweaks.Controls.Add($lstTweaks)

$btnTwkRecommended = New-Object System.Windows.Forms.Button
$btnTwkRecommended.Text = 'Tick recommended'
$btnTwkRecommended.Location = New-Object System.Drawing.Point(10, 390); $btnTwkRecommended.Size = New-Object System.Drawing.Size(150, 35)
$btnTwkRecommended.Add_Click({ for ($i = 0; $i -lt $lstTweaks.Items.Count; $i++) { $lstTweaks.SetItemChecked($i, [bool]$Tweaks[$i].R) } })
$tabTweaks.Controls.Add($btnTwkRecommended)

$btnTwkAll = New-Object System.Windows.Forms.Button
$btnTwkAll.Text = 'Tick all'
$btnTwkAll.Location = New-Object System.Drawing.Point(170, 390); $btnTwkAll.Size = New-Object System.Drawing.Size(110, 35)
$btnTwkAll.Add_Click({ for ($i = 0; $i -lt $lstTweaks.Items.Count; $i++) { $lstTweaks.SetItemChecked($i, $true) } })
$tabTweaks.Controls.Add($btnTwkAll)

$btnTwkNone = New-Object System.Windows.Forms.Button
$btnTwkNone.Text = 'Untick all'
$btnTwkNone.Location = New-Object System.Drawing.Point(290, 390); $btnTwkNone.Size = New-Object System.Drawing.Size(110, 35)
$btnTwkNone.Add_Click({ for ($i = 0; $i -lt $lstTweaks.Items.Count; $i++) { $lstTweaks.SetItemChecked($i, $false) } })
$tabTweaks.Controls.Add($btnTwkNone)

$btnRunTweaks = New-Object System.Windows.Forms.Button
$btnRunTweaks.Text = 'RUN TWEAKS'
$btnRunTweaks.Location = New-Object System.Drawing.Point(560, 390); $btnRunTweaks.Size = New-Object System.Drawing.Size(240, 35)
$btnRunTweaks.BackColor = [System.Drawing.Color]::LightGreen
$btnRunTweaks.Add_Click({
    if (-not (Ensure-RestorePoint)) { Log 'Tweaks stopped - no restore point. Create one on Tab 1 first.'; return }
    Log '--- Tweaks started ---'
    foreach ($idx in $lstTweaks.CheckedIndices) {
        switch ($Tweaks[$idx].Id) {
            'SvcDiagTrack'  { Set-ServiceStart 'DiagTrack' 'Disabled' }
            'SvcDmwap'      { Set-ServiceStart 'dmwappushservice' 'Disabled' }
            'SvcRemoteReg'  { Set-ServiceStart 'RemoteRegistry' 'Disabled' }
            'SvcRetailDemo' { Set-ServiceStart 'RetailDemo' 'Disabled' }
            'SvcFax'        { Set-ServiceStart 'Fax' 'Disabled' }
            'SvcMapsBroker' { Set-ServiceStart 'MapsBroker' 'Disabled' }
            'SvcSpooler'    { Set-ServiceStart 'Spooler' 'Disabled' }
            'WidgetsOff'    { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0 }
            'CopilotOff'    {
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0
                Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
            }
            'SearchHighlightsOff' { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDynamicSearchBoxEnabled' 0 }
            'AdIdOff'       { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0 }
            'SuggestionsOff' {
                $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
                Set-Reg $cdm 'SubscribedContent-338387Enabled' 0
                Set-Reg $cdm 'SubscribedContent-338388Enabled' 0
                Set-Reg $cdm 'SubscribedContent-338389Enabled' 0
                Set-Reg $cdm 'SystemPaneSuggestionsEnabled' 0
                Set-Reg $cdm 'SoftLandingEnabled' 0
            }
            'TailoredOff'   { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0 }
            'ConsumerFeaturesOff' { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1 }
            'GameModeOn'    {
                Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
                Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
            }
            'GameDvrOff'    {
                Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
            }
            'GpuSchedOn'    {
                Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
                Log 'GPU scheduling is set - it only takes effect after a restart.'
            }
            'HighPerf'      {
                try { powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null; Log 'Power: High Performance plan active.' }
                catch { Log "Power plan FAILED - $($_.Exception.Message)" }
            }
            'NoSleep'       {
                try {
                    powercfg /change standby-timeout-ac 0 | Out-Null
                    powercfg /change hibernate-timeout-ac 0 | Out-Null
                    Log 'Power: PC will not sleep or hibernate while plugged in.'
                } catch { Log "Sleep settings FAILED - $($_.Exception.Message)" }
            }
            'EdgeBgOff'     {
                Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
                Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0
            }
            'OneDriveOff'   {
                Remove-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'OneDrive'
                Log 'OneDrive will no longer start at sign-in. Your OneDrive files were not touched.'
            }
        }
    }
    Show-RamNow
    Log '--- Tweaks finished. Restart the PC so services, GPU scheduling and power settings settle. Anything here can be reversed on Tab 5. ---'
})
$tabTweaks.Controls.Add($btnRunTweaks)

# ================================================================ TAB 5: REBLOAT / UNDO
$lblUndo = New-Object System.Windows.Forms.Label
$lblUndo.Text = "REVERSE ANYTHING.  A) Rebloat: tick removed apps and click REBLOAT - the app is re-registered from the copy kept on this PC, or opened in the Store.  B) Undo settings: tick what to put back.  C) Full go-back: System Restore."
$lblUndo.Location = New-Object System.Drawing.Point(10, 10); $lblUndo.Size = New-Object System.Drawing.Size(850, 40)
$tabUndo.Controls.Add($lblUndo)

$grpRebloat = New-Object System.Windows.Forms.GroupBox
$grpRebloat.Text = 'A - Rebloat (put removed apps back)'
$grpRebloat.Location = New-Object System.Drawing.Point(10, 55)
$grpRebloat.Size = New-Object System.Drawing.Size(420, 320)
$tabUndo.Controls.Add($grpRebloat)

$script:RebloatApps = @()
$lstRebloat = New-Object System.Windows.Forms.CheckedListBox
$lstRebloat.Location = New-Object System.Drawing.Point(10, 20); $lstRebloat.Size = New-Object System.Drawing.Size(400, 235)
$lstRebloat.CheckOnClick = $true
$grpRebloat.Controls.Add($lstRebloat)

function Refresh-RebloatList {
    $lstRebloat.Items.Clear()
    $script:RebloatApps = @()
    $seen = @{}
    if (Test-Path $RemovedTxt) {
        foreach ($line in (Get-Content $RemovedTxt)) {
            $parts = $line -split '\|', 2
            if ($parts.Count -eq 2 -and -not $seen.ContainsKey($parts[0])) {
                $seen[$parts[0]] = $true
                $script:RebloatApps += @{ N = $parts[0]; F = $parts[1] }
                [void]$lstRebloat.Items.Add($parts[1], $false)
            }
        }
    }
    if ($script:RebloatApps.Count -eq 0) {
        # Nothing recorded yet - offer the full debloat list, any of them can be restored.
        foreach ($a in $DebloatApps) {
            $script:RebloatApps += @{ N = $a.P; F = $a.F }
            [void]$lstRebloat.Items.Add($a.F, $false)
        }
        Log 'Rebloat list: no removed-apps record found, showing the full app list instead.'
    } else {
        Log "Rebloat list: $($script:RebloatApps.Count) removed app(s) loaded from C:\GamingConsoleOS\removed-apps.txt"
    }
}

$btnRefreshRebloat = New-Object System.Windows.Forms.Button
$btnRefreshRebloat.Text = 'Refresh list'
$btnRefreshRebloat.Location = New-Object System.Drawing.Point(10, 265); $btnRefreshRebloat.Size = New-Object System.Drawing.Size(120, 35)
$btnRefreshRebloat.Add_Click({ Refresh-RebloatList })
$grpRebloat.Controls.Add($btnRefreshRebloat)

$btnRebloatAll = New-Object System.Windows.Forms.Button
$btnRebloatAll.Text = 'Tick all'
$btnRebloatAll.Location = New-Object System.Drawing.Point(140, 265); $btnRebloatAll.Size = New-Object System.Drawing.Size(80, 35)
$btnRebloatAll.Add_Click({ for ($i = 0; $i -lt $lstRebloat.Items.Count; $i++) { $lstRebloat.SetItemChecked($i, $true) } })
$grpRebloat.Controls.Add($btnRebloatAll)

$btnRebloat = New-Object System.Windows.Forms.Button
$btnRebloat.Text = 'REBLOAT SELECTED'
$btnRebloat.Location = New-Object System.Drawing.Point(230, 265); $btnRebloat.Size = New-Object System.Drawing.Size(180, 35)
$btnRebloat.BackColor = [System.Drawing.Color]::LightGreen
$btnRebloat.Add_Click({
    Log '--- Rebloat started ---'
    foreach ($idx in $lstRebloat.CheckedIndices) {
        $app = $script:RebloatApps[$idx]
        Restore-App -Name $app.N -Friendly $app.F
    }
    Log '--- Rebloat finished. If an app opened in the Microsoft Store instead, click Install/Get there to finish putting it back. ---'
})
$grpRebloat.Controls.Add($btnRebloat)

$grpUndoSet = New-Object System.Windows.Forms.GroupBox
$grpUndoSet.Text = 'B - Undo settings (tick what to put back)'
$grpUndoSet.Location = New-Object System.Drawing.Point(440, 55)
$grpUndoSet.Size = New-Object System.Drawing.Size(420, 320)
$tabUndo.Controls.Add($grpUndoSet)

$UndoItems = @(
    @{ F = 'Remove Boot-to-Xbox task';                        Id = 'UndoBootTask' },
    @{ F = 'Lock screen back';                                Id = 'UndoNoLock' },
    @{ F = 'Desktop icons back';                              Id = 'UndoHideIcons' },
    @{ F = 'Services back on (telemetry, Remote Registry, Retail Demo, Fax, Maps, Print Spooler)'; Id = 'UndoServices' },
    @{ F = 'Widgets + Copilot buttons back, Copilot policy off removed'; Id = 'UndoButtons' },
    @{ F = 'Search highlights + advertising ID back on';      Id = 'UndoAds' },
    @{ F = 'App suggestions / Start ads back on';             Id = 'UndoSuggestions' },
    @{ F = 'Consumer features back on (sponsored apps policy removed)'; Id = 'UndoConsumer' },
    @{ F = 'Background game recording back on';               Id = 'UndoGameDvr' },
    @{ F = 'GPU scheduling back to Windows default';          Id = 'UndoGpuSched' },
    @{ F = 'Power plan back to Balanced + sleep back to 30 min'; Id = 'UndoPower' },
    @{ F = 'Edge background mode back on';                    Id = 'UndoEdgeBg' },
    @{ F = 'OneDrive start at sign-in again';                 Id = 'UndoOneDrive' }
)
$lstUndo = New-Object System.Windows.Forms.CheckedListBox
$lstUndo.Location = New-Object System.Drawing.Point(10, 20); $lstUndo.Size = New-Object System.Drawing.Size(400, 235)
$lstUndo.CheckOnClick = $true
foreach ($u in $UndoItems) { [void]$lstUndo.Items.Add($u.F, $false) }
$grpUndoSet.Controls.Add($lstUndo)

$btnUndoAll = New-Object System.Windows.Forms.Button
$btnUndoAll.Text = 'Tick all'
$btnUndoAll.Location = New-Object System.Drawing.Point(10, 265); $btnUndoAll.Size = New-Object System.Drawing.Size(80, 35)
$btnUndoAll.Add_Click({ for ($i = 0; $i -lt $lstUndo.Items.Count; $i++) { $lstUndo.SetItemChecked($i, $true) } })
$grpUndoSet.Controls.Add($btnUndoAll)

$btnUndoNone = New-Object System.Windows.Forms.Button
$btnUndoNone.Text = 'Untick all'
$btnUndoNone.Location = New-Object System.Drawing.Point(100, 265); $btnUndoNone.Size = New-Object System.Drawing.Size(90, 35)
$btnUndoNone.Add_Click({ for ($i = 0; $i -lt $lstUndo.Items.Count; $i++) { $lstUndo.SetItemChecked($i, $false) } })
$grpUndoSet.Controls.Add($btnUndoNone)

$btnApplyUndo = New-Object System.Windows.Forms.Button
$btnApplyUndo.Text = 'APPLY UNDO SELECTED'
$btnApplyUndo.Location = New-Object System.Drawing.Point(200, 265); $btnApplyUndo.Size = New-Object System.Drawing.Size(210, 35)
$btnApplyUndo.BackColor = [System.Drawing.Color]::LightGreen
$btnApplyUndo.Add_Click({
    Log '--- Undo started ---'
    foreach ($idx in $lstUndo.CheckedIndices) {
        switch ($UndoItems[$idx].Id) {
            'UndoBootTask' {
                try { Unregister-ScheduledTask -TaskName 'GamingConsoleOS-BootToXbox' -Confirm:$false -ErrorAction Stop; Log 'Boot task removed.' }
                catch { Log 'Boot task was not installed.' }
            }
            'UndoNoLock'    { Remove-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' 'NoLockScreen' }
            'UndoHideIcons' { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideIcons' 0 }
            'UndoServices'  {
                Set-ServiceStart 'DiagTrack' 'Automatic'
                Set-ServiceStart 'dmwappushservice' 'Manual'
                Set-ServiceStart 'RemoteRegistry' 'Manual'
                Set-ServiceStart 'RetailDemo' 'Manual'
                Set-ServiceStart 'Fax' 'Manual'
                Set-ServiceStart 'MapsBroker' 'Automatic'
                Set-ServiceStart 'Spooler' 'Automatic'
            }
            'UndoButtons'   {
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 1
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 1
                Remove-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot'
            }
            'UndoAds'       {
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDynamicSearchBoxEnabled' 1
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 1
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 1
            }
            'UndoSuggestions' {
                $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
                Set-Reg $cdm 'SubscribedContent-338387Enabled' 1
                Set-Reg $cdm 'SubscribedContent-338388Enabled' 1
                Set-Reg $cdm 'SubscribedContent-338389Enabled' 1
                Set-Reg $cdm 'SystemPaneSuggestionsEnabled' 1
                Set-Reg $cdm 'SoftLandingEnabled' 1
            }
            'UndoConsumer'  { Remove-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' }
            'UndoGameDvr'   {
                Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 1
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 1
            }
            'UndoGpuSched'  { Remove-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' }
            'UndoPower'     {
                try {
                    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null
                    powercfg /change standby-timeout-ac 30 | Out-Null
                    Log 'Power plan set back to Balanced, sleep back to 30 minutes.'
                } catch { Log "Power undo FAILED - $($_.Exception.Message)" }
            }
            'UndoEdgeBg'    {
                Remove-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled'
                Remove-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled'
            }
            'UndoOneDrive'  {
                $od = Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\OneDrive.exe'
                if (Test-Path $od) {
                    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'OneDrive' ('"' + $od + '" /background') 'String'
                    Log 'OneDrive will start at sign-in again.'
                } else { Log 'OneDrive.exe not found - reinstall OneDrive from Microsoft if you want it back.' }
            }
        }
    }
    Log '--- Undo finished. Restart the PC so the restored settings settle. ---'
})
$grpUndoSet.Controls.Add($btnApplyUndo)

$btnSysRestore = New-Object System.Windows.Forms.Button
$btnSysRestore.Text = 'C - Open System Restore (full go-back)'
$btnSysRestore.Location = New-Object System.Drawing.Point(10, 395); $btnSysRestore.Size = New-Object System.Drawing.Size(340, 40)
$btnSysRestore.Add_Click({
    Start-Process 'rstrui.exe'
    Log 'Opened System Restore. Pick the "GamingConsoleOS - before changes" point to undo everything at once.'
})
$tabUndo.Controls.Add($btnSysRestore)

$btnRamUndo = New-Object System.Windows.Forms.Button
$btnRamUndo.Text = 'Show my RAM / process count now'
$btnRamUndo.Location = New-Object System.Drawing.Point(360, 395); $btnRamUndo.Size = New-Object System.Drawing.Size(280, 40)
$btnRamUndo.Add_Click({ Show-RamNow })
$tabUndo.Controls.Add($btnRamUndo)

Refresh-RebloatList

# ------------------------------------------------------------ go
Log 'Gaming Console OS Utility v2.1 started.'
Log 'Start on Tab 1: create a system restore point FIRST. Then Tab 2 Boot, Tab 3 Debloat, Tab 4 Tweaks. Tab 5 reverses anything.'
[void]$form.ShowDialog()
