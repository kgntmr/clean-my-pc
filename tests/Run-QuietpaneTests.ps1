#Requires -Version 5.1
<#
    Quietpane's safety checks, checked.

        powershell -ExecutionPolicy Bypass -File tests\Run-QuietpaneTests.ps1
        powershell -ExecutionPolicy Bypass -File tests\Run-QuietpaneTests.ps1 -Live   (adds the EICAR test)

    The quarantine tests need administrator rights, and -ExecutionPolicy Bypass does not grant them:
    without an elevated window those six are skipped. The reliable way to get one is to paste this into
    an ordinary PowerShell window, from the repository folder, and answer Yes to the prompt Windows shows:

        Start-Process powershell -Verb RunAs -ArgumentList '-NoExit','-ExecutionPolicy','Bypass',
            '-File',"$PWD\tests\Run-QuietpaneTests.ps1",'-Live'

    (all on one line). An elevated window says "Administrator:" in its title bar and starts in
    C:\WINDOWS\system32; an ordinary one starts in your own user folder. Elevated: 112 checks run.

    No real malware is ever used. The only live test writes the EICAR string - the harmless standard file
    the antivirus industry publishes so people can check their protection works - into a temporary folder,
    and it is built at runtime so the string is never stored in this repository.

    Nothing here changes a setting. The one test that asks Defender to act needs -Live and administrator
    rights, and it acts only on the EICAR file it created itself.
#>
param([switch]$Live)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'src\Quietpane.psm1') -Force

$script:Pass = 0; $script:Fail = 0; $script:Skip = 0
function Test-Case([string]$Name, [scriptblock]$Body) {
    try {
        $r = & $Body
        # note: ($true -eq 'skip') is true in PowerShell, so the type has to be checked as well
        if ($r -is [string] -and $r -eq 'skip') { $script:Skip++; Write-Host ("  SKIP  {0}" -f $Name) -ForegroundColor DarkGray; return }
        if ($r) { $script:Pass++; Write-Host ("  ok    {0}" -f $Name) -ForegroundColor Green }
        else { $script:Fail++; Write-Host ("  FAIL  {0}" -f $Name) -ForegroundColor Red }
    } catch {
        $script:Fail++; Write-Host ("  FAIL  {0} - {1}" -f $Name, $_.Exception.Message) -ForegroundColor Red
    }
}
function Section([string]$Name) { Write-Host "`n$Name" -ForegroundColor Cyan }

$colours = @{ Critical = '#7b1d1d'; High = '#a83232'; Medium = '#9a6700'; Low = '#8a8578'; Info = '#117a68' }

Section 'Threat names to plain language'
Test-Case 'ransomware becomes Critical' { (Resolve-QpThreatInfo -ThreatName 'Ransom:Win32/WannaCrypt.A!ml').Tier -eq 'Critical' }
Test-Case 'the family name is recognised' { (Resolve-QpThreatInfo -ThreatName 'Ransom:Win32/LockBit').Family -eq 'LockBit' }
Test-Case 'a stealer becomes High' { (Resolve-QpThreatInfo -ThreatName 'PWS:Win32/RedLineStealer').Tier -eq 'High' }
Test-Case 'unwanted software becomes Low' { (Resolve-QpThreatInfo -ThreatName 'PUA:Win32/CandyOpen').Tier -eq 'Low' }
Test-Case 'the EICAR test file is only Info' { (Resolve-QpThreatInfo -ThreatName 'Virus:DOS/EICAR_Test_File').Tier -eq 'Info' }
Test-Case 'an unknown name still lands somewhere sensible' {
    $i = Resolve-QpThreatInfo -ThreatName 'Trojan:Win32/NeverSeenBefore' -VendorSeverity 4
    $i.Tier -eq 'High' -and $i.MatchedBy -eq 'category'
}
Test-Case 'a name with no category at all falls back to Defender severity' {
    (Resolve-QpThreatInfo -ThreatName 'CompletelyUnknownShape' -VendorSeverity 5).Tier -eq 'Critical'
}
Test-Case 'an unknown family is never given a family name' {
    (Resolve-QpThreatInfo -ThreatName 'Trojan:Win32/NeverSeenBefore' -VendorSeverity 4).Family -eq ''
}

Section 'The shape every finding has'
Test-Case 'a finding carries the facts the card needs' {
    $f = New-QpFinding -Severity High -ThreatName 'Trojan:Win32/Example' -Source 'Microsoft Defender' -Path 'C:\x\y.exe' -Confidence Confirmed
    $f.Id -and $f.Severity -eq 'High' -and $f.Source -eq 'Microsoft Defender' -and $f.Status -eq 'Detected' -and $f.FirstSeen
}
Test-Case 'the same thing always gets the same id' {
    $a = New-QpFinding -ThreatName 'T' -Source 'Microsoft Defender' -Path 'C:\a.exe'
    $b = New-QpFinding -ThreatName 'T' -Source 'Microsoft Defender' -Path 'C:\a.exe'
    $a.Id -eq $b.Id
}
Test-Case 'different things get different ids' {
    (New-QpFinding -ThreatName 'T' -Path 'C:\a.exe').Id -ne (New-QpFinding -ThreatName 'T' -Path 'C:\b.exe').Id
}
Test-Case 'severity outside the five tiers is refused' {
    try { New-QpFinding -Severity 'Catastrophic' | Out-Null; $false } catch { $true }
}

Section 'Hashing'
Test-Case 'a readable file is hashed' {
    $p = Join-Path $env:TEMP ('qp-hash-' + [guid]::NewGuid().ToString('N') + '.txt')
    'hello' | Set-Content -LiteralPath $p
    $h = Get-QpFileHash $p
    Remove-Item $p -Force
    $h.Length -eq 64
}
Test-Case 'a missing file returns nothing instead of throwing' { (Get-QpFileHash 'C:\nope\missing.exe') -eq '' }
Test-Case 'a locked file does not break the scan' {
    $p = Join-Path $env:TEMP ('qp-lock-' + [guid]::NewGuid().ToString('N') + '.bin')
    'x' | Set-Content -LiteralPath $p
    $fs = [IO.File]::Open($p, 'Open', 'Read', 'None')   # deny everyone, including us
    try { $h = Get-QpFileHash $p; $ok = ($h -eq '' -or $h.Length -eq 64) } finally { $fs.Close(); Remove-Item $p -Force }
    $ok
}

