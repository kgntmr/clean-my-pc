#Requires -Version 5.1
<#
    Quietpane's safety checks, checked.

        powershell -ExecutionPolicy Bypass -File tests\Run-QuietpaneTests.ps1
        powershell -ExecutionPolicy Bypass -File tests\Run-QuietpaneTests.ps1 -Live   (adds the EICAR test)

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
