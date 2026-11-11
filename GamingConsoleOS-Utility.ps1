<#
================================================================================
 Gaming Console OS Utility  v1.0   (WinUtil-style, one window, tick boxes)
 For: Lenovo Tiny PC as a living-room gaming console - boot straight to Xbox
 Made for: Kishan  |  Nov 11, 2026

 HOW TO RUN
 1. Copy this ONE file to the Lenovo Tiny PC (Desktop is fine).
 2. Right-click Start > Terminal (Admin) / PowerShell (Admin).
 3. Run these two lines (change the path if you saved it somewhere else):
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
        powershell -STA -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\GamingConsoleOS-Utility.ps1"
    The window opens. If you forgot Admin, the script restarts itself as Admin.

 THE 4 TABS
 1. Boot to Xbox  - THE MAIN ONE. Power on > no desktop > straight into Xbox.
 2. Debloat       - Tick the apps you want gone, click Apply. Safe list only.
 3. Tweaks        - Tick the gaming / privacy tweaks you want, click Run Tweaks.
 4. Undo          - Take back the boot task, services, lock screen and power plan.

 SAFETY RULES BUILT INTO THIS FILE
 - Xbox app, Xbox Game Bar, Gaming Services, Xbox Live services, Microsoft Store,
   Windows Update, Microsoft Defender, BITS, .NET and Visual C++ are PROTECTED.
   This utility will not remove or disable them - Game Pass needs all of them.
 - Nothing here downloads code from the internet or asks for your password.
 - Every change is written to a log in C:\GamingConsoleOS, and removed app
   names are saved there too, so you can reinstall them from the Store.
 - Make a restore point first: Debloat tab > "1. Create Restore Point".
================================================================================
#>

# ------------------------------------------------------------ run as Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList (
            '-STA -NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath)
    } catch {
        Write-Host 'Please right-click the file > Run with PowerShell as Administrator.'
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

$Protected = @('*Xbox*','*GamingApp*','*GamingServices*','*WindowsStore*','*StorePurchaseApp*',
               '*SecHealthUI*','*DesktopAppInstaller*','*WindowsTerminal*','*MicrosoftEdge*')

function Remove-SafeApp {
    param([string]$Pattern, [string]$Friendly)
    foreach ($p in $Protected) {
        if ($Pattern -like $p) { Log "PROTECTED - refused: $Friendly"; return }
    }
    $pkgs = Get-AppxPackage -AllUsers -Name $Pattern -ErrorAction SilentlyContinue
    if (-not $pkgs) { Log "Not installed: $Friendly"; return }
    foreach ($pkg in $pkgs) {
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
            Log "Removed: $Friendly"
            Add-Content -Path $RemovedTxt -Value $pkg.Name -ErrorAction SilentlyContinue
        } catch { Log "Could not remove $Friendly - $($_.Exception.Message)" }
    }
    $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $Pattern }
    foreach ($pv in $prov) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $pv.PackageName -ErrorAction Stop | Out-Null
            Log "Removed provisioned copy: $Friendly"
        } catch { Log "Provisioned copy kept for $Friendly - $($_.Exception.Message)" }
    }
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

# ------------------------------------------------------------ debloat app list
$DebloatApps = @(
    @{ P = 'Microsoft.BingNews';                     F = 'Bing News' },
    @{ P = 'Microsoft.BingWeather';                  F = 'Bing Weather' },
    @{ P = 'Microsoft.MicrosoftSolitaireCollection'; F = 'Solitaire Collection' },
    @{ P = 'Microsoft.MicrosoftOfficeHub';           F = 'Office Hub / Microsoft 365 app' },
    @{ P = 'Microsoft.GetHelp';                      F = 'Get Help' },
    @{ P = 'Microsoft.Getstarted';                   F = 'Tips / Get Started' },
    @{ P = 'Microsoft.People';                       F = 'People' },
    @{ P = 'Microsoft.WindowsFeedbackHub';           F = 'Feedback Hub' },
    @{ P = 'Microsoft.WindowsMaps';                  F = 'Windows Maps' },
    @{ P = 'Microsoft.ZuneVideo';                    F = 'Movies & TV' },
    @{ P = 'Microsoft.Todos';                        F = 'Microsoft To Do' },
    @{ P = 'MicrosoftTeams';                         F = 'Teams (personal)' },
    @{ P = 'Clipchamp.Clipchamp';                    F = 'Clipchamp video editor' },
    @{ P = 'Microsoft.YourPhone';                    F = 'Phone Link' },
    @{ P = 'Microsoft.PowerAutomateDesktop';         F = 'Power Automate' },
    @{ P = 'Microsoft.Copilot';                      F = 'Copilot app' },
    @{ P = 'MicrosoftWindows.Client.WebExperience';  F = 'Widgets board (news / weather panel)' },
    @{ P = '*CandyCrush*';                           F = 'Candy Crush stub' },
    @{ P = '*TikTok*';                               F = 'TikTok stub' },
    @{ P = 'SpotifyAB.SpotifyMusic';                 F = 'Spotify stub (reinstall real Spotify if you use it)' }
)