Section 'The doughnut'
Test-Case 'counts add up to the number in the middle' {
    $svg = New-QpDonutSvg -Counts @{ Critical = 1; High = 2; Medium = 2; Low = 1; Info = 2 } -Colours $colours
    [int]([regex]::Match($svg, '>(\d+)<').Groups[1].Value) -eq 8
}
Test-Case 'one slice per severity that has findings' {
    $svg = New-QpDonutSvg -Counts @{ Critical = 1; High = 2; Medium = 2; Low = 1; Info = 2 } -Colours $colours
    [regex]::Matches($svg, '<path').Count -eq 5
}
Test-Case 'empty severities draw no slice' {
    $svg = New-QpDonutSvg -Counts @{ Critical = 0; High = 3; Medium = 0; Low = 0; Info = 0 } -Colours $colours
    [regex]::Matches($svg, '<path').Count -eq 0 -and [regex]::Matches($svg, '<circle').Count -eq 2
}
Test-Case 'no findings at all still renders' {
    $svg = New-QpDonutSvg -Counts @{ Critical = 0; High = 0; Medium = 0; Low = 0; Info = 0 } -Colours $colours
    $svg -match '>0<' -and [regex]::Matches($svg, '<path').Count -eq 0
}
Test-Case 'the chart describes itself for screen readers' {
    (New-QpDonutSvg -Counts @{ Critical = 1; High = 0; Medium = 0; Low = 0; Info = 0 } -Colours $colours) -match 'role="img"'
}

Section 'The report'
$mock = @(
    (New-QpFinding -Section Threats -Severity Critical -ThreatName 'Ransom:Win32/LockBit' -Family 'LockBit' -Category 'Ransomware' -Source 'Microsoft Defender' -Path 'C:\Users\T\Downloads\a.exe' -Confidence Confirmed -Status Detected -What 'w' -Why 'y' -Recommended 'r' -Title 'LockBit'),
    (New-QpFinding -Section Threats -Severity Low -ThreatName 'PUA:Win32/CandyOpen' -Family 'CandyOpen' -Source 'Microsoft Defender' -Path 'C:\b.exe' -Confidence Confirmed -Title 'CandyOpen'),
    (New-QpFinding -Section Files -Severity Medium -Title 'unsigned thing' -Detail 'detail' -Source 'Quietpane check' -Confidence Heuristic)
)
$counts = [ordered]@{ Critical = 1; High = 0; Medium = 1; Low = 1; Info = 0 }
Test-Case 'the report is built and contains the chart' {
    $html = New-QpReportHtml -Findings $mock -Counts $counts -IsAdmin $true
    $html -match '<svg' -and $html -match 'LockBit'
}
Test-Case 'the report runs no scripts and fetches nothing' {
    $html = New-QpReportHtml -Findings $mock -Counts $counts -IsAdmin $true
    [regex]::Matches($html, '<script').Count -eq 0 -and [regex]::Matches($html, 'src="http').Count -eq 0
}
Test-Case 'every severity appears in the legend, even the empty ones' {
    $html = New-QpReportHtml -Findings $mock -Counts $counts -IsAdmin $true
    [regex]::Matches($html, '<li').Count -eq 5
}
Test-Case 'Defender findings show their source and confidence' {
    $html = New-QpReportHtml -Findings $mock -Counts $counts -IsAdmin $true
    $html -match 'Microsoft Defender' -and $html -match 'Confirmed'
}
Test-Case 'a report with nothing in it still renders' {
    $html = New-QpReportHtml -Findings @() -Counts ([ordered]@{ Critical = 0; High = 0; Medium = 0; Low = 0; Info = 0 }) -IsAdmin $true
    $html -match '<svg' -and $html.Length -gt 500
}

Section 'Filtering, the way the window does it'
Test-Case 'filtering by severity returns only that severity' {
    @($mock | Where-Object { $_.Severity -eq 'Critical' }).Count -eq 1
}
Test-Case 'filtering an empty severity returns nothing, not everything' {
    @($mock | Where-Object { $_.Severity -eq 'High' }).Count -eq 0
}
Test-Case 'the same threat found twice is counted once' {
    $dupes = @(
        (New-QpFinding -ThreatName 'Trojan:Win32/X' -Source 'Microsoft Defender' -Path 'C:\same.exe'),
        (New-QpFinding -ThreatName 'Trojan:Win32/X' -Source 'Microsoft Defender' -Path 'C:\same.exe')
    )
    @($dupes | Group-Object Id).Count -eq 1
}

Section 'Talking to Defender'
Test-Case 'Defender state can always be read, even when Defender is missing' {
    $s = Get-QpDefenderState
    $null -ne $s -and $s.PSObject.Properties['Available'] -and $s.PSObject.Properties['Note']
}
Test-Case 'when Defender is unavailable the scan says so instead of pretending' {
    $s = Get-QpDefenderState
    if ($s.Available) { 'skip' } else { $s.Note -match 'Defender' }
}
Test-Case 'reading detections never throws' { $null -ne @(Get-QpDefenderFindings) }
Test-Case 'a Quietpane heuristic can never be sent to Defender for removal' {
    $h = New-QpFinding -Source 'Quietpane check' -ThreatName '' -Title 'heuristic thing' -Confidence Heuristic
    (Invoke-QpRemediate -Finding $h -Action Defender).Ok -eq $false
}

Section 'Leaving something alone'
Test-Case 'allowing an item never creates a Defender exclusion' {
    $before = @((Get-MpPreference -ErrorAction SilentlyContinue).ExclusionPath).Count
    $f = New-QpFinding -ThreatName 'Test:Win32/AllowMe' -Source 'Microsoft Defender' -Path 'C:\allow-test.exe'
    Invoke-QpRemediate -Finding $f -Action Allow | Out-Null
    $after = @((Get-MpPreference -ErrorAction SilentlyContinue).ExclusionPath).Count
    $listed = @(Get-QpAllowList | Where-Object { $_.ThreatName -eq 'Test:Win32/AllowMe' }).Count -eq 1
    $before -eq $after -and $listed
}
Test-Case 'every action is written to the audit log' {
    $log = Join-Path $env:ProgramData 'Quietpane\audit.log'
    (Test-Path $log) -and ((Get-Content $log -Tail 5) -join "`n") -match 'Allow'
}

