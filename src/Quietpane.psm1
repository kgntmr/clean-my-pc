# ============================================================================
#  LOOKING FOR HOW TO START Quietpane?  This file is the app's code.
#  Close this window, then double-click "Start Quietpane" instead.
# ============================================================================
#Requires -Version 5.1
<#
    Quietpane - core engine.
    Developed by KomodoWorks - https://www.komodoworks.com - MIT License.

    Principles
      * Scan is read-only.
      * Every change is recorded in a restore point (%ProgramData%\Quietpane\restore\...) and can be undone.
      * Tidying up only ever moves files to the Recycle Bin. The single exception is a threat the
        user chooses to delete for good, which is confirmed twice and written to the audit log.
      * Quarantined files are moved, never altered, and can be restored byte-for-byte.
      * Scheduled tasks are disabled, never deleted.
      * Security (Defender, SmartScreen, firewall) and Windows Update are never touched.
      * No network requests, no telemetry, no data collection. Everything stays on this PC.
#>

$script:AppVersion  = '1.6.0'
$script:Brand       = @{ Name = 'KomodoWorks'; Url = 'https://www.komodoworks.com'; Email = 'info@komodoworks.com'; Repo = 'https://github.com/kgntmr/quietpane' }
$script:AssetsRoot  = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets'
$script:LogSink     = $null
$script:LogFile     = $null
$script:Session     = $null
$script:CatalogRoot = Join-Path $PSScriptRoot 'catalog'
$script:DataRoot    = Join-Path $env:ProgramData 'Quietpane'
# Restore points made before the app was renamed (it used to be called Clean My PC).
# New ones go to the folder above; old ones stay readable so Undo keeps working.
$script:LegacyDataRoot = Join-Path $env:ProgramData 'CleanMyPC'
$script:HostsPath   = Join-Path $env:WINDIR 'System32\drivers\etc\hosts'
$script:ComputerMaker = $null      # filled in once, when brand software is looked for
$script:GpuNames = $null
$script:InstalledPrograms = $null

# Apps that are never removed, even if someone adds them to the catalog.
$script:ProtectedAppPattern = '^(Microsoft\.WindowsStore|Microsoft\.StorePurchaseApp|Microsoft\.DesktopAppInstaller|Microsoft\.SecHealthUI|Microsoft\.Windows\.Photos|Microsoft\.WindowsCamera|Microsoft\.WindowsCalculator|Microsoft\.WindowsNotepad|Microsoft\.Paint|Microsoft\.ScreenSketch|Microsoft\.WindowsTerminal|Microsoft\.Winget\.Source|Microsoft\.VCLibs.*|Microsoft\.NET\..*|Microsoft\.UI\.Xaml.*|Microsoft\.WindowsAppRuntime.*|MicrosoftCorporationII\.WinAppRuntime.*|Microsoft\.Services\.Store.*|Microsoft\..*Extension[s]?|Microsoft\.LanguageExperiencePack.*|NVIDIACorp\..*|RealtekSemiconductorCorp\..*|AppUp\.Intel.*|Microsoft\.MicrosoftEdge\.Stable|Microsoft\.MicrosoftEdgeDevToolsClient)$'

#region ---------------------------------------------------------------- helpers

function Get-QpInfo {
    [pscustomobject]@{
        Version    = $script:AppVersion
        BrandName  = $script:Brand.Name
        BrandUrl   = $script:Brand.Url
        BrandEmail = $script:Brand.Email
        RepoUrl    = $script:Brand.Repo
        LogoPath   = Join-Path $script:AssetsRoot 'komodoworks-logo.png'
        DataRoot   = $script:DataRoot
    }
}

function Set-QpLogSink {
    param([scriptblock]$Sink)
    $script:LogSink = $Sink
}

function Write-QpLog {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'PREVIEW', 'SKIP', 'STEP')][string]$Level = 'INFO'
    )
    $line = '[{0}] {1,-7} {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level, $Message
    if ($script:LogFile) { try { Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 } catch { } }
    if ($script:LogSink) { & $script:LogSink $line } else { Write-Host $line }
}

function Test-QpAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-QpCatalog {
    param([ValidateSet('privacy', 'apps', 'cleanup', 'vendors', 'threats')][string]$Name)
    Import-PowerShellDataFile -Path (Join-Path $script:CatalogRoot "$Name.psd1")
}

function Format-QpBytes {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N1} MB' -f ($Bytes / 1MB) }
    return '{0:N0} KB' -f ($Bytes / 1KB)
}

function Get-QpSize {
    param([string[]]$Paths)
    $sum = 0
    foreach ($p in $Paths) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $m = Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
        if ($m.Sum) { $sum += $m.Sum }
    }
    return $sum
}

function Move-QpToRecycleBin {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    Add-Type -AssemblyName Microsoft.VisualBasic
    try {
        $item = Get-Item -LiteralPath $Path -Force
        if ($item.PSIsContainer) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($item.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
        } else {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($item.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
        }
        return $true
    } catch {
        return $false
    }
}

function Get-QpRegValue {
    param([string]$Path, [string]$Name)
    try {
        $p = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return @{ Exists = $true; Value = $p.$Name }
    } catch {
        return @{ Exists = $false; Value = $null }
    }
}

#endregion

function Get-QpSystemUsage {
    <# Live disk and memory figures for the Home screen. Read-only. #>
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $sysDrive = ($env:SystemDrive, 'C:')[[int][string]::IsNullOrEmpty($env:SystemDrive)]
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sysDrive'" -ErrorAction SilentlyContinue
    $memTotal = if ($os) { [int64]$os.TotalVisibleMemorySize * 1KB } else { 0 }
    $memFree = if ($os) { [int64]$os.FreePhysicalMemory * 1KB } else { 0 }
    [pscustomobject]@{
        Drive     = $sysDrive
        DiskTotal = if ($disk) { [int64]$disk.Size } else { 0 }
        DiskFree  = if ($disk) { [int64]$disk.FreeSpace } else { 0 }
        DiskUsed  = if ($disk) { [int64]($disk.Size - $disk.FreeSpace) } else { 0 }
        MemTotal  = $memTotal
        MemFree   = $memFree
        MemUsed   = $memTotal - $memFree
    }
}

function Get-QpTotals {
    <# Running totals of what this tool has freed on this PC, so the Home screen can show progress. #>
    $file = Join-Path $script:DataRoot 'totals.json'
    $empty = [pscustomobject]@{ SpaceFreedBytes = [int64]0; MemoryFreedBytes = [int64]0; Runs = 0; LastRun = $null }
    if (-not (Test-Path $file)) { return $empty }
    try {
        $t = Get-Content $file -Raw | ConvertFrom-Json
        [pscustomobject]@{
            SpaceFreedBytes  = [int64]$t.SpaceFreedBytes
            MemoryFreedBytes = [int64]$t.MemoryFreedBytes
            Runs             = [int]$t.Runs
            LastRun          = $t.LastRun
        }
    } catch { $empty }
}

function Add-QpTotals {
    param([int64]$SpaceBytes = 0, [int64]$MemoryBytes = 0, [switch]$CountRun)
    if ($SpaceBytes -le 0 -and $MemoryBytes -le 0 -and -not $CountRun) { return }
    try {
        $t = Get-QpTotals
        $new = [pscustomobject]@{
            SpaceFreedBytes  = $t.SpaceFreedBytes + [Math]::Max(0, $SpaceBytes)
            MemoryFreedBytes = $t.MemoryFreedBytes + [Math]::Max(0, $MemoryBytes)
            Runs             = $t.Runs + [int]([bool]$CountRun)
            LastRun          = (Get-Date).ToString('yyyy-MM-dd HH:mm')
        }
        if (-not (Test-Path $script:DataRoot)) { New-Item -ItemType Directory -Path $script:DataRoot -Force | Out-Null }
        $new | ConvertTo-Json | Set-Content -Path (Join-Path $script:DataRoot 'totals.json') -Encoding UTF8
    } catch { Write-QpLog "Could not record the totals: $($_.Exception.Message)" 'WARN' }
}

#region ---------------------------------------------------------------- restore points

function Start-QpSession {
    param([string]$Name)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $path = Join-Path $script:DataRoot "restore\$stamp-$Name"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $script:Session = @{ Name = $Name; Path = $path; Started = (Get-Date).ToString('s'); Entries = New-Object System.Collections.ArrayList }
    $script:LogFile = Join-Path $path 'log.txt'
    Write-QpLog "Restore point: $path" 'STEP'
}

function Save-QpSession {
    if (-not $script:Session) { return }
    $data = @{ Name = $script:Session.Name; Started = $script:Session.Started; Entries = @($script:Session.Entries) }
    $data | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $script:Session.Path 'state.json') -Encoding UTF8
}

function Add-QpUndo {
    param([hashtable]$Entry)
    if (-not $script:Session) { return }
    [void]$script:Session.Entries.Add($Entry)
    Save-QpSession
}

function Stop-QpSession {
    if (-not $script:Session) { return }
    Save-QpSession
    Write-QpLog ("Finished. {0} change(s) recorded - they can be undone from the Undo tab." -f $script:Session.Entries.Count) 'OK'
    $script:Session = $null
    $script:LogFile = $null
}

function Get-QpRestorePoints {
    $roots = @((Join-Path $script:DataRoot 'restore'), (Join-Path $script:LegacyDataRoot 'restore')) | Where-Object { Test-Path $_ }
    if (-not $roots.Count) { return @() }
    Get-ChildItem -Path $roots -Directory | Sort-Object Name -Descending | ForEach-Object {
        $count = 0
        $state = Join-Path $_.FullName 'state.json'
        if (Test-Path $state) { try { $count = @((Get-Content $state -Raw | ConvertFrom-Json).Entries).Count } catch { } }
        [pscustomobject]@{
            Name    = $_.Name
            Path    = $_.FullName
            Changes = $count
            Undone  = (Test-Path (Join-Path $_.FullName 'undone.txt'))
        }
    }
}

function Invoke-QpUndo {
    param([Parameter(Mandatory)][string]$Path)
    $stateFile = Join-Path $Path 'state.json'
    if (-not (Test-Path $stateFile)) { Write-QpLog "No state.json in $Path" 'ERROR'; return }
    $state = Get-Content $stateFile -Raw | ConvertFrom-Json
    $entries = @($state.Entries)
    [array]::Reverse($entries)
    Write-QpLog "Undoing $($entries.Count) change(s) from $(Split-Path $Path -Leaf)" 'STEP'
    foreach ($e in $entries) {
        try {
            switch ($e.Type) {
                'Service' {
                    try { Set-Service -Name $e.Name -StartupType $e.StartType -ErrorAction Stop }
                    catch {
                        $map = @{ Disabled = 'disabled'; Manual = 'demand'; Automatic = 'auto' }
                        & sc.exe config $e.Name start= $map[[string]$e.StartType] | Out-Null
                    }
                    if ($e.WasRunning) { Start-Service -Name $e.Name -ErrorAction SilentlyContinue }
                    Write-QpLog "Service $($e.Name) restored to $($e.StartType)" 'OK'
                }
                'Task' {
                    Enable-ScheduledTask -TaskPath $e.Path -TaskName $e.Name -ErrorAction Stop | Out-Null
                    Write-QpLog "Task $($e.Path)$($e.Name) re-enabled" 'OK'
                }
                'Reg' {
                    if ($e.Existed) {
                        Set-ItemProperty -Path $e.Path -Name $e.Name -Value $e.OldValue -Type $e.Kind -ErrorAction Stop
                        Write-QpLog "$($e.Path)\$($e.Name) restored to $($e.OldValue)" 'OK'
                    } else {
                        Remove-ItemProperty -Path $e.Path -Name $e.Name -ErrorAction SilentlyContinue
                        Write-QpLog "$($e.Path)\$($e.Name) removed (was not set before)" 'OK'
                    }
                }
                'Env' {
                    [Environment]::SetEnvironmentVariable($e.Name, $e.OldValue, 'Machine')
                    Write-QpLog "Environment variable $($e.Name) restored" 'OK'
                }
                'FileRestore' {
                    Copy-Item -LiteralPath $e.Backup -Destination $e.Path -Force
                    Write-QpLog "Restored $($e.Path) from backup" 'OK'
                }
                'FileCreated' {
                    if (Move-QpToRecycleBin $e.Path) { Write-QpLog "Moved created file $($e.Path) to the Recycle Bin" 'OK' }
                }
                'Hosts' {
                    Remove-QpHostsBlock -Tag $e.Tag
                }
                'Recycled' {
                    Write-QpLog "Files from $($e.Path) are in the Recycle Bin - restore them there if you need them" 'INFO'
                }
                'Appx' {
                    Write-QpLog "App $($e.Name) was removed - reinstall it from the Microsoft Store if you want it back" 'INFO'
                }
                default { Write-QpLog "Unknown undo entry type: $($e.Type)" 'WARN' }
            }
        } catch {
            Write-QpLog "Could not undo $($e.Type) $($e.Name)$($e.Path): $($_.Exception.Message)" 'WARN'
        }
    }
    Set-Content -Path (Join-Path $Path 'undone.txt') -Value (Get-Date).ToString('s')
    Write-QpLog 'Undo finished. Restart the PC to make sure everything is back in effect.' 'OK'
}

#endregion

#region ---------------------------------------------------------------- change engine

function Invoke-QpServiceAction {
    param($Action, [switch]$Preview)
    $svc = Get-Service -Name $Action.Name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-QpLog "Service $($Action.Name) is not on this PC - skipped" 'SKIP'; return }
    $current = [string]$svc.StartType
    $target = [string]$Action.StartType
    if ($current -eq $target) { Write-QpLog "Service $($Action.Name) is already $target" 'OK'; return }
    if ($Preview) { Write-QpLog "Would change service $($Action.Name): $current -> $target" 'PREVIEW'; return }
    Add-QpUndo @{ Type = 'Service'; Name = $Action.Name; StartType = $current; WasRunning = ($svc.Status -eq 'Running') }
    if ($target -eq 'Disabled') { Stop-Service -Name $Action.Name -Force -ErrorAction SilentlyContinue }
    try {
        Set-Service -Name $Action.Name -StartupType $target -ErrorAction Stop
    } catch {
        $map = @{ Disabled = 'disabled'; Manual = 'demand'; Automatic = 'auto' }
        & sc.exe config $Action.Name start= $map[$target] | Out-Null
    }
    $after = [string](Get-Service -Name $Action.Name).StartType
    if ($after -eq $target) { Write-QpLog "Service $($Action.Name) -> $target" 'OK' }
    else { Write-QpLog "Service $($Action.Name) is protected by Windows and could not be changed" 'WARN' }
}