# ------------------------------------------------------------ the window
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Gaming Console OS Utility - Boot Straight to Xbox'
$form.Size = New-Object System.Drawing.Size(900, 760)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$header = New-Object System.Windows.Forms.Label
$header.Text = 'Gaming Console OS Utility  -  tick what you want, click Apply.  Xbox / Game Pass / Store / Defender / Update are protected and cannot be removed here.'
$header.Location = New-Object System.Drawing.Point(10, 8)
$header.Size = New-Object System.Drawing.Size(860, 30)
$form.Controls.Add($header)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(10, 42)
$tabs.Size = New-Object System.Drawing.Size(860, 500)
$form.Controls.Add($tabs)

$tabBoot    = New-Object System.Windows.Forms.TabPage; $tabBoot.Text    = '1. Boot to Xbox'
$tabDebloat = New-Object System.Windows.Forms.TabPage; $tabDebloat.Text = '2. Debloat'
$tabTweaks  = New-Object System.Windows.Forms.TabPage; $tabTweaks.Text  = '3. Tweaks'
$tabUndo    = New-Object System.Windows.Forms.TabPage; $tabUndo.Text    = '4. Undo'
$tabs.TabPages.AddRange(@($tabBoot, $tabDebloat, $tabTweaks, $tabUndo))

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location = New-Object System.Drawing.Point(10, 550)
$logBox.Size = New-Object System.Drawing.Size(860, 155)
$logBox.ReadOnly = $true
$form.Controls.Add($logBox)
$script:LogBox = $logBox

# ================================================================ TAB 1: BOOT TO XBOX
$lblBoot = New-Object System.Windows.Forms.Label
$lblBoot.Text = "There are 2 layers. Use BOTH and this Tiny PC feels like a real console:`r`nA) Official Xbox Mode - Windows boots into the full-screen Xbox shell and holds back background processes.`r`nB) Fallback launcher (this utility installs it) - works on every PC: sign-in goes straight to the Xbox app."
$lblBoot.Location = New-Object System.Drawing.Point(10, 10)
$lblBoot.Size = New-Object System.Drawing.Size(830, 55)
$tabBoot.Controls.Add($lblBoot)

$grpA = New-Object System.Windows.Forms.GroupBox
$grpA.Text = 'A - Official Xbox Mode (Full Screen Experience)'
$grpA.Location = New-Object System.Drawing.Point(10, 70)
$grpA.Size = New-Object System.Drawing.Size(830, 150)
$tabBoot.Controls.Add($grpA)

$txtA = New-Object System.Windows.Forms.TextBox
$txtA.Multiline = $true; $txtA.ReadOnly = $true; $txtA.ScrollBars = 'Vertical'
$txtA.Location = New-Object System.Drawing.Point(10, 20)
$txtA.Size = New-Object System.Drawing.Size(810, 80)
$txtA.Text = "Do this once, by hand - Microsoft gives no safe script switch for it:`r`n1. Settings > Windows Update - install everything, restart.`r`n2. Microsoft Store - update the Xbox app.`r`n3. Settings > Gaming > Full screen experience (newer builds call it Xbox mode).`r`n4. Set your home app = Xbox.  5. Turn ON 'Enter full screen experience on startup'.  6. Restart.`r`nIn Xbox Mode: Win+F11 or Win+Tab = back to desktop, Xbox button / Win+G = Game Bar.`r`nIf the setting is missing, your build/region has not got the rollout yet - use Layer B below. Do NOT use ViVeTool / DeviceForm registry hacks to force it: the feature IDs change between builds, it is unsupported, and updates can break it."
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
$btnCheck.Add_Click({
    $os = Get-CimInstance Win32_OperatingSystem
    Log "Windows: $($os.Caption) build $($os.BuildNumber)"
    foreach ($n in @('Microsoft.GamingApp','Microsoft.GamingServices','Microsoft.XboxIdentityProvider','Microsoft.XboxGamingOverlay')) {
        $p = Get-AppxPackage -Name $n -ErrorAction SilentlyContinue
        if ($p) { Log "OK - $n  version $($p.Version)" } else { Log "MISSING - $n  (install/update it from Microsoft Store)" }
    }
    Log "Xbox launch ID on this PC: $(Get-XboxAppId)"
    Show-RamNow
})
$grpA.Controls.Add($btnCheck)