Section 'Quarantine, restore and delete'
function New-TestFile([string]$Content = 'harmless test content') {
    $p = Join-Path $env:TEMP ('qp-quar-' + [guid]::NewGuid().ToString('N') + '.txt')
    [IO.File]::WriteAllText($p, $Content)
    return $p
}
function New-TestFinding([string]$Path) {
    New-QpFinding -Severity Medium -ThreatName 'Test:Win32/Harmless' -Source 'Quietpane check' -Confidence Heuristic `
        -Object (Split-Path $Path -Leaf) -Path $Path -Sha256 (Get-QpFileHash $Path) -Title 'test item'
}
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Test-Case 'protected Windows folders are refused' {
    (Test-QpProtectedPath (Join-Path $env:WINDIR 'System32\kernel32.dll')) -and
    (Test-QpProtectedPath (Join-Path $env:ProgramFiles 'anything.exe')) -and
    -not (Test-QpProtectedPath (Join-Path $env:TEMP 'something.exe'))
}
Test-Case 'a folder is never treated as a file to remove' { Test-QpProtectedPath $env:TEMP }
Test-Case 'a drive root is refused' { Test-QpProtectedPath 'C:\' }
Test-Case 'a finding whose file has changed is refused' {
    $p = New-TestFile
    $f = New-TestFinding $p
    [IO.File]::WriteAllText($p, 'something else entirely')
    $r = Test-QpFindingStillTrue $f
    Remove-Item $p -Force
    -not $r.Ok -and $r.Why -match 'changed'
}
Test-Case 'a finding whose file is gone is refused' {
    $p = New-TestFile
    $f = New-TestFinding $p
    Remove-Item $p -Force
    -not (Test-QpFindingStillTrue $f).Ok
}
Test-Case 'quarantine round trip puts back a byte-identical file' {
    if (-not $admin) { return 'skip' }
    $p = New-TestFile 'round trip content'
    $before = Get-QpFileHash $p
    $f = New-TestFinding $p
    $q = Invoke-QpRemediate -Finding $f -Action Quarantine
    $gone = -not (Test-Path -LiteralPath $p)
    $item = @(Get-QpQuarantineItems | Where-Object { $_.OriginalPath -eq $p }) | Select-Object -First 1
    $stored = $item -and (Test-Path (Join-Path $item.Folder 'payload.bin')) -and -not (Test-Path (Join-Path $item.Folder $item.FileName))
    $r = Restore-QpQuarantineItem -Id $item.Id
    $after = Get-QpFileHash $p
    Remove-Item $p -Force -ErrorAction SilentlyContinue
    $q.Ok -and $gone -and $stored -and $r.Ok -and $before -eq $after
}
Test-Case 'quarantined files are stored where they cannot run' {
    if (-not $admin) { return 'skip' }
    $p = New-TestFile
    $f = New-TestFinding $p
    Invoke-QpRemediate -Finding $f -Action Quarantine | Out-Null
    $item = @(Get-QpQuarantineItems | Where-Object { $_.OriginalPath -eq $p }) | Select-Object -First 1
    $ok = $item -and $item.FileName -like '*.txt' -and (Get-ChildItem $item.Folder | Where-Object { $_.Name -eq 'payload.bin' })
    Remove-QpQuarantineItem -Id $item.Id -Force | Out-Null
    $ok
}
Test-Case 'permanent deletion refuses without an explicit confirmation' {
    if (-not $admin) { return 'skip' }
    $p = New-TestFile
    $f = New-TestFinding $p
    $r = Invoke-QpRemediate -Finding $f -Action Delete      # no -Force
    $stillThere = Test-Path -LiteralPath $p
    Remove-Item $p -Force -ErrorAction SilentlyContinue
    -not $r.Ok -and $stillThere
}
Test-Case 'permanent deletion works when it is confirmed' {
    if (-not $admin) { return 'skip' }
    $p = New-TestFile
    $f = New-TestFinding $p
    $r = Invoke-QpRemediate -Finding $f -Action Delete -Force
    $r.Ok -and -not (Test-Path -LiteralPath $p)
}
Test-Case 'the Recycle Bin keeps the file rather than destroying it' {
    if (-not $admin) { return 'skip' }
    $p = New-TestFile
    $f = New-TestFinding $p
    $r = Invoke-QpRemediate -Finding $f -Action RecycleBin
    $r.Ok -and -not (Test-Path -LiteralPath $p) -and $r.Note -match 'Recycle Bin'
}
Test-Case 'a file in a protected folder is refused, not deleted' {
    $f = New-QpFinding -Path (Join-Path $env:WINDIR 'System32\notepad.exe') -ThreatName 'Test:Win32/NotReally' -Source 'Quietpane check'
    $r = Invoke-QpRemediate -Finding $f -Action Delete -Force
    -not $r.Ok -and (Test-Path (Join-Path $env:WINDIR 'System32\notepad.exe'))
}
Test-Case 'restoring something that is no longer quarantined fails cleanly' {
    (Restore-QpQuarantineItem -Id 'nothing-like-this').Ok -eq $false
}
Test-Case 'quarantine actions are all written to the audit log' {
    if (-not $admin) { return 'skip' }
    $log = Get-Content (Join-Path $env:ProgramData 'Quietpane\audit.log') -Tail 30 -ErrorAction SilentlyContinue
    ($log -join "`n") -match 'Quarantine' -and ($log -join "`n") -match 'DeletePermanently'
}

Section 'Stopping a check, and saying where it has got to'
Test-Case 'nothing is treated as stopped when nobody is asking' {
    Set-QpCancelCheck $null
    -not (Test-QpCancelled)
}
Test-Case 'the engine sees Stop the moment the window sets it' {
    $box = @{ Stop = $false }
    Set-QpCancelCheck { $box.Stop }
    $before = Test-QpCancelled
    $box.Stop = $true
    $after = Test-QpCancelled
    Set-QpCancelCheck $null
    -not $before -and $after
}
Test-Case 'a progress update can never break a check' {
    Set-QpProgressSink { throw 'the window fell over' }
    try { Write-QpProgress -Stage 'x' -Step 1 -Of 14; $true } catch { $false } finally { Set-QpProgressSink $null }
}

# One stopped check, looked at from several angles below.
$seen = New-Object System.Collections.ArrayList
$stoppedReport = Join-Path $env:TEMP ('qp-stopped-' + [guid]::NewGuid().ToString('N') + '.html')
Set-QpProgressSink { param($p) [void]$seen.Add($p) }
Set-QpCancelCheck { $true }
$stopped = Invoke-QpAudit -OutFile $stoppedReport
Set-QpCancelCheck $null
Set-QpProgressSink $null

Test-Case 'a stopped check says it was stopped' { [bool]$stopped.Cancelled }
Test-Case 'a stopped check reports nothing rather than half a picture' { @($stopped.Findings).Count -eq 0 -and $stopped.Total -eq 0 }
Test-Case 'a stopped check writes no report' { -not (Test-Path -LiteralPath $stoppedReport) }
Test-Case 'a stopped check still says how long it ran and how much it saw' {
    $stopped.PSObject.Properties['Seconds'] -and $stopped.PSObject.Properties['Scanned'] -and [int]$stopped.Scanned -ge 0
}
Test-Case 'progress says which step of how many, and what it is doing' {
    $first = @($seen)[0]
    $null -ne $first -and $first.Of -eq 14 -and $first.Step -ge 1 -and [string]$first.Stage -ne ''
}

Section 'The summary at the end of a check'
$sumCounts = [ordered]@{ Critical = 1; High = 2; Medium = 0; Low = 0; Info = 5 }
Test-Case 'it says how much was looked at, in words a person reads' {
    $s = New-QpScanSummary -Counts $sumCounts -Tally @{} -Scanned 1234 -Seconds 75 -Outstanding 3
    $s.Lines[0] -match '1,234' -and $s.Lines[0] -match '1 min 15 sec'
}
Test-Case 'every severity is named, including the empty ones' {
    $s = New-QpScanSummary -Counts $sumCounts -Tally @{} -Scanned 10 -Seconds 5 -Outstanding 3
    ($s.Lines -join ' ') -match 'critical' -and ($s.Lines -join ' ') -match '0 medium' -and ($s.Lines -join ' ') -match '0 low'
}
Test-Case 'what was done about it is counted' {
    $s = New-QpScanSummary -Counts $sumCounts -Tally @{ Removed = 1; Quarantined = 2; Recycled = 1; Deleted = 1; Allowed = 1; Failed = 1 } -Scanned 10 -Seconds 5 -Outstanding 0
    $dealt = @($s.Lines | Where-Object { $_ -match '^Dealt with' })[0]
    $dealt -match '1 removed by Defender' -and $dealt -match '2 in Quietpane' -and $dealt -match '1 in the Recycle Bin' -and $dealt -match '1 deleted for good' -and $dealt -match '1 left alone' -and $dealt -match 'did not work'
}
Test-Case 'nothing done means no "dealt with" line at all' {
    $s = New-QpScanSummary -Counts $sumCounts -Tally @{} -Scanned 10 -Seconds 5 -Outstanding 3
    @($s.Lines | Where-Object { $_ -match 'Dealt with' }).Count -eq 0
}
Test-Case 'serious findings get a next step that points at them' {
    (New-QpScanSummary -Counts $sumCounts -Tally @{} -Scanned 10 -Seconds 5 -Outstanding 3).NextStep -match '3 serious item'
}
Test-Case 'a failed action without admin rights explains why' {
    $s = New-QpScanSummary -Counts $sumCounts -Tally @{ Failed = 1 } -Scanned 10 -Seconds 5 -Outstanding 1 -IsAdmin $false
    $s.NextStep -match 'administrator'
}
Test-Case 'a clean check ends calmly rather than inventing work' {
    $clean = [ordered]@{ Critical = 0; High = 0; Medium = 0; Low = 0; Info = 12 }
    $s = New-QpScanSummary -Counts $clean -Tally @{} -Scanned 900 -Seconds 40 -Outstanding 0
    $s.NextStep -match 'nothing needs doing'
}
Test-Case 'a stopped check is never dressed up as a finished one' {
    $s = New-QpScanSummary -Counts $null -Tally @{} -Scanned 120 -Seconds 9 -Outstanding 0 -Cancelled $true
    $s.Lines[0] -match 'Stopped' -and $s.Lines[0] -match 'Nothing on this PC was changed' -and $s.NextStep -match 'run the check again'
}

Section 'What starts when you sign in'
# Everything below runs against a throwaway registry area, never the real sign-in settings.
$testRoot = 'HKCU:\Software\QuietpaneTest'
function Reset-StartupTestArea {
    Remove-Item -Path $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -Path "$testRoot\Run" -Force | Out-Null
    New-Item -Path "$testRoot\Approved" -Force | Out-Null
    New-Item -Path "$testRoot\Apps\Test.StartupApp_abc123\StartIt" -Force | Out-Null
    New-Item -Path "$testRoot\Apps\Test.PolicyApp_abc123\StartIt" -Force | Out-Null
    Set-ItemProperty -Path "$testRoot\Run" -Name 'QpTestApp' -Value ('"' + (Join-Path $env:WINDIR 'notepad.exe') + '" /quiet')
    Set-ItemProperty -Path "$testRoot\Run" -Name 'SecurityHealth' -Value (Join-Path $env:WINDIR 'system32\SecurityHealthSystray.exe')
    Set-ItemProperty -Path "$testRoot\Apps\Test.StartupApp_abc123\StartIt" -Name State -Value 2 -Type DWord
    Set-ItemProperty -Path "$testRoot\Apps\Test.PolicyApp_abc123\StartIt" -Name State -Value 4 -Type DWord
}
function Get-TestRegValue([string]$Name) {
    # The module keeps its registry helper private, so the tests have their own.
    [pscustomobject]@{ Exists = $null -ne (Get-ItemProperty -Path "$testRoot\Approved" -Name $Name -ErrorAction SilentlyContinue) }
}
function Get-TestStartupItems {
    Get-QpStartupItems -RunSources @(@{ Key = "$testRoot\Run"; Approved = "$testRoot\Approved"; Everyone = $false }) -FolderSources @() -AppRoot "$testRoot\Apps"
}
function Get-NewestRestorePoint([datetime]$Since) {
    Get-ChildItem (Join-Path $env:ProgramData 'Quietpane\restore') -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '*-startup' -and $_.CreationTime -ge $Since } | Sort-Object CreationTime -Descending | Select-Object -First 1
}

Test-Case 'what Windows and drivers need is always kept on' {
    (Get-QpStartupAdvice 'SecurityHealth C:\Windows\system32\SecurityHealthSystray.exe').Keep -and
    (Get-QpStartupAdvice 'RtkAudUService "C:\Windows\System32\RtkAudUService64.exe"').Keep -and
    -not (Get-QpStartupAdvice 'Discord C:\Users\x\Discord\Update.exe').Keep
}
Test-Case 'common items get a plain-language note' {
    (Get-QpStartupAdvice 'MicrosoftEdgeAutoLaunch_1 msedge.exe --no-startup-window').Note -match 'startup boost' -and
    (Get-QpStartupAdvice 'Steam steam.exe -silent').Note -match 'game launcher' -and
    (Get-QpStartupAdvice 'SomethingNobodyHasHeardOf x.exe').Note -eq ''
}
Test-Case 'switching off writes exactly what Task Manager writes' {
    Reset-StartupTestArea
    Set-QpStartupApproved -Path "$testRoot\Approved" -Name 'X' -On $false
    $b = (Get-ItemProperty -Path "$testRoot\Approved" -Name 'X').X
    $when = [DateTime]::FromFileTimeUtc([BitConverter]::ToInt64($b, 4))
    Set-QpStartupApproved -Path "$testRoot\Approved" -Name 'Y' -On $true
    $y = (Get-ItemProperty -Path "$testRoot\Approved" -Name 'Y').Y
    $b.Length -eq 12 -and $b[0] -eq 3 -and [math]::Abs(([DateTime]::UtcNow - $when).TotalMinutes) -lt 5 -and $y[0] -eq 2
}
Test-Case 'on and off are read the way Task Manager records them' {
    Reset-StartupTestArea
    $before = @(Get-TestStartupItems | Where-Object { $_.ApprovedName -eq 'QpTestApp' })[0].On
    Set-QpStartupApproved -Path "$testRoot\Approved" -Name 'QpTestApp' -On $false
    $after = @(Get-TestStartupItems | Where-Object { $_.ApprovedName -eq 'QpTestApp' })[0].On
    $before -and -not $after
}
Test-Case 'Store apps are read, and policy-set ones are locked' {
    Reset-StartupTestArea
    $items = @(Get-TestStartupItems)
    $app = @($items | Where-Object { $_.Kind -eq 'App' -and $_.Command -like 'Test.StartupApp*' })[0]
    $pol = @($items | Where-Object { $_.Kind -eq 'App' -and $_.Command -like 'Test.PolicyApp*' })[0]
    $app.On -and -not $app.Locked -and $pol.On -and $pol.Locked -and $app.Name -eq 'Startup App'
}
Test-Case 'a kept item is refused, whatever is ticked' {
    Reset-StartupTestArea
    $items = @(Get-TestStartupItems)
    $keep = @($items | Where-Object { $_.ApprovedName -eq 'SecurityHealth' })[0]
    Invoke-QpStartup -Ids $keep.Id -Items $items -Preview:$false | Out-Null
    $keep.Keep -and -not (Get-TestRegValue -Name 'SecurityHealth').Exists
}
Test-Case 'a policy-set item is refused' {
    Reset-StartupTestArea
    $items = @(Get-TestStartupItems)
    $pol = @($items | Where-Object { $_.Command -like 'Test.PolicyApp*' })[0]
    Invoke-QpStartup -Ids $pol.Id -Items $items | Out-Null
    (Get-ItemProperty -Path "$testRoot\Apps\Test.PolicyApp_abc123\StartIt").State -eq 4
}
Test-Case 'refusing everything leaves no empty restore point behind' {
    Reset-StartupTestArea
    $since = (Get-Date).AddSeconds(-1)
    $items = @(Get-TestStartupItems)
    $refused = @($items | Where-Object { $_.Keep -or $_.Locked } | ForEach-Object { $_.Id })
    Invoke-QpStartup -Ids $refused -Items $items | Out-Null
    $null -eq (Get-NewestRestorePoint $since)
}
Test-Case 'preview changes nothing' {
    Reset-StartupTestArea
    $items = @(Get-TestStartupItems)
    Invoke-QpStartup -Ids @($items.Id) -Items $items -Preview | Out-Null
    -not (Get-TestRegValue -Name 'QpTestApp').Exists -and
    (Get-ItemProperty -Path "$testRoot\Apps\Test.StartupApp_abc123\StartIt").State -eq 2
}
Test-Case 'switching off and Undo round-trip, for a Run entry and a Store app' {
    Reset-StartupTestArea
    $since = (Get-Date).AddSeconds(-2)
    $items = @(Get-TestStartupItems)
    $ids = @($items | Where-Object { $_.ApprovedName -eq 'QpTestApp' -or $_.Command -like 'Test.StartupApp*' } | ForEach-Object { $_.Id })
    Invoke-QpStartup -Ids $ids -Items $items | Out-Null
    $offRun = ((Get-ItemProperty -Path "$testRoot\Approved" -Name 'QpTestApp').QpTestApp)[0] -eq 3
    $offApp = (Get-ItemProperty -Path "$testRoot\Apps\Test.StartupApp_abc123\StartIt").State -eq 1
    $rp = Get-NewestRestorePoint $since
    if (-not $rp) { return $false }
    Invoke-QpUndo -Path $rp.FullName | Out-Null
    $backRun = -not (Get-TestRegValue -Name 'QpTestApp').Exists     # it wasn't set before, so it's gone again
    $backApp = (Get-ItemProperty -Path "$testRoot\Apps\Test.StartupApp_abc123\StartIt").State -eq 2
    Remove-Item -LiteralPath $rp.FullName -Recurse -Force   # the test's own restore point, not the user's
    $offRun -and $offApp -and $backRun -and $backApp
}
Test-Case 'Undo puts back exactly the bytes that were there before' {
    Reset-StartupTestArea
    $original = [byte[]](2, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8)
    Set-ItemProperty -Path "$testRoot\Approved" -Name 'QpTestApp' -Value $original -Type Binary
    $since = (Get-Date).AddSeconds(-2)
    $items = @(Get-TestStartupItems)
    Invoke-QpStartup -Ids @($items | Where-Object { $_.ApprovedName -eq 'QpTestApp' } | ForEach-Object { $_.Id }) -Items $items | Out-Null
    $rp = Get-NewestRestorePoint $since
    if (-not $rp) { return $false }
    Invoke-QpUndo -Path $rp.FullName | Out-Null
    $now = (Get-ItemProperty -Path "$testRoot\Approved" -Name 'QpTestApp').QpTestApp
    Remove-Item -LiteralPath $rp.FullName -Recurse -Force
    (@(Compare-Object $original $now -SyncWindow 0)).Count -eq 0
}
Test-Case 'reading the real sign-in list never throws' { $null -ne @(Get-QpStartupItems) }
Remove-Item -Path $testRoot -Recurse -Force -ErrorAction SilentlyContinue

Section 'Live readings on Home'
Test-Case 'heat is always put into words, not left to colour' {
    (Get-QpHeatWord 40).Word -eq 'cool' -and (Get-QpHeatWord 60).Word -eq 'comfortable' -and (Get-QpHeatWord 75).Word -eq 'warm' -and
    (Get-QpHeatWord 88).Word -eq 'hot' -and (Get-QpHeatWord 97).Word -eq 'very hot'
}
Test-Case 'a driver''s own limit brings "very hot" forward' { (Get-QpHeatWord 82 -MaxC 90).Word -eq 'very hot' }
Test-Case 'a missing temperature says "not shared", never zero' {
    $h = Get-QpHeatWord $null
    $h.Word -eq 'not shared' -and $h.Level -eq 'none'
}
Test-Case 'setting up the readers never throws' { $null -ne (New-QpLiveMonitor) }
Test-Case 'a reading stays within believable ranges' {
    $m = New-QpLiveMonitor
    Start-Sleep -Milliseconds 1000
    $r = Get-QpLiveReading -Monitor $m
    $cpuOk = ($null -eq $r.CpuUsage) -or ($r.CpuUsage -ge 0 -and $r.CpuUsage -le 100)
    $tempOk = ($null -eq $r.CpuTempC) -or ($r.CpuTempC -gt 5 -and $r.CpuTempC -lt 130)
    $memOk = ($null -eq $r.MemUsed) -or ($r.MemUsed -ge 0 -and $r.MemUsed -le $r.MemTotal)
    $gpuOk = @($r.Gpus | Where-Object { $_.Usage -lt 0 -or $_.Usage -gt 100 -or ($null -ne $_.TempC -and ($_.TempC -le 0 -or $_.TempC -ge 130)) }).Count -eq 0
    $cpuOk -and $tempOk -and $memOk -and $gpuOk
}
Test-Case 'a thermal sensor that never moves is flagged rather than shown as live' {
    function New-FakeMonitor([scriptblock]$Kelvin) {
        $zone = [pscustomobject]@{}
        $zone | Add-Member -MemberType ScriptMethod -Name NextValue -Value $Kelvin
        [pscustomobject]@{ Cpu = $null; CpuName = ''; Zone = $zone; ZoneName = '\_TZ.TEST'; Limits = @(); Available = $null; MemTotal = [double]0
            Engines = $null; EnginePrev = $null; GpuMemory = $null; GpuSensors = $false; ZoneSeen = New-Object System.Collections.Generic.List[double] }
    }
    $stuck = New-FakeMonitor { 3252 }
    $moving = New-FakeMonitor { 3200 + (Get-Random -Minimum 0 -Maximum 100) }
    1..24 | ForEach-Object { $a = Get-QpLiveReading -Monitor $stuck; $b = Get-QpLiveReading -Monitor $moving }
    $a.CpuTempStuck -and -not $b.CpuTempStuck -and [math]::Abs($a.CpuTempC - 52.05) -lt 0.1
}
Test-Case 'Windows slowing the processor to cool it is noticed, and only then' {
    function New-LimitMonitor([double[]]$Values) {
        $limits = foreach ($v in $Values) {
            $c = [pscustomobject]@{ V = $v }
            $c | Add-Member -MemberType ScriptMethod -Name NextValue -Value { $this.V }
            $c
        }
        [pscustomobject]@{ Cpu = $null; CpuName = ''; Zone = $null; ZoneName = ''; Limits = @($limits); Available = $null; MemTotal = [double]0
            Engines = $null; EnginePrev = $null; GpuMemory = $null; GpuSensors = $false; ZoneSeen = New-Object System.Collections.Generic.List[double] }
    }
    $slowed = Get-QpLiveReading -Monitor (New-LimitMonitor 100, 80)     # two zones: the lower one counts
    $full = Get-QpLiveReading -Monitor (New-LimitMonitor 100)
    $unknown = Get-QpLiveReading -Monitor (New-LimitMonitor 0)          # 0 means "not reported", not "stopped"
    $none = Get-QpLiveReading -Monitor (New-LimitMonitor)
    $slowed.CpuThrottled -and $slowed.CpuLimitPct -eq 80 -and
    -not $full.CpuThrottled -and -not $unknown.CpuThrottled -and $null -eq $unknown.CpuLimitPct -and -not $none.CpuThrottled
}
Test-Case 'the graphics-driver code only asks questions' {
    # Only enumerate, query and close. Nothing that sets, escapes to the driver, or changes anything.
    $src = Get-Content (Join-Path $root 'src\Quietpane.psm1') -Raw
    $calls = @([regex]::Matches($src, 'DllImport\("gdi32\.dll"\)\]\s*static extern int (\w+)') | ForEach-Object { $_.Groups[1].Value })
    $calls.Count -eq 3 -and @($calls | Where-Object { $_ -notin 'D3DKMTEnumAdapters2', 'D3DKMTQueryAdapterInfo', 'D3DKMTCloseAdapter' }).Count -eq 0
}
Test-Case 'live readings write nothing to disk' {
    # Every file with its date, plus every folder by name. Folder dates are left out on purpose: Windows
    # updates a folder's date a moment late after something inside it is removed (an earlier test does that).
    $data = Join-Path $env:ProgramData 'Quietpane'
    $snap = {
        (@(Get-ChildItem $data -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object { "$($_.FullName)|$($_.LastWriteTimeUtc.Ticks)" }) +
         @(Get-ChildItem $data -Recurse -Force -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })) -join "`n"
    }
    $before = & $snap
    $m = New-QpLiveMonitor
    1..2 | ForEach-Object { Get-QpLiveReading -Monitor $m | Out-Null }
    $after = & $snap
    $before -eq $after
}