function Invoke-QpTaskAction {
    param($Action, [switch]$Preview)
    $tasks = @(Get-ScheduledTask -TaskPath $Action.Path -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like $Action.Name })
    if ($tasks.Count -eq 0) { Write-QpLog "Task $($Action.Path)$($Action.Name) is not on this PC - skipped" 'SKIP'; return }
    foreach ($t in $tasks) {
        $id = "$($t.TaskPath)$($t.TaskName)"
        if ($t.State -eq 'Disabled') { Write-QpLog "Task $id is already disabled" 'OK'; continue }
        if ($Preview) { Write-QpLog "Would disable task $id" 'PREVIEW'; continue }
        try {
            Disable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction Stop | Out-Null
            Add-QpUndo @{ Type = 'Task'; Path = $t.TaskPath; Name = $t.TaskName }
            Write-QpLog "Task $id disabled" 'OK'
        } catch {
            Write-QpLog "Task $id is protected by Windows - left as is" 'WARN'
        }
    }
}

function Invoke-QpRegAction {
    param($Action, [switch]$Preview)
    $kind = if ($Action.Kind) { $Action.Kind } else { 'DWord' }
    $label = "$($Action.Path)\$($Action.Name)"
    $cur = Get-QpRegValue -Path $Action.Path -Name $Action.Name
    if ($cur.Exists -and ("$($cur.Value)" -eq "$($Action.Value)")) { Write-QpLog "$label is already $($Action.Value)" 'OK'; return }
    if ($Preview) {
        $from = if ($cur.Exists) { $cur.Value } else { '(not set)' }
        Write-QpLog "Would set $label : $from -> $($Action.Value)" 'PREVIEW'
        return
    }
    Add-QpUndo @{ Type = 'Reg'; Path = $Action.Path; Name = $Action.Name; Existed = $cur.Exists; OldValue = $cur.Value; Kind = $kind }
    try {
        if (-not (Test-Path -Path $Action.Path)) { New-Item -Path $Action.Path -Force | Out-Null }
        Set-ItemProperty -Path $Action.Path -Name $Action.Name -Value $Action.Value -Type $kind -ErrorAction Stop
        Write-QpLog "$label = $($Action.Value)" 'OK'
    } catch {
        Write-QpLog "Could not set $label : $($_.Exception.Message)" 'ERROR'
    }
}

function Invoke-QpEnvAction {
    param($Action, [switch]$Preview)
    $cur = [Environment]::GetEnvironmentVariable($Action.Name, 'Machine')
    if ($cur -eq $Action.Value) { Write-QpLog "$($Action.Name) is already $($Action.Value)" 'OK'; return }
    if ($Preview) { Write-QpLog "Would set environment variable $($Action.Name)=$($Action.Value)" 'PREVIEW'; return }
    Add-QpUndo @{ Type = 'Env'; Name = $Action.Name; OldValue = $cur }
    [Environment]::SetEnvironmentVariable($Action.Name, $Action.Value, 'Machine')
    Write-QpLog "Environment variable $($Action.Name)=$($Action.Value)" 'OK'
}

function Invoke-QpVSCodeTelemetry {
    param([switch]$Preview)
    $codeRoot = Join-Path $env:APPDATA 'Code'
    if (-not (Test-Path $codeRoot)) { Write-QpLog 'VS Code is not installed for this user - skipped' 'SKIP'; return }
    $userDir = Join-Path $codeRoot 'User'
    $file = Join-Path $userDir 'settings.json'
    $setting = '"telemetry.telemetryLevel": "off"'
    if (Test-Path $file) {
        $raw = Get-Content -LiteralPath $file -Raw
        if ($raw -match '"telemetry\.telemetryLevel"\s*:\s*"off"') { Write-QpLog 'VS Code telemetry is already off' 'OK'; return }
        if ($raw -match '"telemetry\.telemetryLevel"') { Write-QpLog 'VS Code has telemetry.telemetryLevel set to another value - set it to "off" in VS Code settings' 'WARN'; return }
        if ($Preview) { Write-QpLog "Would add $setting to $file" 'PREVIEW'; return }
        $backup = Join-Path $script:Session.Path 'vscode-settings.json.bak'
        Copy-Item -LiteralPath $file -Destination $backup -Force
        Add-QpUndo @{ Type = 'FileRestore'; Path = $file; Backup = $backup }
        $new = ([regex]'\{').Replace($raw, "{`r`n    $setting,", 1)
        Set-Content -LiteralPath $file -Value $new -Encoding UTF8
    } else {
        if ($Preview) { Write-QpLog "Would create $file with $setting" 'PREVIEW'; return }
        New-Item -ItemType Directory -Path $userDir -Force | Out-Null
        Set-Content -LiteralPath $file -Value "{`r`n    $setting`r`n}" -Encoding UTF8
        Add-QpUndo @{ Type = 'FileCreated'; Path = $file }
    }
    Write-QpLog 'VS Code telemetry turned off' 'OK'
}

function Invoke-QpAction {
    param($Action, [switch]$Preview)
    switch ($Action.Type) {
        'Service'         { Invoke-QpServiceAction -Action $Action -Preview:$Preview }
        'Task'            { Invoke-QpTaskAction -Action $Action -Preview:$Preview }
        'Reg'             { Invoke-QpRegAction -Action $Action -Preview:$Preview }
        'Env'             { Invoke-QpEnvAction -Action $Action -Preview:$Preview }
        'Hosts'           { Add-QpHostsBlock -HostNames $Action.Hosts -Tag $Action.Tag -Preview:$Preview }
        'VSCodeTelemetry' { Invoke-QpVSCodeTelemetry -Preview:$Preview }
        default           { Write-QpLog "Unknown action type '$($Action.Type)'" 'WARN' }
    }
}

function Test-QpActionApplied {
    # Returns $true (done), $false (not done) or $null (not applicable on this PC).
    param($Action)
    switch ($Action.Type) {
        'Service' {
            $svc = Get-Service -Name $Action.Name -ErrorAction SilentlyContinue
            if (-not $svc) { return $null }
            return ([string]$svc.StartType -eq [string]$Action.StartType)
        }
        'Task' {
            $tasks = @(Get-ScheduledTask -TaskPath $Action.Path -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like $Action.Name })
            if ($tasks.Count -eq 0) { return $null }
            return (@($tasks | Where-Object { $_.State -ne 'Disabled' }).Count -eq 0)
        }
        'Reg' {
            $cur = Get-QpRegValue -Path $Action.Path -Name $Action.Name
            return ($cur.Exists -and ("$($cur.Value)" -eq "$($Action.Value)"))
        }
        'Env' { return ([Environment]::GetEnvironmentVariable($Action.Name, 'Machine') -eq $Action.Value) }
        'Hosts' {
            $lines = @(Get-Content -Path $script:HostsPath -ErrorAction SilentlyContinue)
            return (@($Action.Hosts | Where-Object { -not (Test-QpHostBlocked -Lines $lines -HostName $_) }).Count -eq 0)
        }
        'VSCodeTelemetry' {
            $file = Join-Path $env:APPDATA 'Code\User\settings.json'
            if (-not (Test-Path (Join-Path $env:APPDATA 'Code'))) { return $null }
            if (-not (Test-Path $file)) { return $false }
            return ((Get-Content -LiteralPath $file -Raw) -match '"telemetry\.telemetryLevel"\s*:\s*"off"')
        }
    }
    return $null
}

function Get-QpPrivacyStatus {
    # Returns a hashtable Id -> 'Applied' | 'Partial' | 'NotApplied' | 'NotApplicable'
    $result = @{}
    foreach ($item in (Get-QpCatalog privacy).Items) {
        $states = @($item.Actions | ForEach-Object { Test-QpActionApplied $_ })
        $relevant = @($states | Where-Object { $null -ne $_ })
        if ($relevant.Count -eq 0) { $result[$item.Id] = 'NotApplicable'; continue }
        $done = @($relevant | Where-Object { $_ }).Count
        if ($done -eq $relevant.Count) { $result[$item.Id] = 'Applied' }
        elseif ($done -gt 0) { $result[$item.Id] = 'Partial' }
        else { $result[$item.Id] = 'NotApplied' }
    }
    return $result
}

function Invoke-QpPrivacy {
    param([string[]]$Ids, [switch]$Preview)
    $items = @((Get-QpCatalog privacy).Items | Where-Object { $Ids -contains $_.Id })
    if ($items.Count -eq 0) { Write-QpLog 'Nothing selected.' 'WARN'; return }
    $own = (-not $Preview) -and (-not $script:Session)   # join an existing restore point (one-click) if there is one
    if ($Preview) { Write-QpLog 'PREVIEW - nothing will be changed.' 'STEP' } elseif ($own) { Start-QpSession 'privacy' }
    foreach ($item in $items) {
        Write-QpLog $item.Title 'STEP'
        foreach ($a in $item.Actions) { Invoke-QpAction -Action $a -Preview:$Preview }
    }
    if ($Preview) { Write-QpLog 'Preview finished. Nothing was changed.' 'OK' } elseif ($own) { Stop-QpSession }
}

#endregion

#region ---------------------------------------------------------------- apps

function Test-QpProtectedApp {
    param([string]$Name)
    return ($Name -match $script:ProtectedAppPattern)
}

function Get-QpBloatApps {
    $installed = @(Get-AppxPackage -ErrorAction SilentlyContinue)
    foreach ($item in (Get-QpCatalog apps).Items) {
        $pkg = $installed | Where-Object { $_.Name -like $item.Name } | Select-Object -First 1
        if ($pkg -and -not (Test-QpProtectedApp $pkg.Name)) {
            [pscustomobject]@{
                Name        = $pkg.Name
                Title       = $item.Title
                Description = $item.Description
                Recommended = [bool]$item.Recommended
            }
        }
    }
}

function Invoke-QpRemoveApps {
    param([string[]]$Names, [switch]$Deprovision, [switch]$Preview)
    if (-not $Names) { Write-QpLog 'Nothing selected.' 'WARN'; return }
    $own = (-not $Preview) -and (-not $script:Session)
    if ($Preview) { Write-QpLog 'PREVIEW - nothing will be changed.' 'STEP' } elseif ($own) { Start-QpSession 'apps' }
    foreach ($n in $Names) {
        if (Test-QpProtectedApp $n) { Write-QpLog "$n is protected and will not be removed" 'WARN'; continue }
        $pkgs = @(Get-AppxPackage -Name $n -ErrorAction SilentlyContinue)
        if ($pkgs.Count -eq 0) { Write-QpLog "$n is not installed - skipped" 'SKIP'; continue }
        if ($Preview) { Write-QpLog "Would remove $n" 'PREVIEW'; continue }
        foreach ($p in $pkgs) {
            try {
                Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop
                Add-QpUndo @{ Type = 'Appx'; Name = $n }
                Write-QpLog "Removed $n" 'OK'
            } catch {
                Write-QpLog "Could not remove $n : $($_.Exception.Message)" 'WARN'
            }
        }
        if ($Deprovision) {
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object DisplayName -eq $n | ForEach-Object {
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null
                    Write-QpLog "$n will not be reinstalled for new user accounts" 'OK'
                } catch { }
            }
        }
    }
    if ($Preview) { Write-QpLog 'Preview finished. Nothing was changed.' 'OK' } elseif ($own) { Stop-QpSession }
}

#endregion

#region ---------------------------------------------------------------- clean-up

function Resolve-QpPaths {
    param([string[]]$Patterns)
    foreach ($pat in $Patterns) {
        $expanded = [Environment]::ExpandEnvironmentVariables($pat)
        Get-Item -Path $expanded -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer } | ForEach-Object { $_.FullName }
    }
}

function Get-QpCleanupTargets {
    foreach ($item in (Get-QpCatalog cleanup).Items) {
        $paths = @(Resolve-QpPaths $item.Paths)
        # Only count what Clean-up would actually move (respects the MinAgeHours safety rule).
        $cutoff = if ($item.MinAgeHours) { (Get-Date).AddHours(-[double]$item.MinAgeHours) } else { $null }
        $size = 0
        foreach ($p in $paths) {
            if ($cutoff) {
                foreach ($c in @(Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cutoff })) {
                    $size += if ($c.PSIsContainer) { Get-QpSize @($c.FullName) } else { $c.Length }
                }
            } else {
                $size += Get-QpSize @($p)
            }
        }
        [pscustomobject]@{
            Id          = $item.Id
            Title       = $item.Title
            Description = $item.Description
            Recommended = [bool]$item.Recommended
            Paths       = $paths
            SizeBytes   = $size
        }
    }
}

function Invoke-QpCleanup {
    param([string[]]$Ids, [switch]$Preview)
    $items = @((Get-QpCatalog cleanup).Items | Where-Object { $Ids -contains $_.Id })
    if ($items.Count -eq 0) { Write-QpLog 'Nothing selected.' 'WARN'; return }
    $own = (-not $Preview) -and (-not $script:Session)
    if ($Preview) { Write-QpLog 'PREVIEW - nothing will be moved.' 'STEP' } elseif ($own) { Start-QpSession 'cleanup' }
    $total = 0
    foreach ($item in $items) {
        Write-QpLog $item.Title 'STEP'
        if ($item.RequiresClosed -and (Get-Process -Name $item.RequiresClosed -ErrorAction SilentlyContinue)) {
            Write-QpLog "Close $($item.RequiresClosed) first - skipped" 'WARN'
            continue
        }
        $cutoff = if ($item.MinAgeHours) { (Get-Date).AddHours(-[double]$item.MinAgeHours) } else { $null }
        foreach ($root in @(Resolve-QpPaths $item.Paths)) {
            $children = @(Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue)
            if ($cutoff) { $children = @($children | Where-Object { $_.LastWriteTime -lt $cutoff }) }
            $moved = 0; $bytes = 0
            foreach ($c in $children) {
                $size = if ($c.PSIsContainer) { Get-QpSize @($c.FullName) } else { $c.Length }
                if ($Preview) { $moved++; $bytes += $size; continue }
                if (Move-QpToRecycleBin $c.FullName) { $moved++; $bytes += $size }
            }
            $total += $bytes
            if ($Preview) {
                Write-QpLog ("Would move {0} item(s), {1}, from {2}" -f $moved, (Format-QpBytes $bytes), $root) 'PREVIEW'
            } else {
                Write-QpLog ("Moved {0} item(s), {1}, from {2} to the Recycle Bin (items in use were skipped)" -f $moved, (Format-QpBytes $bytes), $root) 'OK'
                if ($moved) { Add-QpUndo @{ Type = 'Recycled'; Path = $root; Items = $moved } }
            }
        }
    }
    if ($Preview) {
        Write-QpLog ("Preview finished. About {0} could be freed." -f (Format-QpBytes $total)) 'OK'
    } else {
        Write-QpLog ("About {0} moved to the Recycle Bin. Empty the Recycle Bin yourself when you are happy - this tool never permanently deletes." -f (Format-QpBytes $total)) 'OK'
        Add-QpTotals -SpaceBytes $total
        if ($own) { Stop-QpSession }
    }
    [pscustomobject]@{ BytesFreed = [int64]$total }
}

#endregion

#region ---------------------------------------------------------------- NVIDIA