$grpB = New-Object System.Windows.Forms.GroupBox
$grpB.Text = 'B - Boot Straight to Xbox (installed by this utility, works on any PC)'
$grpB.Location = New-Object System.Drawing.Point(10, 230)
$grpB.Size = New-Object System.Drawing.Size(830, 235)
$tabBoot.Controls.Add($grpB)

$chkAutoXbox = New-Object System.Windows.Forms.CheckBox
$chkAutoXbox.Text = 'Auto-open the Xbox app at sign-in (scheduled task, 5 seconds after sign-in)'
$chkAutoXbox.Location = New-Object System.Drawing.Point(15, 25); $chkAutoXbox.Size = New-Object System.Drawing.Size(800, 22)
$chkAutoXbox.Checked = $true
$grpB.Controls.Add($chkAutoXbox)

$chkNoLock = New-Object System.Windows.Forms.CheckBox
$chkNoLock.Text = 'Skip the lock screen (power on goes straight to sign-in, no photo screen to click past)'
$chkNoLock.Location = New-Object System.Drawing.Point(15, 50); $chkNoLock.Size = New-Object System.Drawing.Size(800, 22)
$chkNoLock.Checked = $true
$grpB.Controls.Add($chkNoLock)

$chkHideIcons = New-Object System.Windows.Forms.CheckBox
$chkHideIcons.Text = 'Hide desktop icons (clean TV look - files are not deleted, icons are just hidden)'
$chkHideIcons.Location = New-Object System.Drawing.Point(15, 75); $chkHideIcons.Size = New-Object System.Drawing.Size(800, 22)
$chkHideIcons.Checked = $false
$grpB.Controls.Add($chkHideIcons)

$lblAuto = New-Object System.Windows.Forms.Label
$lblAuto.Text = "For true 'power on, no password, straight in' you also need auto sign-in. This utility will NOT ask for or store your password. Use Microsoft's own free Autologon tool (button below) - it stores the password protected, and holding Shift at boot skips it once."
$lblAuto.Location = New-Object System.Drawing.Point(15, 105); $lblAuto.Size = New-Object System.Drawing.Size(800, 40)
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

# ================================================================ TAB 2: DEBLOAT
$lblDeb = New-Object System.Windows.Forms.Label
$lblDeb.Text = "Tick the apps to remove, then click Apply Debloat. Only this safe list is shown.`r`nXbox, Game Bar, Gaming Services, Store, Edge, Terminal, Calculator, Notepad, Paint, Photos and Snipping Tool are protected and are NOT in this list."
$lblDeb.Location = New-Object System.Drawing.Point(10, 10); $lblDeb.Size = New-Object System.Drawing.Size(830, 40)
$tabDebloat.Controls.Add($lblDeb)

$lstDebloat = New-Object System.Windows.Forms.CheckedListBox
$lstDebloat.Location = New-Object System.Drawing.Point(10, 55); $lstDebloat.Size = New-Object System.Drawing.Size(830, 330)
$lstDebloat.CheckOnClick = $true
foreach ($a in $DebloatApps) { [void]$lstDebloat.Items.Add($a.F, $true) }
$tabDebloat.Controls.Add($lstDebloat)

$btnRestore = New-Object System.Windows.Forms.Button
$btnRestore.Text = '1. Create Restore Point'
$btnRestore.Location = New-Object System.Drawing.Point(10, 400); $btnRestore.Size = New-Object System.Drawing.Size(220, 35)
$btnRestore.Add_Click({
    try {
        Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'GamingConsoleOS - before debloat' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Log 'Restore point created.'
    } catch { Log "Restore point not created: $($_.Exception.Message) (Windows allows one per 24h - you can still continue, every removal is logged.)" }
    Show-RamNow
})
$tabDebloat.Controls.Add($btnRestore)