Section 'What''s using it'
$liveM = New-QpLiveMonitor
Start-Sleep -Milliseconds 1200
$liveR = Get-QpLiveReading -Monitor $liveM
Test-Case 'the busiest programs come with a name and a believable share' {
    @($liveR.CpuTop | Where-Object { -not $_.Name -or $_.Pct -lt 1 -or $_.Pct -gt 100 }).Count -eq 0 -and @($liveR.CpuTop).Count -le 3
}
Test-Case 'every graphics card says what is using it (possibly nothing)' {
    @($liveR.Gpus | Where-Object { -not $_.PSObject.Properties['Top'] }).Count -eq 0 -and
    @($liveR.Gpus | ForEach-Object { @($_.Top) } | Where-Object { $_ -and ($_.Pct -lt 1 -or $_.Pct -gt 100) }).Count -eq 0
}
Test-Case 'Quietpane names itself honestly' { (Get-QpProgramName -Monitor $liveM -Instance 'powershell' -ProcessId $PID) -eq 'Quietpane (this app)' }
Test-Case 'Windows'' own processes get plain names' {
    (Get-QpProgramName -Monitor $liveM -Instance 'dwm' -ProcessId 0) -eq 'Windows desktop' -and
    (Get-QpProgramName -Monitor $liveM -Instance 'MsMpEng' -ProcessId 0) -eq 'Microsoft Defender'
}
Test-Case 'the battery reading is a real percentage, or absent on a desktop' {
    $b = $liveR.Battery
    ($null -eq $b) -or ($b.Percent -ge 0 -and $b.Percent -le 100 -and $b.PluggedIn -is [bool])
}