function Test-QpHostBlocked {
    param([string[]]$Lines, [string]$HostName)
    return [bool]($Lines | Where-Object { $_ -match "^\s*0\.0\.0\.0\s+$([regex]::Escape($HostName))(\s|$)" })
}

function Add-QpHostsBlock {
    param([string[]]$HostNames, [string]$Tag, [switch]$Preview)
    $lines = @(Get-Content -Path $script:HostsPath -ErrorAction SilentlyContinue)
    $missing = @($HostNames | Where-Object { -not (Test-QpHostBlocked -Lines $lines -HostName $_) })
    if ($missing.Count -eq 0) { Write-QpLog 'All listed servers are already blocked' 'OK'; return }
    if ($Preview) { foreach ($m in $missing) { Write-QpLog "Would block $m" 'PREVIEW' }; return }
    Copy-Item -Path $script:HostsPath -Destination (Join-Path $script:Session.Path 'hosts.bak') -Force
    Add-QpUndo @{ Type = 'Hosts'; Tag = $Tag }
    $add = @('') + @($missing | ForEach-Object { "0.0.0.0 $_  # $Tag" })
    Add-Content -Path $script:HostsPath -Value $add -Encoding ASCII
    foreach ($m in $missing) { Write-QpLog "Blocked $m" 'OK' }
}

function Remove-QpHostsBlock {
    param([string]$Tag)
    $lines = @(Get-Content -Path $script:HostsPath -ErrorAction SilentlyContinue)
    $keep = @($lines | Where-Object { $_ -notmatch [regex]::Escape("# $Tag") })
    Set-Content -Path $script:HostsPath -Value $keep -Encoding ASCII
    & ipconfig.exe /flushdns | Out-Null
    Write-QpLog "Removed hosts entries tagged '$Tag'" 'OK'
}

function Test-QpNeverTouch {
    # Drivers, audio and the bits people rely on are off limits, whatever a catalog entry says.
    param([string]$Name)
    if (-not $Name) { return $false }
    foreach ($p in (Get-QpCatalog vendors).NeverTouch) { if ($Name -like $p -or $Name -eq $p) { return $true } }
    return $false
}

function Test-QpVendorPresent {
    # Is this brand's software actually on this PC?
    param($Vendor)
    $d = $Vendor.Detect
    if (-not $d) { return $false }
    if ($d.Manufacturer) {
        if (-not $script:ComputerMaker) { $script:ComputerMaker = [string](Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).Manufacturer }
        if ($script:ComputerMaker -match $d.Manufacturer) { return $true }
    }
    if ($d.Gpu) {
        if ($null -eq $script:GpuNames) { $script:GpuNames = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) -join ' | ' }
        if ($script:GpuNames -match $d.Gpu) { return $true }
    }
    foreach ($p in @($d.Paths)) { if ($p -and (Test-Path ([Environment]::ExpandEnvironmentVariables($p)))) { return $true } }
    foreach ($s in @($d.Services)) { if ($s -and (Get-Service -Name $s -ErrorAction SilentlyContinue)) { return $true } }
    return $false
}

function Get-QpInstalledPrograms {
    # Ordinary installed programs (not Store apps), from the places Windows lists them.
    if ($script:InstalledPrograms) { return $script:InstalledPrograms }
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $script:InstalledPrograms = @(
        foreach ($k in $keys) {
            Get-ItemProperty -Path $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and -not $_.SystemComponent } | ForEach-Object {
                [pscustomobject]@{
                    Name      = [string]$_.DisplayName
                    Publisher = [string]$_.Publisher
                    Uninstall = [string]$(if ($_.QuietUninstallString) { $_.QuietUninstallString } else { $_.UninstallString })
                    Quiet     = [bool]$_.QuietUninstallString
                    Key       = $_.PSChildName
                }
            }
        }
    )
    return $script:InstalledPrograms
}

function Get-QpVendorStatus {
    <#
        What brand and hardware software is on this PC, and which of its background bits are still on.
        Read-only. Vendors and items that are not on this PC are left out entirely.
    #>
    $hostLines = @(Get-Content -Path $script:HostsPath -ErrorAction SilentlyContinue)
    $programs = Get-QpInstalledPrograms
    $result = foreach ($v in (Get-QpCatalog vendors).Vendors) {
        if (-not (Test-QpVendorPresent $v)) { continue }
        $items = foreach ($item in @($v.Items)) {
            $blocked = @($item.Actions | Where-Object { $_.Name -and (Test-QpNeverTouch $_.Name) })
            if ($blocked.Count) { continue }
            $states = @($item.Actions | ForEach-Object { Test-QpActionApplied $_ })
            $relevant = @($states | Where-Object { $null -ne $_ })
            if ($relevant.Count -eq 0) { continue }   # nothing of this item exists here - don't mention it
            $done = @($relevant | Where-Object { $_ }).Count
            $status = if ($done -eq $relevant.Count) { 'Applied' } elseif ($done -gt 0) { 'Partial' } else { 'NotApplied' }
            [pscustomobject]@{
                Id = $item.Id; VendorId = $v.Id; Title = $item.Title; Description = $item.Description
                Recommended = [bool]$item.Recommended; Status = $status
            }
        }
        $junk = foreach ($j in @($v.Junk)) {
            foreach ($p in @($programs | Where-Object { $_.Name -match $j.Match -and $_.Uninstall })) {
                if (Test-QpNeverTouch $p.Name) { continue }
                [pscustomobject]@{ VendorId = $v.Id; Title = $j.Title; Why = $j.Why; Name = $p.Name; Key = $p.Key; Uninstall = $p.Uninstall; Quiet = $p.Quiet }
            }
        }
        $items = @($items); $junk = @($junk)
        if ($items.Count -eq 0 -and $junk.Count -eq 0) { continue }
        [pscustomobject]@{
            Id = $v.Id; Name = $v.Name; Kind = $v.Kind; Note = $v.Note
            Items = $items; Junk = $junk
            Open = @($items | Where-Object { $_.Status -ne 'Applied' }).Count
        }
    }
    return @($result)
}

function Invoke-QpVendor {
    param([string[]]$Ids, [switch]$Preview)
    if (-not $Ids) { Write-QpLog 'Pick at least one thing first.' 'WARN'; return }
    $items = @(foreach ($v in (Get-QpCatalog vendors).Vendors) { foreach ($i in @($v.Items)) { if ($Ids -contains $i.Id) { $i } } })
    if ($items.Count -eq 0) { Write-QpLog 'Pick at least one thing first.' 'WARN'; return }
    $own = (-not $Preview) -and (-not $script:Session)
    if ($Preview) { Write-QpLog 'PREVIEW - nothing will be changed.' 'STEP' } elseif ($own) { Start-QpSession 'brands' }
    $touchedHosts = $false
    foreach ($item in $items) {
        Write-QpLog $item.Title 'STEP'
        foreach ($a in $item.Actions) {
            if ($a.Name -and (Test-QpNeverTouch $a.Name)) { Write-QpLog "$($a.Name) is on the protected list - left alone" 'SKIP'; continue }
            if ($a.Type -eq 'Hosts') { $touchedHosts = $true }
            Invoke-QpAction -Action $a -Preview:$Preview
        }
    }
    if ($Preview) {
        Write-QpLog 'Preview finished. Nothing was changed.' 'OK'
    } else {
        if ($touchedHosts) { & ipconfig.exe /flushdns | Out-Null }
        Write-QpLog 'The apps themselves still open and work. Run this again after a big brand-software update.' 'INFO'
        if ($own) { Stop-QpSession }
    }
}

function Invoke-QpVendorUninstall {
    <#
        Runs the program's own uninstaller. The window always asks first, one program at a time.
        This CANNOT be undone - the program has to be downloaded again from its maker.
    #>
    param([string[]]$Keys)
    $all = Get-QpVendorStatus
    $targets = @(foreach ($v in $all) { foreach ($j in $v.Junk) { if ($Keys -contains $j.Key) { $j } } })
    if ($targets.Count -eq 0) { Write-QpLog 'Nothing to remove.' 'WARN'; return }
    foreach ($t in $targets) {
        Write-QpLog "Removing $($t.Name) using its own uninstaller (this cannot be undone)" 'STEP'
        try {
            $cmd = $t.Uninstall.Trim()
            if ($cmd -match '^"([^"]+)"\s*(.*)$') { $exe = $matches[1]; $args = $matches[2] }
            elseif ($cmd -match '^(\S+\.exe)\s*(.*)$') { $exe = $matches[1]; $args = $matches[2] }
            else { $exe = $cmd; $args = '' }
            if ($exe -match '(?i)msiexec') { $args = ($args -replace '(?i)/I', '/X'); if ($args -notmatch '(?i)/qn|/quiet|/passive') { $args += ' /passive /norestart' } }
            $p = if ($args) { Start-Process -FilePath $exe -ArgumentList $args -PassThru -Wait -ErrorAction Stop } else { Start-Process -FilePath $exe -PassThru -Wait -ErrorAction Stop }
            Write-QpLog "$($t.Name): uninstaller finished (exit code $($p.ExitCode))" 'OK'
        } catch {
            Write-QpLog "$($t.Name) could not be removed automatically: $($_.Exception.Message). You can remove it from Settings > Apps." 'WARN'
        }
    }
    $script:InstalledPrograms = $null
    Write-QpLog 'Removed programs can be installed again from the maker''s website.' 'INFO'
}

#endregion

#region ---------------------------------------------------------------- one-click

function Get-QpRecommendedPlan {
    <# What "Quiet my PC now" would do on this PC: only recommended items that are not done yet. Read-only. #>
    $status = Get-QpPrivacyStatus
    $privacy = @((Get-QpCatalog privacy).Items | Where-Object { $_.Recommended -and $status[$_.Id] -in 'NotApplied', 'Partial' })
    # Brand and hardware items: only the recommended switch-offs. Uninstalling anything is never automatic.
    $vendors = Get-QpVendorStatus
    $vendorItems = @(foreach ($v in $vendors) { $v.Items | Where-Object { $_.Recommended -and $_.Status -ne 'Applied' } })
    $apps = @(Get-QpBloatApps | Where-Object { $_.Recommended })
    $clean = @(Get-QpCleanupTargets | Where-Object { $_.Recommended -and $_.SizeBytes -gt 0 })
    [pscustomobject]@{
        PrivacyIds    = @($privacy | ForEach-Object { $_.Id })
        PrivacyTitles = @($privacy | ForEach-Object { $_.Title })
        VendorIds     = @($vendorItems | ForEach-Object { $_.Id })
        VendorTitles  = @($vendorItems | ForEach-Object { $_.Title })
        VendorNames   = @($vendors | Where-Object { @($_.Items | Where-Object { $_.Recommended -and $_.Status -ne 'Applied' }).Count } | ForEach-Object { $_.Name })
        AppNames      = @($apps | ForEach-Object { $_.Name })
        AppTitles     = @($apps | ForEach-Object { $_.Title })
        CleanupIds    = @($clean | ForEach-Object { $_.Id })
        CleanupBytes  = [int64](($clean | Measure-Object -Property SizeBytes -Sum).Sum)
        IsEmpty       = (-not $privacy -and -not $vendorItems -and -not $apps -and -not $clean)
    }
}

function Invoke-QpRecommended {
    <#
        "Quiet my PC now": applies every recommended item that is not done yet, all inside ONE restore point,
        so "Undo everything" really undoes everything. Returns a plain summary for the Home screen.
    #>
    $plan = Get-QpRecommendedPlan
    if ($plan.IsEmpty) {
        Write-QpLog 'Nothing to do - this PC already has every recommended setting.' 'OK'
        return [pscustomobject]@{ Nothing = $true }
    }
    Start-QpSession 'one-click'
    $restore = $script:Session.Path
    $before = Get-QpSystemUsage
    if ($plan.PrivacyIds.Count) { Invoke-QpPrivacy -Ids $plan.PrivacyIds }
    if ($plan.VendorIds.Count)  { Invoke-QpVendor -Ids $plan.VendorIds }
    if ($plan.AppNames.Count)   { Invoke-QpRemoveApps -Names $plan.AppNames -Deprovision }
    $freed = 0
    if ($plan.CleanupIds.Count) {
        $r = @(Invoke-QpCleanup -Ids $plan.CleanupIds) | Where-Object { $_ -and $_.PSObject.Properties['BytesFreed'] } | Select-Object -Last 1
        if ($r) { $freed = $r.BytesFreed }
    }
    $entries = @($script:Session.Entries)
    # Services and startup items that were switched off release memory straight away; a restart frees more.
    Start-Sleep -Seconds 2
    $after = Get-QpSystemUsage
    $memFreed = [int64][Math]::Max(0, $before.MemUsed - $after.MemUsed)
    if ($memFreed -gt 0) { Write-QpLog ("Memory in use dropped by about {0}. A restart usually frees more." -f (Format-QpBytes $memFreed)) 'OK' }
    Add-QpTotals -MemoryBytes $memFreed -CountRun
    $summary = [pscustomobject]@{
        Nothing       = $false
        Settings      = $plan.PrivacyIds.Count
        AppsRemoved   = @($entries | Where-Object { $_.Type -eq 'Appx' }).Count
        BrandsQuieted = @($plan.VendorNames)
        BytesFreed    = [int64]$freed
        MemoryFreed   = $memFreed
        RestorePoint  = $restore
    }
    Stop-QpSession
    return $summary
}

#endregion

#region ---------------------------------------------------------------- threats (Defender first, heuristics labelled)

# Quietpane does not identify malware families itself. Microsoft Defender names a threat; this code
# translates that name into plain words and an impact tier, and always keeps Defender's own name and
# classification visible. Quietpane's own checks are reported as heuristics and never claim a family.

$script:SeverityRank = @{ Critical = 0; High = 1; Medium = 2; Low = 3; Info = 4 }
$script:DefenderStatusMap = @{ '0' = 'Detected'; '1' = 'Detected'; '2' = 'Removed'; '3' = 'Quarantined'; '4' = 'Removed'; '5' = 'Allowed'; '6' = 'Removed' }

function Get-QpDefenderState {
    <# Can we ask Defender anything, and should we trust the answer? Never throws. #>
    $s = [pscustomobject]@{
        Available = $false; RealTime = $false; SignatureAge = $null
        CanScan = $false; CanRemediate = $false; ThirdParty = @(); Note = ''
    }
    $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($mp) {
        $s.Available = $true
        $s.RealTime = [bool]$mp.RealTimeProtectionEnabled
        $s.SignatureAge = [int]$mp.AntivirusSignatureAge
        $s.CanScan = [bool](Get-Command Start-MpScan -ErrorAction SilentlyContinue)
        $s.CanRemediate = [bool](Get-Command Remove-MpThreat -ErrorAction SilentlyContinue)
    }
    try {
        $av = @(Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop | ForEach-Object { [string]$_.displayName })
        $s.ThirdParty = @($av | Where-Object { $_ -and $_ -notmatch '(?i)(windows|microsoft) defender' })
    } catch { }
    if (-not $s.Available) {
        $s.Note = 'Microsoft Defender could not be reached, so only Quietpane''s own checks ran. Nothing here can confirm a virus by name.'
    } elseif ($s.ThirdParty.Count) {
        $s.Note = 'Another antivirus is installed (' + ($s.ThirdParty -join ', ') + '), so Defender may be standing down and its list of threats can look empty. Check that program as well.'
    } elseif (-not $s.RealTime) {
        $s.Note = 'Defender real-time protection is off, so new threats are not being caught as they arrive.'
    }
    return $s
}