$btnAll = New-Object System.Windows.Forms.Button
$btnAll.Text = 'Tick all'
$btnAll.Location = New-Object System.Drawing.Point(240, 400); $btnAll.Size = New-Object System.Drawing.Size(110, 35)
$btnAll.Add_Click({ for ($i = 0; $i -lt $lstDebloat.Items.Count; $i++) { $lstDebloat.SetItemChecked($i, $true) } })
$tabDebloat.Controls.Add($btnAll)

$btnNone = New-Object System.Windows.Forms.Button
$btnNone.Text = 'Untick all'
$btnNone.Location = New-Object System.Drawing.Point(360, 400); $btnNone.Size = New-Object System.Drawing.Size(110, 35)
$btnNone.Add_Click({ for ($i = 0; $i -lt $lstDebloat.Items.Count; $i++) { $lstDebloat.SetItemChecked($i, $false) } })
$tabDebloat.Controls.Add($btnNone)

$btnApplyDebloat = New-Object System.Windows.Forms.Button
$btnApplyDebloat.Text = '2. APPLY DEBLOAT'
$btnApplyDebloat.Location = New-Object System.Drawing.Point(480, 400); $btnApplyDebloat.Size = New-Object System.Drawing.Size(220, 35)
$btnApplyDebloat.BackColor = [System.Drawing.Color]::LightGreen
$btnApplyDebloat.Add_Click({
    Log '--- Debloat started ---'
    foreach ($idx in $lstDebloat.CheckedIndices) {
        $app = $DebloatApps[$idx]
        Remove-SafeApp -Pattern $app.P -Friendly $app.F
    }
    Log '--- Debloat finished. Restart, then check the Xbox app still signs in and a Game Pass game still installs. Removed app names: C:\GamingConsoleOS\removed-apps.txt ---'
})
$tabDebloat.Controls.Add($btnApplyDebloat)

# ================================================================ TAB 3: TWEAKS
$lblTwk = New-Object System.Windows.Forms.Label
$lblTwk.Text = "Tick the tweaks you want, then click Run Tweaks. Nothing here touches Defender, Windows Update, the Store, Xbox services or the pagefile."
$lblTwk.Location = New-Object System.Drawing.Point(10, 10); $lblTwk.Size = New-Object System.Drawing.Size(830, 30)
$tabTweaks.Controls.Add($lblTwk)

$TweakNames = @(
    'Disable telemetry services (DiagTrack + dmwappushservice)',
    'Turn off Widgets button, Copilot button and search highlights',
    'Turn off app suggestions, Start ads and tips (and advertising ID)',
    'Game Mode ON',
    'Turn off background game recording (Game DVR capture)',
    'Hardware GPU scheduling ON (needs a restart, best with a real GPU)',
    'High Performance power plan + never sleep while plugged in',
    'Stop Microsoft Edge running in the background',
    'Set background services to Disabled: Remote Registry, Retail Demo, Fax',
    'Stop OneDrive starting at sign-in (does not delete your files)'
)
$lstTweaks = New-Object System.Windows.Forms.CheckedListBox
$lstTweaks.Location = New-Object System.Drawing.Point(10, 45); $lstTweaks.Size = New-Object System.Drawing.Size(830, 300)
$lstTweaks.CheckOnClick = $true
for ($i = 0; $i -lt $TweakNames.Count; $i++) {
    $checked = $i -lt 8   # first 8 ticked by default, last 2 are your choice
    [void]$lstTweaks.Items.Add($TweakNames[$i], $checked)
}
$tabTweaks.Controls.Add($lstTweaks)