Section 'Battery and drive health'
Test-Case 'battery health is a share of what it held new, or nothing' {
    $h = Get-QpBatteryHealth
    ($null -eq $h) -or ($h.Percent -ge 1 -and $h.Percent -le 100 -and $h.DesignWh -gt 0 -and $h.FullWh -gt 0)
}
Test-Case 'the battery report file is always deleted afterwards' {
    Get-QpBatteryHealth | Out-Null
    @(Get-ChildItem $env:TEMP -Filter 'Quietpane-battery-*.xml' -ErrorAction SilentlyContinue).Count -eq 0
}
Test-Case 'drive health uses Windows'' own verdict, and never throws' {
    $d = Get-QpDriveHealth
    ($null -eq $d) -or ($d.Health -in 'Healthy', 'Warning', 'Unhealthy', 'Unknown' -and $d.Media)
}
Test-Case 'drives have their own, cooler idea of hot' {
    (Get-QpHeatWord 55 -Kind Drive).Word -eq 'warm' -and (Get-QpHeatWord 72 -Kind Drive).Word -eq 'very hot' -and (Get-QpHeatWord 72).Word -eq 'warm'
}

Section 'What came back since last time'
$notePath = Join-Path $env:TEMP ('qp-note-' + [guid]::NewGuid().ToString('N') + '.json')
$pIds = @((Get-QpCatalog privacy).Items | Select-Object -First 4 | ForEach-Object { $_.Id })
function New-FakeState([string[]]$Applied = @(), [string[]]$Apps = @(), $Startup = @()) {
    $priv = @{}
    foreach ($i in (Get-QpCatalog privacy).Items) { $priv[$i.Id] = $(if ($Applied -contains $i.Id) { 'Applied' } else { 'NotApplied' }) }
    @{ Privacy = $priv; Vendors = @(); Startup = @($Startup)
       Apps = @($Apps | Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ Name = $_; Title = "App $_" } }) }
}
function New-FakeStartup([string]$Id, [bool]$On) { [pscustomobject]@{ Id = $Id; Name = "Item $Id"; On = $On; Keep = $false } }
Test-Case 'the first look just takes a note and reports nothing' {
    Remove-Item -LiteralPath $notePath -Force -ErrorAction SilentlyContinue
    $d = Update-QpQuietNote -State (New-FakeState $pIds[0..2]) -Path $notePath
    $d.Count -eq 0 -and (Test-Path -LiteralPath $notePath)
}
Test-Case 'a setting that switched itself back on is reported, by name' {
    Update-QpQuietNote -State (New-FakeState $pIds[0..2]) -Path $notePath -Accept | Out-Null
    $d = Update-QpQuietNote -State (New-FakeState $pIds[1..2]) -Path $notePath
    $d.Count -eq 1 -and $d.Privacy[0].Id -eq $pIds[0] -and $d.Privacy[0].Title
}
Test-Case 'it keeps being reported until it is dealt with' {
    (Update-QpQuietNote -State (New-FakeState $pIds[1..2]) -Path $notePath).Count -eq 1
}
Test-Case 'things that got quieter are never reported, only noted' {
    $d = Update-QpQuietNote -State (New-FakeState $pIds[0..3]) -Path $notePath
    $again = Update-QpQuietNote -State (New-FakeState $pIds[0..2]) -Path $notePath   # the newly quiet one counts from now on
    $d.Count -eq 0 -and $again.Count -eq 1 -and $again.Privacy[0].Id -eq $pIds[3]
}
Test-Case '"That was me" clears it, and it stays cleared' {
    Update-QpQuietNote -State (New-FakeState $pIds[0..2]) -Path $notePath -Accept | Out-Null
    (Update-QpQuietNote -State (New-FakeState $pIds[0..2]) -Path $notePath).Count -eq 0
}
Test-Case 'an app that came back is reported; one that went is not' {
    Update-QpQuietNote -State (New-FakeState -Apps 'Kept') -Path $notePath -Accept | Out-Null
    $back = Update-QpQuietNote -State (New-FakeState -Apps 'Kept', 'Returned') -Path $notePath
    Update-QpQuietNote -State (New-FakeState -Apps 'Kept') -Path $notePath -Accept | Out-Null
    $gone = Update-QpQuietNote -State (New-FakeState -Apps @()) -Path $notePath
    $back.Count -eq 1 -and $back.Apps[0].Id -eq 'Returned' -and $back.Apps[0].Title -eq 'App Returned' -and $gone.Count -eq 0
}
Test-Case 'a startup item back on is reported; an uninstalled one is not' {
    Update-QpQuietNote -State (New-FakeState -Startup @((New-FakeStartup 's1' $false), (New-FakeStartup 's2' $false))) -Path $notePath -Accept | Out-Null
    $d = Update-QpQuietNote -State (New-FakeState -Startup @((New-FakeStartup 's1' $true))) -Path $notePath   # s1 back on, s2 gone
    $d.Count -eq 1 -and $d.Startup[0].Id -eq 's1' -and $d.Startup[0].Title -eq 'Item s1'
}
Test-Case 'a Windows update in between is named as the likely reason' {
    Update-QpQuietNote -State (New-FakeState $pIds[0..2]) -Path $notePath -Accept | Out-Null
    $note = Get-Content -LiteralPath $notePath -Raw | ConvertFrom-Json
    $note.Windows = [pscustomobject]@{ Display = '21H2'; Build = '1.1' }
    $note | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $notePath -Encoding UTF8
    $d = Update-QpQuietNote -State (New-FakeState $pIds[1..2]) -Path $notePath
    $d.WindowsUpdated -and $d.WindowsChange -match '^from 21H2 to '
}
Test-Case 'switching off what came back, when nothing did, changes nothing and saves nothing' {
    $since = (Get-Date).AddSeconds(-1)
    Invoke-QpPutBack | Out-Null
    @(Get-ChildItem (Join-Path $env:ProgramData 'Quietpane\restore') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*-came-back' -and $_.CreationTime -ge $since }).Count -eq 0
}
Remove-Item -LiteralPath $notePath -Force -ErrorAction SilentlyContinue

Section 'Reading the PC quickly, without cutting corners'
Test-Case 'the shared lookups give exactly the same answers as asking one by one' {
    # Scheduled-task checks are what the shared lookup speeds up, so compare a handful both ways.
    # Picks tasks that really exist on this PC, so the comparison means something.
    $mod = Get-Module Quietpane
    $present = & $mod { Get-QpTasksByPath }
    $taskActions = @((Get-QpCatalog privacy).Items | ForEach-Object { $_.Actions } | Where-Object { $_.Type -eq 'Task' -and $present.ContainsKey($_.Path) } | Select-Object -First 4)
    if (-not $taskActions.Count) { return 'skip' }
    $oneByOne = @($taskActions | ForEach-Object { "$(& $mod { param($a) Test-QpActionApplied $a } $_)" }) -join ','
    $shared = (& $mod { param($list) Start-QpStateCache; try { @($list | ForEach-Object { "$(Test-QpActionApplied $_)" }) } finally { Stop-QpStateCache } } $taskActions) -join ','
    $oneByOne -eq $shared
}
Test-Case 'the whole state comes back in one pass, and the shared lookups are let go afterwards' {
    $s = Get-QpState
    $keysOk = @('Privacy', 'Vendors', 'Apps', 'Startup', 'Cleanup', 'Restore' | Where-Object { -not $s.ContainsKey($_) }).Count -eq 0
    $keysOk -and $null -eq (& (Get-Module Quietpane) { $script:StateCache })
}
Test-Case 'catalogs are read once and remembered' {
    [object]::ReferenceEquals((Get-QpCatalog privacy), (Get-QpCatalog privacy))
}
Test-Case 'when nothing changes, no restore point is kept' {
    $since = (Get-Date).AddSeconds(-1)
    Invoke-QpRemoveApps -Names 'Quietpane.Test.NotAnApp' | Out-Null    # nothing by that name, so nothing changes
    @(Get-ChildItem (Join-Path $env:ProgramData 'Quietpane\restore') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.CreationTime -ge $since }).Count -eq 0
}
Test-Case 'an empty restore point is never offered in Undo' {
    $fake = Join-Path $env:ProgramData 'Quietpane\restore\19990101-000000-quietpane-test'
    New-Item -ItemType Directory -Path $fake -Force | Out-Null
    '{ "Name": "test", "Entries": [] }' | Set-Content -LiteralPath (Join-Path $fake 'state.json') -Encoding UTF8
    $listed = @(Get-QpRestorePoints | Where-Object { $_.Name -eq '19990101-000000-quietpane-test' }).Count
    Remove-Item -LiteralPath $fake -Recurse -Force    # the test's own folder
    $listed -eq 0
}