function Resolve-QpThreatInfo {
    <# Defender's threat name -> Quietpane tier and plain-language note. Nothing is ever dropped. #>
    param([string]$ThreatName, [int]$VendorSeverity = 0)
    $cat = Get-QpCatalog threats
    foreach ($f in $cat.Families) {
        if ($ThreatName -match $f.Match) {
            return [pscustomobject]@{ Family = $f.Family; Tier = $f.Tier; Category = $f.Category; What = $f.What; Why = $f.Why; MatchedBy = 'family' }
        }
    }
    foreach ($c in $cat.CategoryFallback) {
        if ($ThreatName -match $c.Match) {
            return [pscustomobject]@{ Family = ''; Tier = $c.Tier; Category = $c.Category; What = $c.What; Why = $c.Why; MatchedBy = 'category' }
        }
    }
    $tier = if ($cat.SeverityFallback["$VendorSeverity"]) { $cat.SeverityFallback["$VendorSeverity"] } else { 'Medium' }
    [pscustomobject]@{
        Family = ''; Tier = $tier; Category = 'Malware'
        What = 'Defender reported this, and Quietpane has no plain-language note for this name yet.'
        Why = 'Follow what Defender recommends. The exact name is in the technical details.'
        MatchedBy = 'severity'
    }
}

function Get-QpFileHash {
    param([string]$Path, [int64]$MaxBytes = 104857600)
    try {
        if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
        if ((Get-Item -LiteralPath $Path -Force -ErrorAction Stop).Length -gt $MaxBytes) { return '' }
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
    } catch { return '' }   # locked or unreadable: a missing hash is fine, a failed scan is not
}

function New-QpFinding {
    <# The one shape every finding has, whoever found it. #>
    param(
        [string]$Section = 'Threats',
        [ValidateSet('Critical', 'High', 'Medium', 'Low', 'Info')][string]$Severity = 'Info',
        [string]$ThreatName = '', [string]$Family = '', [string]$Category = '',
        [string]$Source = 'Quietpane check', [string]$Method = '',
        [string]$Object = '', [string]$Path = '', [string]$Sha256 = '',
        [ValidateSet('Confirmed', 'Likely', 'Heuristic', 'Informational')][string]$Confidence = 'Informational',
        [string]$VendorName = '', [string]$VendorSeverity = '',
        $FirstSeen = $null, [string]$Recommended = '', [string]$Status = 'Detected',
        [string]$What = '', [string]$Why = '', [string]$Technical = '',
        [string]$Title = '', [string]$Detail = '',
        [string]$ThreatId = '', [bool]$VendorActive = $false
    )
    $seed = '{0}|{1}|{2}|{3}' -f $Source, $ThreatName, $Path, $Object
    $bytes = [Security.Cryptography.SHA1]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($seed))
    $id = (($bytes | Select-Object -First 8) | ForEach-Object { $_.ToString('x2') }) -join ''
    if (-not $Title) { $Title = if ($ThreatName) { $ThreatName } else { $Object } }
    if (-not $Detail) { $Detail = $Technical }
    [pscustomobject]@{
        Id = $id; Section = $Section; Severity = $Severity
        ThreatName = $ThreatName; Family = $Family; Category = $Category
        Source = $Source; Method = $Method
        Object = $Object; Path = $Path; Sha256 = $Sha256
        Confidence = $Confidence; VendorName = $VendorName; VendorSeverity = $VendorSeverity
        FirstSeen = $(if ($FirstSeen) { $FirstSeen } else { Get-Date })
        Recommended = $Recommended; Status = $Status
        What = $What; Why = $Why; Technical = $Technical
        Title = $Title; Detail = $Detail
        ThreatId = $ThreatId; VendorActive = $VendorActive
    }
}

function Get-QpDefenderFindings {
    <# Everything Defender has detected on this PC, in Quietpane's shape. Read-only. #>
    $state = Get-QpDefenderState
    if (-not $state.Available) { return @() }
    $threats = @{}
    foreach ($t in @(Get-MpThreat -ErrorAction SilentlyContinue)) { $threats["$($t.ThreatID)"] = $t }
    $seen = @{}
    $out = foreach ($d in @(Get-MpThreatDetection -ErrorAction SilentlyContinue | Sort-Object InitialDetectionTime -Descending)) {
        $t = $threats["$($d.ThreatID)"]
        $name = if ($t -and $t.ThreatName) { [string]$t.ThreatName } else { "Unnamed detection $($d.ThreatID)" }
        $vendorSev = if ($t) { [int]$t.SeverityID } else { 0 }
        $info = Resolve-QpThreatInfo -ThreatName $name -VendorSeverity $vendorSev
        $path = ''; $kind = 'file'
        foreach ($r in @($d.Resources | Where-Object { $_ })) {
            if ($r -match '^(?<k>[a-z]+):_?(?<v>.+)$') { if (-not $path) { $kind = $matches['k']; $path = $matches['v'] } }
            elseif (-not $path) { $path = [string]$r }
        }
        $key = "$name|$path"
        if ($seen.ContainsKey($key)) { continue }   # keep only the newest detection of the same thing
        $seen[$key] = $true
        $status = $script:DefenderStatusMap["$([int]$d.ThreatStatusID)"]
        if (-not $status) { $status = 'Detected' }
        $confidence = if ($name -match '^Behavior:') { 'Likely' } else { 'Confirmed' }
        $recommended = if ($status -eq 'Detected') { 'Let Defender remove it, or quarantine it with Quietpane.' } else { "Already handled by Defender ($status). Nothing more to do." }
        $tech = @(
            "Defender threat name: $name"
            "Defender severity: $vendorSev (5 = severe, 4 = high, 2 = moderate, 1 = low)"
            "Defender status: $($d.ThreatStatusID) ($status)"
            "Resource: $kind $path"
            "Detected: $($d.InitialDetectionTime)"
            "Ran before it was caught: $(if ($t) { $t.DidThreatExecute } else { 'unknown' })"
            "Matched Quietpane note by: $($info.MatchedBy)"
        ) -join "`n"
        New-QpFinding -Section 'Threats' -Severity $info.Tier -ThreatName $name -Family $info.Family -Category $info.Category `
            -Source 'Microsoft Defender' -Method 'Antivirus signature' -Object (Split-Path $path -Leaf) -Path $path `
            -Sha256 (Get-QpFileHash $path) -Confidence $confidence -VendorName $name -VendorSeverity "$vendorSev" `
            -FirstSeen $d.InitialDetectionTime -Recommended $recommended -Status $status `
            -What $info.What -Why $info.Why -Technical $tech `
            -Title $(if ($info.Family) { $info.Family } else { $name }) `
            -ThreatId "$($d.ThreatID)" -VendorActive $(if ($t) { [bool]$t.IsActive } else { $false })
    }
    return @($out)
}

function Invoke-QpThreatScan {
    <#
        Asks Microsoft Defender to scan, then reads what it found. Quietpane never opens or runs a
        detected file. Quick scan covers the places malware normally lives; a custom scan takes a folder.
    #>
    param([ValidateSet('Quick', 'Full', 'Custom')][string]$Type = 'Quick', [string]$Path)
    $state = Get-QpDefenderState
    if (-not $state.Available -or -not $state.CanScan) {
        Write-QpLog 'Microsoft Defender is not available here, so no antivirus scan was run. Quietpane''s own checks still work.' 'WARN'
        return [pscustomobject]@{ Ran = $false; Findings = @(); State = $state }
    }
    if ($state.ThirdParty.Count) { Write-QpLog $state.Note 'INFO' }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        if ($Type -eq 'Custom') {
            if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { Write-QpLog 'That folder could not be found - nothing scanned.' 'WARN'; return [pscustomobject]@{ Ran = $false; Findings = @(); State = $state } }
            Write-QpLog "Asking Defender to scan $Path ..." 'STEP'
            Start-MpScan -ScanType CustomScan -ScanPath $Path -ErrorAction Stop
        } else {
            Write-QpLog "Asking Defender to run a $($Type.ToLower()) scan. This is Defender's own engine, not ours." 'STEP'
            Start-MpScan -ScanType "$($Type)Scan" -ErrorAction Stop
        }
        Write-QpLog ("Defender finished in {0:N0} seconds." -f $sw.Elapsed.TotalSeconds) 'OK'
    } catch {
        Write-QpLog "Defender could not complete the scan: $($_.Exception.Message)" 'WARN'
        return [pscustomobject]@{ Ran = $false; Findings = @(Get-QpDefenderFindings); State = $state }
    }
    [pscustomobject]@{ Ran = $true; Findings = @(Get-QpDefenderFindings); State = $state; Seconds = [int]$sw.Elapsed.TotalSeconds }
}

function Write-QpAudit {
    <# Append-only record of everything Quietpane did to a threat, including failures. #>
    param([string]$FindingId, [string]$Action, [string]$Result, [string]$Object = '', [string]$Note = '')
    try {
        if (-not (Test-Path $script:DataRoot)) { New-Item -ItemType Directory -Path $script:DataRoot -Force | Out-Null }
        $line = [pscustomobject]@{
            Time = (Get-Date).ToString('s'); FindingId = $FindingId; Action = $Action; Result = $Result
            Object = $Object; Note = $Note; User = "$env:USERDOMAIN\$env:USERNAME"
        } | ConvertTo-Json -Compress
        Add-Content -Path (Join-Path $script:DataRoot 'audit.log') -Value $line -Encoding UTF8
    } catch { Write-QpLog "Could not write the audit log: $($_.Exception.Message)" 'WARN' }
}

function Get-QpAllowList {
    $file = Join-Path $script:DataRoot 'allowed.json'
    if (-not (Test-Path $file)) { return @() }
    try { return @(Get-Content $file -Raw | ConvertFrom-Json) } catch { return @() }
}

function Add-QpAllow {
    <#
        The user chose to leave something in place. This is Quietpane's own note only: it never creates a
        Defender exclusion and never weakens any future scan. The item keeps showing up, marked Allowed.
    #>
    param([string]$FindingId, [string]$ThreatName, [string]$Path)
    $all = @(Get-QpAllowList | Where-Object { $_.FindingId -ne $FindingId })
    $all += [pscustomobject]@{ FindingId = $FindingId; ThreatName = $ThreatName; Path = $Path; Allowed = (Get-Date).ToString('s') }
    try {
        if (-not (Test-Path $script:DataRoot)) { New-Item -ItemType Directory -Path $script:DataRoot -Force | Out-Null }
        $all | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $script:DataRoot 'allowed.json') -Encoding UTF8
        Write-QpLog "Left in place on purpose: $ThreatName. It is still on this PC, and Quietpane will keep showing it." 'WARN'
        Write-QpAudit -FindingId $FindingId -Action 'Allow' -Result 'Recorded' -Object $Path -Note 'Quietpane note only - no Defender exclusion was created'
    } catch { Write-QpLog "Could not record that choice: $($_.Exception.Message)" 'WARN' }
}

function Get-QpFailureReason {
    <# Say what actually went wrong, rather than guessing. #>
    param($Ex)
    $name = if ($Ex) { $Ex.GetType().Name } else { '' }
    switch -Regex ($name) {
        'UnauthorizedAccessException' { return 'Windows would not allow it. Quietpane needs administrator rights, or the file is protected.' }
        'FileNotFoundException|DirectoryNotFoundException' { return 'It is not there any more. Run the check again.' }
        'IOException' { return 'The file is in use, so it could not be moved. Close whatever is using it, or restart and try again.' }
        default { return $(if ($Ex) { $Ex.Message } else { 'It did not work.' }) }
    }
}