$btnTweaks = New-Object System.Windows.Forms.Button
$btnTweaks.Text = 'RUN TWEAKS'
$btnTweaks.Location = New-Object System.Drawing.Point(10, 360); $btnTweaks.Size = New-Object System.Drawing.Size(220, 35)
$btnTweaks.BackColor = [System.Drawing.Color]::LightGreen
$btnTweaks.Add_Click({
    Log '--- Tweaks started ---'
    foreach ($idx in $lstTweaks.CheckedIndices) {
        switch ($idx) {
            0 {
                Set-ServiceStart 'DiagTrack' 'Disabled'
                Set-ServiceStart 'dmwappushservice' 'Disabled'
            }
            1 {
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDynamicSearchBoxEnabled' 0
                Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
            }
            2 {
                $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
                Set-Reg $cdm 'SubscribedContent-338387Enabled' 0
                Set-Reg $cdm 'SubscribedContent-338388Enabled' 0
                Set-Reg $cdm 'SubscribedContent-338389Enabled' 0
                Set-Reg $cdm 'SystemPaneSuggestionsEnabled' 0
                Set-Reg $cdm 'SoftLandingEnabled' 0
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
            }
            3 {
                Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
                Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
            }
            4 {
                Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
                Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
            }
            5 {
                Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
                Log 'GPU scheduling is set - it only takes effect after a restart.'
            }
            6 {
                try {
                    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
                    powercfg /change standby-timeout-ac 0 | Out-Null
                    powercfg /change hibernate-timeout-ac 0 | Out-Null
                    Log 'Power: High Performance plan active, PC will not sleep while plugged in.'
                } catch { Log "Power plan FAILED - $($_.Exception.Message)" }
            }
            7 {
                Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
                Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0
            }
            8 {
                Set-ServiceStart 'RemoteRegistry' 'Disabled'
                Set-ServiceStart 'RetailDemo' 'Disabled'
                Set-ServiceStart 'Fax' 'Disabled'
            }
            9 {
                Remove-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'OneDrive'
                Log 'OneDrive will no longer start at sign-in. Your OneDrive files were not touched.'
            }
        }
    }
    Show-RamNow
    Log '--- Tweaks finished. Restart the PC so services, GPU scheduling and power settings settle. ---'
})
$tabTweaks.Controls.Add($btnTweaks)

$lblTwkNote = New-Object System.Windows.Forms.Label
$lblTwkNote.Text = 'Note: Print Spooler is left alone on purpose. If this console never prints, you can disable it yourself in services.msc - it is the one extra safe one.'
$lblTwkNote.Location = New-Object System.Drawing.Point(10, 410); $lblTwkNote.Size = New-Object System.Drawing.Size(830, 30)
$tabTweaks.Controls.Add($lblTwkNote)

# ================================================================ TAB 4: UNDO
$lblUndo = New-Object System.Windows.Forms.Label
$lblUndo.Text = "Take things back. Removed apps are reinstalled from the Microsoft Store - their names are saved in C:\GamingConsoleOS\removed-apps.txt.`r`nFor a full go-back, use System Restore (button below) and pick the 'GamingConsoleOS - before debloat' point."
$lblUndo.Location = New-Object System.Drawing.Point(10, 10); $lblUndo.Size = New-Object System.Drawing.Size(830, 45)
$tabUndo.Controls.Add($lblUndo)

function New-UndoButton {
    param([string]$Text, [int]$Y, [scriptblock]$Action)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text; $b.Location = New-Object System.Drawing.Point(10, $Y); $b.Size = New-Object System.Drawing.Size(420, 35)
    $b.Add_Click($Action)
    $tabUndo.Controls.Add($b)
    return $b
}

New-UndoButton 'Remove Boot-to-Xbox (task + lock screen + icons back)' 65 {
    try { Unregister-ScheduledTask -TaskName 'GamingConsoleOS-BootToXbox' -Confirm:$false -ErrorAction Stop; Log 'Boot task removed.' }
    catch { Log 'Boot task was not installed.' }
    Remove-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' 'NoLockScreen'
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideIcons' 0
} | Out-Null

New-UndoButton 'Turn services back on (telemetry, Remote Registry, Retail Demo, Fax)' 110 {
    Set-ServiceStart 'DiagTrack' 'Automatic'
    Set-ServiceStart 'dmwappushservice' 'Manual'
    Set-ServiceStart 'RemoteRegistry' 'Manual'
    Set-ServiceStart 'RetailDemo' 'Manual'
    Set-ServiceStart 'Fax' 'Manual'
    Remove-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot'
} | Out-Null

New-UndoButton 'Power plan back to Balanced' 155 {
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null
    Log 'Power plan set back to Balanced.'
} | Out-Null

New-UndoButton 'Open System Restore' 200 { Start-Process 'rstrui.exe' } | Out-Null

New-UndoButton 'Open the log + removed-apps folder' 245 {
    Start-Process 'explorer.exe' -ArgumentList $WorkDir
} | Out-Null

New-UndoButton 'Show my RAM / process count now' 290 { Show-RamNow } | Out-Null

# ------------------------------------------------------------ go
Log 'Gaming Console OS Utility started.'
Log 'Start on Tab 1 (Boot to Xbox), then Tab 2 (Debloat), then Tab 3 (Tweaks). Create a restore point first - Debloat tab, button 1.'
[void]$form.ShowDialog()