Section 'The app icon'
Add-Type -AssemblyName PresentationCore
Test-Case 'the icon has every size Windows asks for' {
    $ico = (Get-QpInfo).IconPath
    $dec = New-Object System.Windows.Media.Imaging.IconBitmapDecoder ([Uri]$ico), 'None', 'OnLoad'
    $sizes = @($dec.Frames | ForEach-Object { $_.PixelWidth } | Sort-Object)
    ($sizes -join ',') -eq '16,20,24,32,40,48,64,256'
}
Test-Case 'the icon is the KomodoWorks emblem, on a see-through background' {
    $dec = New-Object System.Windows.Media.Imaging.IconBitmapDecoder ([Uri](Get-QpInfo).IconPath), 'None', 'OnLoad'
    $big = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap ($dec.Frames | Where-Object { $_.PixelWidth -eq 256 }), ([System.Windows.Media.PixelFormats]::Bgra32), $null, 0
    $px = New-Object byte[] (256 * 256 * 4)
    $big.CopyPixels($px, 256 * 4, 0)
    function Get-Px([int]$x, [int]$y) { $i = ($y * 256 + $x) * 4; '{0},{1},{2},{3}' -f $px[$i + 2], $px[$i + 1], $px[$i], $px[$i + 3] }
    # corner clear, dark square in the KomodoWorks anchor colour, teal square peeking out bottom-right
    (Get-Px 0 0).EndsWith(',0') -and (Get-Px 40 40) -eq '15,27,28,255' -and (Get-Px 240 240) -eq '23,155,131,255'
}
Test-Case 'the window''s only call into Windows names the app for the taskbar' {
    $src = Get-Content (Join-Path $root 'Quietpane.ps1') -Raw
    $calls = @([regex]::Matches($src, 'DllImport\("(\w+)\.dll"[^\]]*\)\]\s*public static extern int (\w+)') | ForEach-Object { '{0}!{1}' -f $_.Groups[1].Value, $_.Groups[2].Value })
    ($calls -join ';') -eq 'shell32!SetCurrentProcessExplicitAppUserModelID'
}