function Get-QpQuarantineRoot {
    <# The quarantine folder, locked down the first time it is needed. #>
    $root = Join-Path $script:DataRoot 'quarantine'
    if (-not (Test-Path $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        try {
            # Only SYSTEM and administrators may look inside. Inheritance off, so a wide-open
            # ProgramData permission cannot leak in.
            & icacls.exe $root /inheritance:r /grant:r 'SYSTEM:(OI)(CI)F' 'Administrators:(OI)(CI)F' | Out-Null
        } catch { Write-QpLog "Could not lock down the quarantine folder: $($_.Exception.Message)" 'WARN' }
    }
    return $root
}

function Test-QpProtectedPath {
    <# Places Quietpane will never move, recycle or delete, whatever a finding says. #>
    param([string]$Path)
    if (-not $Path) { return $true }
    $p = ''
    try { $p = [IO.Path]::GetFullPath($Path) } catch { return $true }
    if ($p.Length -lt 8) { return $true }                                  # a drive root or similar
    if (Test-Path -LiteralPath $p -PathType Container) { return $true }    # only ever single files
    $protected = @(
        [Environment]::GetFolderPath('Windows')
        (Join-Path $env:WINDIR 'System32'), (Join-Path $env:WINDIR 'SysWOW64'), (Join-Path $env:WINDIR 'WinSxS')
        (Join-Path $env:SystemDrive '\Program Files\WindowsApps')
        $env:ProgramFiles, ${env:ProgramFiles(x86)}
        $script:DataRoot
    ) | Where-Object { $_ }
    foreach ($root in $protected) {
        if ($p -eq $root -or $p.StartsWith(($root.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Test-QpFindingStillTrue {
    <# Before anything destructive: is this still the same file we were told about? #>
    param($Finding)
    if (-not $Finding.Path) { return [pscustomobject]@{ Ok = $false; Why = 'This finding has no file attached, so there is nothing to act on.' } }
    if (-not (Test-Path -LiteralPath $Finding.Path -PathType Leaf)) { return [pscustomobject]@{ Ok = $false; Why = 'That file is not there any more. Run the check again.' } }
    if (Test-QpProtectedPath $Finding.Path) { return [pscustomobject]@{ Ok = $false; Why = 'That file lives in a protected Windows folder. Quietpane will not touch it - use Windows Security instead.' } }
    if ($Finding.Sha256) {
        $now = Get-QpFileHash $Finding.Path
        if ($now -and $now -ne $Finding.Sha256) { return [pscustomobject]@{ Ok = $false; Why = 'That file has changed since the check ran, so it may not be the same thing. Run the check again.' } }
    }
    return [pscustomobject]@{ Ok = $true; Why = '' }
}

function Invoke-QpQuarantine {
    <#
        Moves the file into Quietpane's quarantine: renamed so it cannot run, with everything needed
        to put it back. The original folder, name, times and hash are recorded.
    #>
    param([Parameter(Mandatory)]$Finding)
    $check = Test-QpFindingStillTrue $Finding
    if (-not $check.Ok) { return [pscustomobject]@{ Ok = $false; Status = 'Failed'; Note = $check.Why } }
    $root = Get-QpQuarantineRoot
    # The quarantine folder is deliberately locked to administrators. Check we can write before moving anything.
    try {
        $probe = Join-Path $root ('.write-test-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $probe -Force -ErrorAction Stop | Out-Null
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    } catch {
        return [pscustomobject]@{ Ok = $false; Status = 'Failed'; Note = 'The quarantine folder is locked to administrators, and Quietpane is not running as one. Start it with "Start Quietpane", which asks Windows for permission.' }
    }
    $id = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $Finding.Id
    $dir = Join-Path $root $id
    try {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $src = Get-Item -LiteralPath $Finding.Path -Force
        $hash = if ($Finding.Sha256) { $Finding.Sha256 } else { Get-QpFileHash $Finding.Path }
        $meta = [pscustomobject]@{
            Id = $id; OriginalPath = $src.FullName; FileName = $src.Name; Size = $src.Length
            Sha256 = $hash; ThreatName = $Finding.ThreatName; Family = $Finding.Family
            Severity = $Finding.Severity; Source = $Finding.Source; Confidence = $Finding.Confidence
            QuarantinedAt = (Get-Date).ToString('s'); Status = 'Quarantined'
            CreationTime = $src.CreationTime.ToString('o'); LastWriteTime = $src.LastWriteTime.ToString('o')
            Attributes = "$($src.Attributes)"
        }
        $meta | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $dir 'meta.json') -Encoding UTF8
        Move-Item -LiteralPath $src.FullName -Destination (Join-Path $dir 'payload.bin') -Force -ErrorAction Stop
        Set-ItemProperty -LiteralPath (Join-Path $dir 'payload.bin') -Name Attributes -Value 'Normal' -ErrorAction SilentlyContinue
        Write-QpLog "Quarantined $($src.Name). It cannot run from there, and you can put it back any time." 'OK'
        Write-QpAudit -FindingId $Finding.Id -Action 'Quarantine' -Result 'Quarantined' -Object $src.FullName -Note $id
        [pscustomobject]@{ Ok = $true; Status = 'Quarantined'; Note = "Moved into Quietpane's quarantine. You can restore it from the Safety scan tab."; QuarantineId = $id }
    } catch {
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        $why = Get-QpFailureReason $_.Exception
        Write-QpLog "Could not quarantine $($Finding.Path): $why" 'ERROR'
        Write-QpAudit -FindingId $Finding.Id -Action 'Quarantine' -Result 'Failed' -Object $Finding.Path -Note $_.Exception.Message
        [pscustomobject]@{ Ok = $false; Status = 'Failed'; Note = $why }
    }
}

function Get-QpQuarantineItems {
    $root = Join-Path $script:DataRoot 'quarantine'
    if (-not (Test-Path $root)) { return @() }
    @(Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | ForEach-Object {
        $metaFile = Join-Path $_.FullName 'meta.json'
        if (-not (Test-Path $metaFile)) { return }
        try {
            $m = Get-Content $metaFile -Raw | ConvertFrom-Json
            $payload = Join-Path $_.FullName 'payload.bin'
            [pscustomobject]@{
                Id = $m.Id; FileName = $m.FileName; OriginalPath = $m.OriginalPath; Size = [int64]$m.Size
                Sha256 = $m.Sha256; ThreatName = $m.ThreatName; Severity = $m.Severity; Source = $m.Source
                QuarantinedAt = $m.QuarantinedAt; Folder = $_.FullName; HasPayload = (Test-Path $payload)
            }
        } catch { }
    })
}

function Restore-QpQuarantineItem {
    <# Puts a quarantined file back exactly where it was, but only if it is still byte-for-byte the same. #>
    param([Parameter(Mandatory)][string]$Id)
    $item = @(Get-QpQuarantineItems | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    if (-not $item) { return [pscustomobject]@{ Ok = $false; Status = 'Failed'; Note = 'That quarantined item is no longer there.' } }
    $payload = Join-Path $item.Folder 'payload.bin'
    if (-not (Test-Path $payload)) { return [pscustomobject]@{ Ok = $false; Status = 'Failed'; Note = 'The quarantined file is missing.' } }
    if ($item.Sha256) {
        $now = Get-QpFileHash $payload
        if ($now -and $now -ne $item.Sha256) {
            Write-QpAudit -FindingId $Id -Action 'Restore' -Result 'Failed' -Object $item.OriginalPath -Note 'hash mismatch'
            return [pscustomobject]@{ Ok = $false; Status = 'Failed'; Note = 'The quarantined file does not match what was stored, so it was left alone.' }
        }
    }
    try {
        $dest = $item.OriginalPath
        $parent = Split-Path $dest -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        if (Test-Path -LiteralPath $dest) { return [pscustomobject]@{ Ok = $false; Status = 'Failed'; Note = "Something is already at $dest, so nothing was overwritten." } }
        Move-Item -LiteralPath $payload -Destination $dest -ErrorAction Stop
        $meta = Get-Content (Join-Path $item.Folder 'meta.json') -Raw | ConvertFrom-Json
        try {
            $f = Get-Item -LiteralPath $dest -Force
            $f.CreationTime = [datetime]::Parse($meta.CreationTime)
            $f.LastWriteTime = [datetime]::Parse($meta.LastWriteTime)
        } catch { }
        Remove-Item -LiteralPath $item.Folder -Recurse -Force -ErrorAction SilentlyContinue
        Write-QpLog "Restored $($item.FileName) to $dest" 'OK'
        Write-QpAudit -FindingId $Id -Action 'Restore' -Result 'Restored' -Object $dest
        [pscustomobject]@{ Ok = $true; Status = 'Restored'; Note = "Put back at $dest. Your antivirus may catch it again straight away." }
    } catch {
        Write-QpAudit -FindingId $Id -Action 'Restore' -Result 'Failed' -Object $item.OriginalPath -Note $_.Exception.Message
        [pscustomobject]@{ Ok = $false; Status = 'Failed'; Note = $_.Exception.Message }
    }
}

function Remove-QpQuarantineItem {
    <# Deletes a quarantined file for good. There is no undo, and the window asks first. #>
    param([Parameter(Mandatory)][string]$Id, [switch]$Force)
    if (-not $Force) { return [pscustomobject]@{ Ok = $false; Status = 'Failed'; Note = 'Permanent deletion has to be confirmed.' } }
    $item = @(Get-QpQuarantineItems | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    if (-not $item) { return [pscustomobject]@{ Ok = $false; Status = 'Failed'; Note = 'That quarantined item is no longer there.' } }
    try {
        Remove-Item -LiteralPath $item.Folder -Recurse -Force -ErrorAction Stop
        Write-QpLog "Deleted $($item.FileName) for good. This one cannot be undone." 'OK'
        Write-QpAudit -FindingId $Id -Action 'DeletePermanently' -Result 'Deleted' -Object $item.OriginalPath -Note 'from quarantine'
        [pscustomobject]@{ Ok = $true; Status = 'Removed'; Note = 'Deleted for good.' }
    } catch {
        Write-QpAudit -FindingId $Id -Action 'DeletePermanently' -Result 'Failed' -Object $item.OriginalPath -Note $_.Exception.Message
        [pscustomobject]@{ Ok = $false; Status = 'Failed'; Note = $_.Exception.Message }
    }
}

function Invoke-QpRemediate {
    <#
        What happens to a finding. Defender first for things Defender found, then Quietpane's own
        quarantine, the Recycle Bin, or - only when the user says so outright - permanent deletion.
    #>
    param([Parameter(Mandatory)]$Finding, [ValidateSet('Defender', 'Quarantine', 'RecycleBin', 'Delete', 'Allow')][string]$Action = 'Defender', [switch]$Force)
    if ($Action -eq 'Allow') {
        Add-QpAllow -FindingId $Finding.Id -ThreatName $Finding.ThreatName -Path $Finding.Path
        return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Allowed'; Ok = $true; Note = 'Left in place at your request.' }
    }
    if ($Action -in 'Quarantine', 'RecycleBin', 'Delete') {
        if (-not (Test-QpAdmin)) {
            Write-QpAudit -FindingId $Finding.Id -Action $Action -Result 'Failed' -Object $Finding.Path -Note 'not running as administrator'
            return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Failed'; Ok = $false; Note = 'Quietpane needs administrator rights for this. Start it again with "Start Quietpane", which asks Windows for permission.' }
        }
        if ($Action -eq 'Quarantine') {
            $r = Invoke-QpQuarantine -Finding $Finding
            return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = $r.Status; Ok = $r.Ok; Note = $r.Note }
        }
        $check = Test-QpFindingStillTrue $Finding
        if (-not $check.Ok) {
            Write-QpAudit -FindingId $Finding.Id -Action $Action -Result 'Failed' -Object $Finding.Path -Note $check.Why
            return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Failed'; Ok = $false; Note = $check.Why }
        }
        if ($Action -eq 'RecycleBin') {
            if (Move-QpToRecycleBin $Finding.Path) {
                Write-QpLog "Moved $($Finding.Path) to the Recycle Bin. It is still on this PC until you empty the bin." 'OK'
                Write-QpAudit -FindingId $Finding.Id -Action 'RecycleBin' -Result 'Removed' -Object $Finding.Path
                return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Removed'; Ok = $true; Note = 'In your Recycle Bin. Empty the bin to finish the job, or restore it from there.' }
            }
            Write-QpAudit -FindingId $Finding.Id -Action 'RecycleBin' -Result 'Failed' -Object $Finding.Path -Note 'move failed'
            return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Failed'; Ok = $false; Note = 'It could not be moved - it is probably in use. Close what is using it, or restart and try again.' }
        }
        # Delete: gone for good, and only ever when the window has asked outright.
        if (-not $Force) { return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Failed'; Ok = $false; Note = 'Permanent deletion has to be confirmed first.' } }
        try {
            Remove-Item -LiteralPath $Finding.Path -Force -ErrorAction Stop
            Write-QpLog "Deleted $($Finding.Path) for good. This one cannot be undone." 'OK'
            Write-QpAudit -FindingId $Finding.Id -Action 'DeletePermanently' -Result 'Deleted' -Object $Finding.Path
            return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Removed'; Ok = $true; Note = 'Deleted for good.' }
        } catch {
            $why = Get-QpFailureReason $_.Exception
            Write-QpAudit -FindingId $Finding.Id -Action 'DeletePermanently' -Result 'Failed' -Object $Finding.Path -Note $_.Exception.Message
            return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Failed'; Ok = $false; Note = $why }
        }
    }
    if ($Finding.Source -ne 'Microsoft Defender') {
        Write-QpLog 'Only Defender can remove its own detections. This finding came from a Quietpane check, so there is nothing for Defender to remove.' 'WARN'
        return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Failed'; Ok = $false; Note = 'Not a Defender detection.' }
    }
    $state = Get-QpDefenderState
    if (-not $state.CanRemediate) {
        Write-QpAudit -FindingId $Finding.Id -Action 'Remove' -Result 'Failed' -Object $Finding.Path -Note 'Defender remediation unavailable'
        return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Failed'; Ok = $false; Note = 'Defender cannot be asked to remove anything on this PC.' }
    }
    if (-not (Test-QpAdmin)) {
        Write-QpLog 'Administrator rights are needed before Defender will remove anything. Nothing was changed.' 'WARN'
        Write-QpAudit -FindingId $Finding.Id -Action 'Remove' -Result 'Failed' -Object $Finding.Path -Note 'not running as administrator'
        return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Failed'; Ok = $false; Note = 'Quietpane needs administrator rights for this. Close it and start it again with "Start Quietpane", which asks Windows for permission.' }
    }
    Write-QpLog "Asking Defender to deal with $($Finding.ThreatName)" 'STEP'
    $hadFile = $Finding.Path -and (Test-Path -LiteralPath $Finding.Path)
    $tried = @()
    try {
        # A targeted scan of the file is what actually makes Defender clean it. Remove-MpThreat only ever
        # touches threats Defender still counts as active, which is why it can quietly do nothing.
        if ($hadFile) {
            $mp = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
            if (Test-Path $mp) {
                & $mp -Scan -ScanType 3 -File $Finding.Path | Out-Null
                $tried += "MpCmdRun -Scan -File (exit $LASTEXITCODE)"
            }
        }
        if ($Finding.VendorActive -or -not $hadFile) {
            $tried += 'Remove-MpThreat'
            Remove-MpThreat -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        Write-QpLog "Defender returned an error: $($_.Exception.Message)" 'WARN'
    }
    # Never report success without checking. A claim of "removed" has to be true.
    Start-Sleep -Milliseconds 800
    $stillThere = $Finding.Path -and (Test-Path -LiteralPath $Finding.Path)
    if ($hadFile -and -not $stillThere) {
        Write-QpLog "Defender removed $($Finding.Path)" 'OK'
        Write-QpAudit -FindingId $Finding.Id -Action 'Remove' -Result 'Removed' -Object $Finding.Path -Note ($tried -join ' + ')
        return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Removed'; Ok = $true; Note = 'Defender removed the file. It is in Defender''s own quarantine, and Windows Security can restore it.' }
    }
    $now = @(Get-MpThreat -ErrorAction SilentlyContinue | Where-Object { "$($_.ThreatID)" -eq $Finding.ThreatId })
    if (-not $hadFile -and $now.Count -and -not $now[0].IsActive) {
        Write-QpLog 'Defender says this one is no longer active. Nothing is left to remove.' 'OK'
        Write-QpAudit -FindingId $Finding.Id -Action 'Remove' -Result 'AlreadyHandled' -Object $Finding.Path -Note ($tried -join ' + ')
        return [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Removed'; Ok = $true; Note = 'Defender had already dealt with this one.' }
    }
    $note = 'Defender did not remove it. Open Windows Security > Protection history and act there, or leave it and we will offer quarantine in the next version.'
    Write-QpLog "Defender did not remove $($Finding.Path). Nothing was changed by Quietpane." 'WARN'
    Write-QpAudit -FindingId $Finding.Id -Action 'Remove' -Result 'Failed' -Object $Finding.Path -Note ("tried: " + ($tried -join ' + '))
    [pscustomobject]@{ Id = $Finding.Id; Action = $Action; Status = 'Failed'; Ok = $false; Note = $note }
}

#endregion

#region ---------------------------------------------------------------- scan (read-only)

function Invoke-QpAudit {
    <#
        Read-only health, privacy and malware check. Writes an HTML report and returns a summary.
        Nothing on the PC is changed.
    #>
    param([string]$OutFile = (Join-Path ([Environment]::GetFolderPath('Desktop')) ("Quietpane-Report-{0}.html" -f (Get-Date -Format 'yyyyMMdd-HHmm'))))

    $findings = New-Object System.Collections.ArrayList
    $isAdmin = Test-QpAdmin
    function Add-Finding([string]$Section, [string]$Severity, [string]$Title, [string]$Detail = '') {
        # Quietpane's own checks. They are heuristics: useful signals, never proof, and never a family name.
        $confidence = if ($Severity -eq 'Info') { 'Informational' } else { 'Heuristic' }
        [void]$findings.Add((New-QpFinding -Section $Section -Severity $Severity -Title $Title -Detail $Detail `
            -Source 'Quietpane check' -Method 'Heuristic check' -Confidence $confidence `
            -Object $Title -What $Title -Why $Detail -Technical $Detail))
    }

    $suspiciousCmd = '(?i)(cmd(\.exe)?\s+/c\s+start\s+\S*(https?:|www\.))|(\bstart\s+(https?://|www\.))|\bmshta\b|\bwscript\b|\bcscript\b|powershell[^;|]*\s-(e|enc|encodedcommand)\s|-w(indowstyle)?\s+hidden|downloadstring|\\AppData\\Local\\Temp\\|\\Users\\Public\\'
    $suspiciousTask = '(?i)reg(\.exe)?\s+add\s+\S*\\CurrentVersion\\Run|\bstart\s+\S*(https?://|www\.)|\bmshta\b|\bwscript\b|\bcscript\b|powershell[^;]*\s-(e|enc|encodedcommand)\s|downloadstring|invoke-webrequest|\\AppData\\Local\\Temp\\|\\Users\\Public\\'
    $correlationRoots = @($env:LOCALAPPDATA, $env:APPDATA, (Join-Path $env:USERPROFILE 'AppData\LocalLow'), $env:ProgramData,
        $env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:USERPROFILE 'Downloads'), ([Environment]::GetFolderPath('Desktop')), 'C:\Games') |
        Where-Object { $_ -and (Test-Path $_) }

    function Get-NearbyFolders([datetime]$When) {
        # Folders created within 3 minutes of $When - the likely source of a malicious entry.
        $hits = foreach ($r in $correlationRoots) {
            Get-ChildItem -Path $r -Directory -Force -ErrorAction SilentlyContinue |
                Where-Object { [math]::Abs(($_.CreationTime - $When).TotalMinutes) -le 3 } |
                ForEach-Object { '{0}  (created {1:yyyy-MM-dd HH:mm:ss})' -f $_.FullName, $_.CreationTime }
        }
        return @($hits)
    }

    Write-QpLog 'Scan started (read-only - nothing will be changed)' 'STEP'

    # ---- 0. What Microsoft Defender has found. Defender names threats; Quietpane only explains them.
    Write-QpLog 'Asking Microsoft Defender what it has found...' 'INFO'
    $defender = Get-QpDefenderState
    foreach ($f in @(Get-QpDefenderFindings)) { [void]$findings.Add($f) }
    if ($defender.Note) { Add-Finding 'Threats' 'Medium' 'Antivirus cover is not complete' $defender.Note }
    if ($defender.Available -and -not @($findings | Where-Object { $_.Source -eq 'Microsoft Defender' }).Count) {
        Add-Finding 'Threats' 'Info' 'Microsoft Defender has no threats on record for this PC' 'Nothing has been detected or quarantined. Quietpane cannot confirm a PC is clean on its own - it only reports what Defender knows plus its own checks below.'
    }

    # ---- 1. Startup entries
    Write-QpLog 'Checking startup entries...' 'INFO'
    # Each Run key is paired with the key where Task Manager records whether that entry is switched off.
    $sa = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    $runKeys = @(
        @{ Key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKCU:\$sa\Run" },
        @{ Key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Approved = $null },
        @{ Key = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$sa\Run" },
        @{ Key = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Approved = $null },
        @{ Key = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$sa\Run32" },
        @{ Key = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'; Approved = $null },
        @{ Key = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run'; Approved = $null },
        @{ Key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run'; Approved = $null })
    function Get-DisabledNames([string]$ApprovedKey) {
        # Task Manager stores a switched-off entry with an odd first byte (usually 03).
        $names = @{}
        if (-not $ApprovedKey) { return $names }
        $p = Get-ItemProperty -Path $ApprovedKey -ErrorAction SilentlyContinue
        if ($p) { $p.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object { if ($_.Value -is [byte[]] -and $_.Value.Length -and ($_.Value[0] -band 1)) { $names[$_.Name] = $true } } }
        return $names
    }
    function Test-StartupTarget([string]$Command) {
        # $true if the program a startup command points to exists (or if that can't be worked out).
        try {
            $c = [Environment]::ExpandEnvironmentVariables("$Command").Trim()
            if (-not $c) { return $true }
            $exePath = if ($c -match '^"([^"]+)"') { $matches[1] } elseif ($c -match '^(.+?\.(exe|com|bat|cmd|vbs|js|ps1|scr))(\s|$)') { $matches[1] } else { ($c -split '\s+')[0] }
            if ([IO.Path]::IsPathRooted($exePath)) { return (Test-Path -LiteralPath $exePath) }
            return [bool](Get-Command $exePath -CommandType Application -ErrorAction SilentlyContinue)
        } catch { return $true }
    }
    $startupTotal = 0
    $startupOn = 0
    foreach ($rk in $runKeys) {
        $p = Get-ItemProperty -Path $rk.Key -ErrorAction SilentlyContinue
        if (-not $p) { continue }
        $off = Get-DisabledNames $rk.Approved
        foreach ($prop in ($p.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' })) {
            $startupTotal++
            $disabled = $off.ContainsKey($prop.Name)
            $exists = Test-StartupTarget $prop.Value
            if (-not $disabled -and $exists) { $startupOn++ }
            $state = if ($disabled) { ' (disabled in Task Manager)' } else { '' }
            $detail = "$($rk.Key)`n$($prop.Name) = $($prop.Value)"
            if ("$($prop.Value)" -match $suspiciousCmd) { Add-Finding 'Startup & persistence' 'High' "Suspicious startup entry: $($prop.Name)$state" "$detail`nThis launches a website, script or hidden command at login - typical adware/browser-hijacker behaviour." }
            elseif (-not $exists) {
                $how = if ($rk.Key -like '*RunOnce') { 'Windows removes this kind of entry by itself the next time you sign in.' } elseif ($disabled) { 'It is already switched off, so it does nothing.' } else { 'You can switch it off in Task Manager > Startup apps.' }
                Add-Finding 'Startup & persistence' 'Info' "Leftover startup entry: $($prop.Name)$state" "$detail`nThe program it points to no longer exists - probably left behind by something you uninstalled. Harmless. $how"
            }
            else { Add-Finding 'Startup & persistence' 'Info' "Startup entry: $($prop.Name)$state" $detail }
        }
    }
    $folderOff = @{}
    foreach ($ak in "HKCU:\$sa\StartupFolder", "HKLM:\$sa\StartupFolder") { foreach ($n in (Get-DisabledNames $ak).Keys) { $folderOff[$n] = $true } }
    $shell = New-Object -ComObject WScript.Shell
    foreach ($folder in @([Environment]::GetFolderPath('Startup'), [Environment]::GetFolderPath('CommonStartup'))) {
        Get-ChildItem -Path $folder -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
            $startupTotal++
            $disabled = $folderOff.ContainsKey($_.Name)
            $targetExe = $_.FullName
            $target = $_.FullName
            if ($_.Extension -eq '.lnk') { $s = $shell.CreateShortcut($_.FullName); $targetExe = $s.TargetPath; $target = "$($s.TargetPath) $($s.Arguments)" }
            $exists = (-not $targetExe) -or (Test-Path -LiteralPath $targetExe)
            if (-not $disabled -and $exists) { $startupOn++ }
            $state = if ($disabled) { ' (disabled in Task Manager)' } else { '' }
            if ($target -match $suspiciousCmd -or $_.Extension -match '\.(bat|cmd|vbs|js|ps1|hta)$') { Add-Finding 'Startup & persistence' 'High' "Suspicious item in Startup folder: $($_.Name)$state" "$($_.FullName)`n-> $target" }
            elseif (-not $exists) { Add-Finding 'Startup & persistence' 'Info' "Leftover item in Startup folder: $($_.Name)$state" "$($_.FullName)`n-> $target`nThe program it points to no longer exists. Harmless - you can delete this shortcut." }
            else { Add-Finding 'Startup & persistence' 'Info' "Startup folder item: $($_.Name)$state" "$($_.FullName)`n-> $target" }
        }
    }

    # ---- 2. Scheduled tasks
    Write-QpLog 'Checking scheduled tasks...' 'INFO'
    foreach ($t in @(Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        $actions = (@($t.Actions) | ForEach-Object { ("{0} {1}" -f $_.Execute, $_.Arguments).Trim() }) -join ' ; '
        $id = "$($t.TaskPath)$($t.TaskName)"
        if ($actions -match $suspiciousTask) {
            $detail = "Action: $actions`nState: $($t.State)"
            $taskFile = Join-Path $env:WINDIR ("System32\Tasks\" + $t.TaskPath.TrimStart('\') + $t.TaskName)
            if (Test-Path $taskFile) {
                $created = (Get-Item $taskFile -Force).CreationTime
                $detail += "`nTask created: $($created.ToString('yyyy-MM-dd HH:mm:ss'))"
                $near = Get-NearbyFolders $created
                if ($near.Count) { $detail += "`nFolders created within 3 minutes of this task (likely source):`n  " + ($near -join "`n  ") }
            } elseif (-not $isAdmin) { $detail += "`n(Run as administrator to see when it was created and what was installed at the same time.)" }
            Add-Finding 'Scheduled tasks' 'High' "Suspicious scheduled task: $id" $detail
        } elseif ($t.TaskPath -notlike '\Microsoft\*') {
            Add-Finding 'Scheduled tasks' 'Info' "Third-party task: $id" "Action: $actions`nState: $($t.State)"
        }
    }

    # ---- 3. Other persistence tricks
    Write-QpLog 'Checking other persistence locations...' 'INFO'
    foreach ($cls in 'CommandLineEventConsumer', 'ActiveScriptEventConsumer') {
        Get-CimInstance -Namespace root\subscription -ClassName $cls -ErrorAction SilentlyContinue | ForEach-Object {
            Add-Finding 'Startup & persistence' 'High' "WMI event consumer: $($_.Name)" ("{0}{1}" -f $_.CommandLineTemplate, $_.ScriptText)
        }
    }
    Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options' -ErrorAction SilentlyContinue | ForEach-Object {
        $dbg = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).Debugger
        if ($dbg) { Add-Finding 'Startup & persistence' 'Medium' "Program hijack (IFEO debugger) on $($_.PSChildName)" "Runs instead: $dbg" }
    }
    $wl = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue
    if ($wl.Shell -and $wl.Shell -notmatch '^\s*explorer\.exe\s*$') { Add-Finding 'Startup & persistence' 'High' 'Winlogon shell has been changed' "Shell = $($wl.Shell)" }
    if ($wl.Userinit -and $wl.Userinit -notmatch '^\s*C:\\Windows\\system32\\userinit\.exe,?\s*$') { Add-Finding 'Startup & persistence' 'High' 'Winlogon Userinit has been changed' "Userinit = $($wl.Userinit)" }
    $appinit = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' -ErrorAction SilentlyContinue
    if ($appinit.AppInit_DLLs -and $appinit.LoadAppInit_DLLs -eq 1) { Add-Finding 'Startup & persistence' 'High' 'AppInit_DLLs is loading extra DLLs into every program' $appinit.AppInit_DLLs }

    # ---- 4. Network hijacks
    Write-QpLog 'Checking hosts file, proxy and DNS...' 'INFO'
    $blockedHosts = New-Object System.Collections.ArrayList
    foreach ($line in @(Get-Content $script:HostsPath -ErrorAction SilentlyContinue)) {
        $l = $line.Trim()
        if (-not $l -or $l.StartsWith('#')) { continue }
        $parts = $l -split '\s+'
        if ($parts[0] -in '0.0.0.0', '127.0.0.1', '::1', '::') { [void]$blockedHosts.Add($parts[1]) }
        else { Add-Finding 'Network' 'High' "Hosts file redirects $($parts[1]) to $($parts[0])" "$l`nRedirecting real websites to other addresses is a classic phishing/hijack trick unless you set it up yourself." }
    }
    if ($blockedHosts.Count) { Add-Finding 'Network' 'Info' "Hosts file blocks $($blockedHosts.Count) domain(s)" ($blockedHosts -join "`n") }
    $inet = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    if ($inet.ProxyEnable -eq 1 -or $inet.AutoConfigURL) { Add-Finding 'Network' 'Medium' 'A proxy is configured' "ProxyServer = $($inet.ProxyServer)`nAutoConfigURL = $($inet.AutoConfigURL)`nIf you did not set this up (VPN, work, school), it may be intercepting your traffic." }
    $dns = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object ServerAddresses | ForEach-Object { "$($_.InterfaceAlias): $($_.ServerAddresses -join ', ')" })
    if ($dns) { Add-Finding 'Network' 'Info' 'DNS servers in use' ($dns -join "`n") }

    # ---- 5. Services running from unusual places
    Write-QpLog 'Checking services...' 'INFO'
    Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName } | ForEach-Object {
        # Only look at the executable itself, not its arguments (arguments often mention AppData legitimately).
        $exePath = if ($_.PathName -match '^\s*"([^"]+)"') { $matches[1] } elseif ($_.PathName -match '^\s*(\S+?\.exe)\b') { $matches[1] } else { $_.PathName }
        if ($exePath -match '(?i)\\AppData\\|\\Temp\\|\\Users\\Public\\') {
            Add-Finding 'Services' 'Medium' "Service runs from a user folder: $($_.DisplayName)" "$($_.Name)`n$($_.PathName)`nState: $($_.State), start: $($_.StartMode)"
        }
    }

    # ---- 6. Unsigned programs in user-writable folders
    Write-QpLog 'Checking programs in user folders for missing/invalid signatures (this can take a minute)...' 'INFO'
    $skip = '(?i)\\node_modules\\|\\npm-cache\\|\\\.vscode\\|\\Programs\\Python\\|\\go\\pkg\\|\\Android\\Sdk\\|\\\.gradle\\|\\\.m2\\|\\\.cargo\\|\\\.rustup\\|\\WindowsApps\\|\\Packages\\|\\Microsoft\\WindowsApps\\'
    $scanRoots = @($env:LOCALAPPDATA, $env:APPDATA, (Join-Path $env:USERPROFILE 'AppData\LocalLow'), (Join-Path $env:USERPROFILE 'Downloads'), $env:PUBLIC, $env:TEMP) | Where-Object { $_ -and (Test-Path $_) }
    $exe = foreach ($r in $scanRoots) { Get-ChildItem -Path $r -Recurse -Force -File -Include *.exe, *.scr -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $skip } }
    $exe = @($exe | Sort-Object LastWriteTime -Descending | Select-Object -First 1500)
    # Folders that hold a validly signed program: an unsigned file next to one is usually that app's own helper.
    $signedIn = @{}
    function Get-SignerName($Sig) { try { $Sig.SignerCertificate.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false) } catch { 'unknown publisher' } }
    $unsigned = foreach ($f in $exe) {
        $sig = Get-AuthenticodeSignature -FilePath $f.FullName -ErrorAction SilentlyContinue
        if (-not $sig) { continue }
        if ($sig.Status -eq 'Valid') {
            # Prefer naming the app's main program over its uninstaller.
            $cur = $signedIn[$f.DirectoryName]
            if (-not $cur -or ($cur -match '^(?i)unins' -and $f.Name -notmatch '^(?i)unins')) { $signedIn[$f.DirectoryName] = '{0} (signed by {1})' -f $f.Name, (Get-SignerName $sig) }
        }
        else { [pscustomobject]@{ File = $f.FullName; Dir = $f.DirectoryName; Status = [string]$sig.Status; Date = $f.LastWriteTime } }
    }
    function Get-SignedSibling([string]$Dir) {
        if ($signedIn.ContainsKey($Dir)) { return $signedIn[$Dir] }
        $found = $null
        foreach ($s in @(Get-ChildItem -LiteralPath $Dir -Filter *.exe -File -Force -ErrorAction SilentlyContinue | Sort-Object { $_.Name -match '^(?i)unins' } | Select-Object -First 20)) {
            $sg = Get-AuthenticodeSignature -FilePath $s.FullName -ErrorAction SilentlyContinue
            if ($sg -and $sg.Status -eq 'Valid') { $found = '{0} (signed by {1})' -f $s.Name, (Get-SignerName $sg); break }
        }
        $signedIn[$Dir] = $found
        return $found
    }
    foreach ($u in @($unsigned | Where-Object Status -eq 'HashMismatch')) { Add-Finding 'Files' 'High' "Modified signed program (signature broken): $(Split-Path $u.File -Leaf)" "$($u.File)`nThe file was signed by its publisher but has been altered since - typical of cracks or infected files." }
    $alone = New-Object System.Collections.ArrayList
    $helpers = New-Object System.Collections.ArrayList
    foreach ($u in @($unsigned | Where-Object Status -ne 'HashMismatch')) {
        $sib = Get-SignedSibling $u.Dir
        if ($sib) { [void]$helpers.Add([pscustomobject]@{ U = $u; Sibling = $sib }) } else { [void]$alone.Add($u) }
    }
    $plain = @($alone | Select-Object -First 40)
    if ($plain.Count) { Add-Finding 'Files' 'Medium' "$($plain.Count) unsigned program(s) in user folders (newest first)" ((($plain | ForEach-Object { '{0:yyyy-MM-dd}  {1}' -f $_.Date, $_.File }) -join "`n") + "`nUnsigned doesn't mean harmful, but make sure you recognise each one.") }
    $help = @($helpers | Select-Object -First 40)
    if ($help.Count) { Add-Finding 'Files' 'Info' "$($help.Count) unsigned helper file(s) belonging to signed programs" ((($help | ForEach-Object { "{0:yyyy-MM-dd}  {1}`n            next to {2}" -f $_.U.Date, $_.U.File, $_.Sibling }) -join "`n") + "`nMany apps ship small unsigned helpers (for example crash reporters) next to their signed main program. Lower risk.") }

    # ---- 7. Unofficial / cracked software indicators
    Write-QpLog 'Looking for signs of cracked/unofficial software...' 'INFO'
    # Only unambiguous names - generic words (codex, rune, plaza, reloaded...) collide with legitimate software.
    $crackNames = '(?i)^(nodvd|crack|cracked|codex-rune|empress|skidrow|fitgirl|fitgirl repacks|dodi|dodi repacks|anadius|goldberg|goldberg_emu|steam_emu|smartsteamemu|creamapi|cream_api|tenoke)$'
    $crackFiles = '(?i)^(steam_emu\.ini|cream_api\.ini|codex\.ini|rune\.ini|steam_api64\.cdx|smartsteamemu\.ini|onlinefix\.ini|cpy\.ini)$'
    $gameRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, 'C:\Games', (Join-Path $env:USERPROFILE 'Downloads'), ([Environment]::GetFolderPath('Desktop')), $env:LOCALAPPDATA, $env:APPDATA) | Where-Object { $_ -and (Test-Path $_) }
    $indicators = foreach ($r in $gameRoots) {
        Get-ChildItem -Path $r -Recurse -Depth 4 -Force -ErrorAction SilentlyContinue |
            Where-Object { ($_.PSIsContainer -and $_.Name -match $crackNames) -or (-not $_.PSIsContainer -and $_.Name -match $crackFiles) } |
            Select-Object -ExpandProperty FullName
    }
    foreach ($i in @($indicators | Select-Object -Unique -First 25)) {
        Add-Finding 'Files' 'Medium' 'Cracked/unofficial software indicator' "$i`nCracked games and software are one of the most common ways adware and password stealers get onto PCs."
    }

    # ---- 8. Browsers
    Write-QpLog 'Checking browser extensions and notification permissions...' 'INFO'
    $browsers = @{ 'Chrome' = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'; 'Edge' = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'; 'Brave' = Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data' }
    foreach ($b in $browsers.Keys) {
        $root = $browsers[$b]
        if (-not (Test-Path $root)) { continue }
        foreach ($prof in @(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' })) {
            # The browser's own records say which extensions it installed itself (built-in or default ones).
            $extInfo = @{}
            $pj = $null
            foreach ($pf in 'Secure Preferences', 'Preferences') {
                $pp = Join-Path $prof.FullName $pf
                if (-not (Test-Path $pp)) { continue }
                try {
                    $js = Get-Content $pp -Raw | ConvertFrom-Json
                    if ($pf -eq 'Preferences') { $pj = $js }
                    if ($js.extensions.settings) { foreach ($es in $js.extensions.settings.PSObject.Properties) { if (-not $extInfo.ContainsKey($es.Name)) { $extInfo[$es.Name] = $es.Value } } }
                } catch { }
            }
            foreach ($ext in @(Get-ChildItem (Join-Path $prof.FullName 'Extensions') -Directory -ErrorAction SilentlyContinue)) {
                $manifest = Get-ChildItem $ext.FullName -Recurse -Depth 1 -Filter manifest.json -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $manifest) { continue }
                try { $j = Get-Content $manifest.FullName -Raw | ConvertFrom-Json } catch { continue }
                $name = [string]$j.name
                if ($name -like '__MSG_*') {
                    $key = $name.Trim('_').Substring(4)
                    foreach ($loc in 'en', 'en_US', 'en_GB') {
                        $mf = Join-Path $manifest.DirectoryName "_locales\$loc\messages.json"
                        if (Test-Path $mf) { try { $msgs = Get-Content $mf -Raw | ConvertFrom-Json; $hit = $msgs.PSObject.Properties | Where-Object { $_.Name -ieq $key } | Select-Object -First 1; if ($hit) { $name = $hit.Value.message; break } } catch { } }
                    }
                }
                $perms = @($j.permissions) + @($j.host_permissions) | Where-Object { $_ -is [string] }
                $broad = @($perms | Where-Object { $_ -in '<all_urls>', '*://*/*', 'http://*/*', 'https://*/*' }).Count -gt 0
                # location 5 / 10 = part of the browser; was_installed_by_default = the browser installed it on its own
                $info = $extInfo[$ext.Name]
                $builtIn = $info -and ($info.was_installed_by_default -eq $true -or [int]$info.location -in 5, 10)
                $sev = if (-not $builtIn -and $broad -and ($perms -contains 'webRequest' -or $perms -contains 'scripting' -or $perms -contains 'tabs')) { 'Medium' } else { 'Info' }
                $note = if ($builtIn) { "`n$b installed this itself - it didn't come from you or another program." } elseif ($sev -eq 'Medium') { "`nCan read and change every website you visit - keep it only if you trust it." } else { '' }
                $title = if ($builtIn) { "$b extension: $name (installed by $b itself)" } else { "$b extension: $name" }
                Add-Finding 'Browsers' $sev $title ("Profile: {0}`nID: {1}`nPermissions: {2}{3}" -f $prof.Name, $ext.Name, ($perms -join ', '), $note)
            }
            if ($pj) {
                try {
                    $n = $pj.profile.content_settings.exceptions.notifications
                    if ($n) {
                        $allowed = @($n.PSObject.Properties | Where-Object { $_.Value.setting -eq 1 } | ForEach-Object { $_.Name })
                        if ($allowed.Count) { Add-Finding 'Browsers' 'Medium' "$b ($($prof.Name)): sites allowed to show notifications" (($allowed -join "`n") + "`nNotification spam from sites like these is a common adware trick. Remove any you do not recognise in the browser's site settings.") }
                    }
                } catch { }
            }
        }
    }

    # ---- 9. Security basics
    Write-QpLog 'Checking Microsoft Defender and firewall...' 'INFO'
    $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($mp) {
        if (-not $mp.RealTimeProtectionEnabled) { Add-Finding 'Security' 'High' 'Defender real-time protection is OFF' 'Turn it back on in Windows Security unless another antivirus is installed.' }
        $age = ((Get-Date) - $mp.AntivirusSignatureLastUpdated).Days
        if ($age -gt 7) { Add-Finding 'Security' 'Medium' "Defender virus definitions are $age days old" 'Run Windows Update or open Windows Security > Protection updates.' }
        $lastFull = if ($mp.FullScanEndTime) { $mp.FullScanEndTime.ToString('yyyy-MM-dd') } else { 'never' }
        Add-Finding 'Security' 'Info' 'Microsoft Defender status' ("Real-time protection: {0}`nDefinitions updated: {1:yyyy-MM-dd}`nLast full scan: {2}" -f $mp.RealTimeProtectionEnabled, $mp.AntivirusSignatureLastUpdated, $lastFull)
    }
    if ($isAdmin) {
        $pref = Get-MpPreference -ErrorAction SilentlyContinue
        foreach ($x in @($pref.ExclusionPath) | Where-Object { $_ }) {
            $sev = if ($x -match '(?i)\\AppData\\|\\Temp\\|\\Users\\Public\\|^[A-Z]:\\?$') { 'High' } else { 'Info' }
            Add-Finding 'Security' $sev "Defender exclusion: $x" 'Files here are not scanned. Malware sometimes adds exclusions for itself.'
        }
    }
    Get-NetFirewallProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Enabled } | ForEach-Object { Add-Finding 'Security' 'High' "Windows Firewall is off for the $($_.Name) profile" '' }

    # ---- 10. Telemetry status
    Write-QpLog 'Checking telemetry status...' 'INFO'
    $status = Get-QpPrivacyStatus
    $open = @((Get-QpCatalog privacy).Items | Where-Object { $status[$_.Id] -in 'NotApplied', 'Partial' -and $_.Recommended })
    if ($open.Count) { Add-Finding 'Privacy & telemetry' 'Medium' "$($open.Count) recommended privacy setting(s) are not fully applied yet" (($open | ForEach-Object { "- $($_.Title)" + $(if ($status[$_.Id] -eq 'Partial') { ' (partly done)' } else { '' }) }) -join "`n") }
    else { Add-Finding 'Privacy & telemetry' 'Info' 'All recommended privacy settings are applied' '' }
    # ---- 10b. Brand and hardware software (whatever came with this PC)
    Write-QpLog 'Looking for brand software that came with this PC...' 'INFO'
    foreach ($v in (Get-QpVendorStatus)) {
        $open = @($v.Items | Where-Object { $_.Status -ne 'Applied' })
        if ($open.Count) {
            $detail = (($open | ForEach-Object { "- $($_.Title)" }) -join "`n") + "`n`n" + $v.Note + "`nSwitch these off in the Telemetry tab, or use the one-click button on the Home screen."
            Add-Finding 'Brand & hardware software' 'Medium' "$($v.Name): $($open.Count) background item(s) still switched on" $detail
        } else {
            Add-Finding 'Brand & hardware software' 'Info' "$($v.Name): background tracking is already switched off" $v.Note
        }
        if ($v.Junk.Count) {
            $detail = (($v.Junk | ForEach-Object { "- $($_.Name): $($_.Why)" }) -join "`n") + "`nThese are ordinary programs. Quietpane only removes one if you ask it to, and removing cannot be undone."
            Add-Finding 'Brand & hardware software' 'Info' "$($v.Name): $($v.Junk.Count) extra program(s) you could remove" $detail
        }
    }

    # ---- 11. Performance snapshot
    Write-QpLog 'Taking a performance snapshot...' 'INFO'
    $os = Get-CimInstance Win32_OperatingSystem
    $usedGB = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB
    $top = Get-Process | Group-Object ProcessName | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Count = $_.Count; MB = [math]::Round((($_.Group | Measure-Object WorkingSet64 -Sum).Sum) / 1MB) } } | Sort-Object MB -Descending | Select-Object -First 12
    Add-Finding 'Performance' 'Info' ("RAM in use: {0:N1} of {1:N1} GB, {2} processes, {3} program(s) start at sign-in" -f $usedGB, ($os.TotalVisibleMemorySize / 1MB), @(Get-Process).Count, $startupOn) ((($top | ForEach-Object { '{0,6} MB  {1} (x{2})' -f $_.MB, $_.Name, $_.Count }) -join "`n") + ("`n{0} startup entries in total; the rest are switched off in Task Manager or point to programs that no longer exist." -f $startupTotal))

    # ---- 12. Disk space
    Write-QpLog 'Measuring reclaimable space...' 'INFO'
    $targets = @(Get-QpCleanupTargets | Where-Object SizeBytes -gt 0)
    if ($targets.Count) { Add-Finding 'Disk space' 'Info' ("Reclaimable with the Clean-up tab: about {0}" -f (Format-QpBytes (($targets | Measure-Object SizeBytes -Sum).Sum))) (($targets | ForEach-Object { '{0,10}  {1}' -f (Format-QpBytes $_.SizeBytes), $_.Title }) -join "`n") }
    if (Test-Path 'C:\Windows.old') { Add-Finding 'Disk space' 'Info' 'C:\Windows.old exists (previous Windows version)' 'Remove it with Settings > System > Storage > Temporary files > "Previous Windows installation(s)".' }

    # ---- 13. Possibly leftover folders
    Write-QpLog 'Looking for folders left behind by uninstalled programs...' 'INFO'
    $cutoff = (Get-Date).AddDays(-180)
    $old = foreach ($r in @($env:LOCALAPPDATA, $env:APPDATA, (Join-Path $env:USERPROFILE 'AppData\LocalLow'), $env:ProgramData)) {
        Get-ChildItem -Path $r -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff -and $_.CreationTime -lt $cutoff -and $_.Name -notmatch '^(Microsoft|Packages|Temp|Comms|ConnectedDevicesPlatform|Programs|Application Data|History|Temporary Internet Files|Package Cache|USOPrivate|USOShared|ssh|regid\..*|Desktop|Documents|Start Menu|Templates|Favorites|VirtualStore|Publishers|PlaceholderTileLogoFolder)$' } |
            ForEach-Object {
                $dir = $_
                # A folder's own date doesn't change when files inside it change, so look inside too.
                # Stop at the first recent item - a folder with anything changed in the last 6 months is still in use.
                $recent = Get-ChildItem -LiteralPath $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -ge $cutoff -or $_.CreationTime -ge $cutoff } | Select-Object -First 1
                if (-not $recent) {
                    $newest = Get-ChildItem -LiteralPath $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    $last = if ($newest -and $newest.LastWriteTime -gt $dir.LastWriteTime) { $newest.LastWriteTime } else { $dir.LastWriteTime }
                    [pscustomobject]@{ Path = $dir.FullName; Last = $last; Size = (Get-QpSize @($dir.FullName)) }
                }
            }
    }
    $old = @($old | Sort-Object Size -Descending | Select-Object -First 30)
    if ($old.Count) { Add-Finding 'Disk space' 'Info' 'Folders where nothing has changed for 6+ months (review before deleting - may belong to uninstalled programs)' ((($old | ForEach-Object { '{0,10}  {1:yyyy-MM-dd}  {2}' -f (Format-QpBytes $_.Size), $_.Last, $_.Path }) -join "`n") + "`nThe date is the last time anything inside the folder changed. Check what a folder belongs to before deleting it - some apps you still use rarely write to their folders.") }

    # ---- Report
    $counts = [ordered]@{}
    foreach ($s in 'Critical', 'High', 'Medium', 'Low', 'Info') { $counts[$s] = @($findings | Where-Object { $_.Severity -eq $s }).Count }
    $high = $counts['High']; $med = $counts['Medium']
    $html = New-QpReportHtml -Findings $findings -Counts $counts -IsAdmin $isAdmin
    try {
        $dir = Split-Path -Path $OutFile -Parent
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Set-Content -Path $OutFile -Value $html -Encoding UTF8 -ErrorAction Stop
    } catch {
        $OutFile = Join-Path $env:TEMP ("Quietpane-Report-{0}.html" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
        Set-Content -Path $OutFile -Value $html -Encoding UTF8
        Write-QpLog "Could not save the report to the chosen location - saved to $OutFile instead" 'WARN'
    }
    Write-QpLog ("Check finished: {0} critical, {1} high, {2} medium, {3} low, {4} for information. Report: {5}" -f $counts['Critical'], $counts['High'], $counts['Medium'], $counts['Low'], $counts['Info'], $OutFile) 'OK'
    [pscustomobject]@{
        Critical = $counts['Critical']; High = $high; Medium = $med; Low = $counts['Low']; Info = $counts['Info']
        Counts = $counts; Total = @($findings).Count
        Findings = @($findings)
        Defender = $defender
        Report = $OutFile
    }
}

function New-QpDonutSvg {
    <#
        The severity doughnut, drawn as plain inline SVG: no scripts, no fonts, no network.
        Every segment is also written out in the legend, so the picture never carries meaning on its own.
    #>
    param([hashtable]$Counts, [hashtable]$Colours)
    $order = @('Critical', 'High', 'Medium', 'Low', 'Info')
    $total = 0; foreach ($s in $order) { $total += [int]$Counts[$s] }
    $cx = 90; $cy = 90; $r = 68; $w = 26
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('<svg viewBox="0 0 180 180" width="180" height="180" role="img" aria-label="Findings by severity">')
    [void]$sb.Append(('<circle cx="{0}" cy="{1}" r="{2}" fill="none" stroke="{3}" stroke-width="{4}"/>' -f $cx, $cy, $r, '#e6dfcc', $w))
    if ($total -gt 0) {
        $angle = -90.0
        foreach ($s in $order) {
            $n = [int]$Counts[$s]
            if ($n -le 0) { continue }
            $sweep = 360.0 * $n / $total
            # a full circle cannot be drawn as one arc, so draw it as a ring
            if ([Math]::Abs($sweep - 360) -lt 0.01) {
                [void]$sb.Append(('<circle cx="{0}" cy="{1}" r="{2}" fill="none" stroke="{3}" stroke-width="{4}"/>' -f $cx, $cy, $r, $Colours[$s], $w))
                break
            }
            $a1 = $angle * [Math]::PI / 180.0
            $a2 = ($angle + $sweep) * [Math]::PI / 180.0
            $x1 = $cx + $r * [Math]::Cos($a1); $y1 = $cy + $r * [Math]::Sin($a1)
            $x2 = $cx + $r * [Math]::Cos($a2); $y2 = $cy + $r * [Math]::Sin($a2)
            $large = if ($sweep -gt 180) { 1 } else { 0 }
            [void]$sb.Append(('<path d="M {0:F2} {1:F2} A {2} {2} 0 {3} 1 {4:F2} {5:F2}" fill="none" stroke="{6}" stroke-width="{7}"><title>{8}: {9}</title></path>' -f $x1, $y1, $r, $large, $x2, $y2, $Colours[$s], $w, $s, $n))
            $angle += $sweep
        }
    }
    [void]$sb.Append(('<text x="{0}" y="{1}" text-anchor="middle" font-size="34" font-weight="700" fill="currentColor">{2}</text>' -f $cx, ($cy + 4), $total))
    [void]$sb.Append(('<text x="{0}" y="{1}" text-anchor="middle" font-size="12" fill="currentColor" opacity="0.75">{2}</text>' -f $cx, ($cy + 24), $(if ($total -eq 1) { 'finding' } else { 'findings' })))
    [void]$sb.Append('</svg>')
    return $sb.ToString()
}

function New-QpReportHtml {
    param($Findings, [System.Collections.IDictionary]$Counts, [bool]$IsAdmin)
    $enc = { param($s) [System.Net.WebUtility]::HtmlEncode([string]$s) }
    # The logo is embedded as a data URI so the report makes no network requests at all
    # (no web fonts, no CDNs, no images from the internet).
    $logoPath = Join-Path $script:AssetsRoot 'komodoworks-logo.png'
    $logo = if (Test-Path $logoPath) { 'data:image/png;base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($logoPath)) } else { '' }
    $brandUrl = $script:Brand.Url
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append(@"
<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="no-referrer">
<title>Quietpane report</title>
<style>
:root{--bg:#faf6ec;--card:#fffdf8;--text:#0f1b1c;--muted:#4b5b5c;--line:#e6dfcc;--anchor:#0f1b1c;--accent:#ffb627;--teal:#117a68;--crit:#7b1d1d;--high:#a83232;--med:#9a6700;--low:#4b5b5c;--info:#117a68}
@media (prefers-color-scheme:dark){:root{--bg:#0f1b1c;--card:#162627;--text:#faf6ec;--muted:#a9b5b3;--line:#22393a;--teal:#1fa187;--crit:#ff7b7b;--high:#e06666;--med:#ffb627;--low:#a9b5b3;--info:#1fa187}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:15px/1.55 "Sora","Segoe UI",system-ui,sans-serif}
header.brand{background:var(--anchor);color:#faf6ec;padding:18px 16px}
.wrap{max-width:980px;margin:0 auto}.row{display:flex;align-items:center;gap:14px;flex-wrap:wrap}
.row img{width:48px;height:48px;display:block}
h1{font:600 26px/1.2 "Fraunces",Georgia,"Times New Roman",serif;margin:0}
.by{margin:2px 0 0;font-size:13px;color:#d9d3c4}.by a{color:var(--accent);text-decoration:none;font-weight:600}.by a:hover{text-decoration:underline}
main{padding:24px 16px}p.meta{color:var(--muted);margin:0 0 20px}
.sum{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:24px}.pill{background:var(--card);border:1px solid var(--line);padding:10px 16px;min-width:110px}
.pill b{font:600 24px/1.2 "Fraunces",Georgia,serif;display:block}
h2{font:600 19px/1.3 "Fraunces",Georgia,serif;margin:28px 0 8px;color:var(--teal)}
.f{background:var(--card);border:1px solid var(--line);border-left:4px solid var(--info);padding:10px 14px;margin:8px 0}
.f.Critical{border-left-color:var(--crit)}.f.High{border-left-color:var(--high)}.f.Medium{border-left-color:var(--med)}.f.Low{border-left-color:var(--low)}
.sev{font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;margin-right:8px}
.Critical .sev{color:var(--crit)}.High .sev{color:var(--high)}.Medium .sev{color:var(--med)}.Low .sev{color:var(--low)}.Info .sev{color:var(--info)}
.chart{display:flex;gap:24px;align-items:center;flex-wrap:wrap;background:var(--card);border:1px solid var(--line);padding:16px;margin-bottom:24px}
.legend{list-style:none;margin:0;padding:0;min-width:230px}
.legend li{display:flex;align-items:center;gap:10px;padding:3px 0;font-size:14px}
.legend .k{width:14px;height:14px;flex:0 0 14px;display:inline-block;border:1px solid rgba(0,0,0,.15)}
.legend .n{margin-left:auto;font-weight:700}.legend li.zero{opacity:.45}
.meta2{color:var(--muted);font-size:13px;margin:4px 0 0}.meta2 b{color:var(--text)}
pre{white-space:pre-wrap;word-break:break-all;margin:6px 0 0;color:var(--muted);font:13px/1.45 Consolas,monospace}
footer{border-top:1px solid var(--line);margin-top:32px;padding:16px 0;color:var(--muted);font-size:13px}footer a{color:var(--teal)}
</style></head><body>
<header class="brand"><div class="wrap row">
"@)
    if ($logo) { [void]$sb.Append(('<img src="{0}" alt="KomodoWorks emblem">' -f $logo)) }
    [void]$sb.Append(('<div><h1>Quietpane &ndash; scan report</h1><p class="by">Developed by <a href="{0}" rel="noopener noreferrer">KomodoWorks.com</a></p></div></div></header><main><div class="wrap">' -f $brandUrl))
    $adminNote = if (-not $IsAdmin) { ' &middot; run as administrator for the full scan' } else { '' }
    [void]$sb.Append(('<p class="meta">{0} &middot; version {1} &middot; read-only scan, nothing was changed{2}</p>' -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $script:AppVersion, $adminNote))
    # Severity doughnut plus a written legend: the chart never carries meaning through colour alone.
    $colours = @{ Critical = '#7b1d1d'; High = '#a83232'; Medium = '#9a6700'; Low = '#8a8578'; Info = '#117a68' }
    $meaning = @{ Critical = 'act now'; High = 'act on it'; Medium = 'worth a look'; Low = 'minor'; Info = 'just so you know' }
    $plain = @{}
    foreach ($s in 'Critical', 'High', 'Medium', 'Low', 'Info') { $plain[$s] = [int]$Counts[$s] }
    [void]$sb.Append('<div class="chart">' + (New-QpDonutSvg -Counts $plain -Colours $colours) + '<ul class="legend">')
    foreach ($s in 'Critical', 'High', 'Medium', 'Low', 'Info') {
        $cls = if ($plain[$s] -eq 0) { ' class="zero"' } else { '' }
        [void]$sb.Append(('<li{0}><span class="k" style="background:{1}"></span>{2} <span style="color:var(--muted)">- {3}</span><span class="n">{4}</span></li>' -f $cls, $colours[$s], $s, $meaning[$s], $plain[$s]))
    }
    [void]$sb.Append('</ul></div>')
    $order = @{ Critical = 0; High = 1; Medium = 2; Low = 3; Info = 4 }
    foreach ($g in ($Findings | Group-Object Section | Sort-Object { ($_.Group | ForEach-Object { $order[$_.Severity] } | Measure-Object -Minimum).Minimum })) {
        [void]$sb.Append("<h2>$(& $enc $g.Name)</h2>")
        foreach ($f in ($g.Group | Sort-Object { $order[$_.Severity] })) {
            $line = '<div class="f {0}"><span class="sev">{0}</span>{1}' -f $f.Severity, (& $enc $f.Title)
            # Findings that came from Defender carry extra facts worth printing.
            if ($f.Source -and $f.Source -ne 'Quietpane check') {
                $bits = @("found by <b>$(& $enc $f.Source)</b>", "confidence: <b>$(& $enc $f.Confidence)</b>", "status: <b>$(& $enc $f.Status)</b>")
                if ($f.Category) { $bits += 'type: <b>' + (& $enc $f.Category) + '</b>' }
                $line += '<p class="meta2">' + ($bits -join ' &middot; ') + '</p>'
                if ($f.What) { $line += '<p class="meta2">' + (& $enc $f.What) + '</p>' }
                if ($f.Why) { $line += '<p class="meta2">' + (& $enc $f.Why) + '</p>' }
                if ($f.Recommended) { $line += '<p class="meta2">What to do: <b>' + (& $enc $f.Recommended) + '</b></p>' }
                if ($f.Path) { $line += '<p class="meta2">Where: ' + (& $enc $f.Path) + '</p>' }
                if ($f.Sha256) { $line += '<p class="meta2">SHA256: ' + (& $enc $f.Sha256) + '</p>' }
            }
            if ($f.Detail) { $line += '<pre>' + (& $enc $f.Detail) + '</pre>' }
            [void]$sb.Append($line + '</div>')
        }
    }
    [void]$sb.Append(('<footer>Critical = act now &middot; High = act on it &middot; Medium = worth a look &middot; Low = minor &middot; Info = just so you know.<br>Threat names come from Microsoft Defender. Quietpane''s own checks are marked as such and are signals, not proof.<br>This report was created on this PC and was not sent anywhere. It describes your PC, so review it before sharing it with anyone.<br><b>A good start, not a guarantee.</b> This check looks at the places problems usually hide, but it cannot promise a PC is clean. If yours still feels wrong, run a deeper scan with a dedicated security tool as well.<br>Quietpane {0} &middot; free and open source (MIT) &middot; Developed by <a href="{1}" rel="noopener noreferrer">KomodoWorks.com</a> &middot; <a href="mailto:{2}">{2}</a></footer></div></main></body></html>' -f $script:AppVersion, $brandUrl, $script:Brand.Email))
    return $sb.ToString()
}

#endregion

Export-ModuleMember -Function Get-QpInfo, Set-QpLogSink, Write-QpLog, Test-QpAdmin, Get-QpCatalog, Format-QpBytes,
    Get-QpSystemUsage, Get-QpTotals,
    Get-QpRestorePoints, Invoke-QpUndo,
    Get-QpPrivacyStatus, Invoke-QpPrivacy,
    Get-QpBloatApps, Invoke-QpRemoveApps,
    Get-QpCleanupTargets, Invoke-QpCleanup,
    Get-QpVendorStatus, Invoke-QpVendor, Invoke-QpVendorUninstall,
    Get-QpDefenderState, Get-QpDefenderFindings, Invoke-QpThreatScan, Invoke-QpRemediate, Get-QpAllowList, Resolve-QpThreatInfo, New-QpFinding,
    New-QpDonutSvg, New-QpReportHtml, Get-QpFileHash,
    Invoke-QpQuarantine, Get-QpQuarantineItems, Restore-QpQuarantineItem, Remove-QpQuarantineItem, Test-QpProtectedPath, Test-QpFindingStillTrue,
    Get-QpRecommendedPlan, Invoke-QpRecommended,
    Invoke-QpAudit