Section 'The checks a person has to do by hand'
Test-Case 'the manual test pages are written down, including the AMTSO ones' {
    $doc = Join-Path $root 'docs\manual-checks.md'
    if (-not (Test-Path $doc)) { return $false }
    $text = Get-Content $doc -Raw
    $text -match 'AMTSO' -and $text -match 'amtso\.org' -and $text -match 'EICAR'
}
Test-Case 'the app itself never downloads a test file' {
    # AMTSO checks are done in a browser on purpose: Quietpane makes no network requests at all.
    $lines = @(Get-Content (Join-Path $root 'src\Quietpane.psm1')) + @(Get-Content (Join-Path $root 'Quietpane.ps1')) |
        Where-Object { $_ -notmatch '\$suspicious(Cmd|Task)\s*=' }   # those two lines are what a scan looks FOR
    [regex]::Matches(($lines -join "`n"), '(?i)Invoke-WebRequest|Invoke-RestMethod|DownloadFile|DownloadString|WebClient|HttpClient').Count -eq 0
}

Section 'With the real antivirus (needs -Live and administrator rights)'
if (-not $Live) {
    Write-Host '  SKIP  EICAR detection (run with -Live to include it)' -ForegroundColor DarkGray
    $script:Skip++
} else {
    Test-Case 'Defender detects the EICAR test file and Quietpane calls it Info, not malware' {
        $dir = Join-Path $env:TEMP ('qp-eicar-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        try {
            # assembled here so the test string is never stored in the repository
            $eicar = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$' + 'EICAR-STANDARD-ANTIVIRUS-TEST-FILE' + '!$H+H*'
            [IO.File]::WriteAllText((Join-Path $dir 'qp-test.com'), $eicar)
            $r = Invoke-QpThreatScan -Type Custom -Path $dir
            $hit = @($r.Findings | Where-Object { $_.Path -like "$dir*" }) | Select-Object -First 1
            $null -ne $hit -and $hit.Severity -eq 'Info' -and $hit.Source -eq 'Microsoft Defender' -and $hit.Family -eq 'EICAR test file'
        } finally {
            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ("`n{0} passed, {1} failed, {2} skipped" -f $script:Pass, $script:Fail, $script:Skip) -ForegroundColor $(if ($script:Fail) { 'Red' } else { 'Green' })
if ($script:Fail) { exit 1 }
