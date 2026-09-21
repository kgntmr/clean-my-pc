<p align="center">
  <a href="https://www.komodoworks.com"><img src="assets/komodoworks-logo.png" width="96" alt="KomodoWorks emblem"></a>
</p>

<h1 align="center">Quietpane</h1>

<p align="center">
  <b>Take your Windows PC back.</b><br>
  Switch off tracking, clear out the bloat your PC came with, and free up space. Everything happens on your PC, and nothing leaves it.<br><br>
  Developed by <a href="https://www.komodoworks.com"><b>KomodoWorks.com</b></a> &middot; Free &amp; open source (MIT) &middot; Windows 10 / 11
</p>

<p align="center">
  <a href="https://github.com/kgntmr/quietpane/releases/latest/download/Quietpane.zip"><b>⬇&nbsp;&nbsp;Download Quietpane</b></a> &nbsp;(one small ZIP file)
</p>

<p align="center"><img src="docs/screenshot-home.png" width="820" alt="Quietpane home screen with one big 'Quiet my PC now' button"></p>

## Get started

1. **[Download Quietpane](https://github.com/kgntmr/quietpane/releases/latest/download/Quietpane.zip)**.
2. **Unzip it:** right-click **Quietpane.zip** → **Extract All** → **Extract**. It can't start from inside the ZIP.
3. In the new folder, double-click **Start Quietpane**, then press **Quiet my PC now**.

It shows what it will do before doing anything, takes about a minute, and **Undo everything** puts it all back. You need Windows 10 or 11 and an administrator account. Nothing is installed.

Quietpane isn't [digitally signed](#code-signing-policy) yet, so Windows asks a few questions first:

| Windows says | Click |
|---|---|
| "Windows protected your PC" | **More info** → **Run anyway** |
| "Do you want to run this file?" | **Run** |
| "Do you want to allow this app to make changes?" | **Yes** |

Just want a check-up that changes nothing? Double-click **Safety scan only** instead.

> **A good start, not a guarantee.** Quietpane tidies up the usual troublemakers, but it can't promise a PC is clean. If yours still feels wrong, run a deeper scan with a dedicated security tool too.

## How it treats your PC

- **Collects nothing, connects to nothing.** No accounts, analytics, telemetry or ads, and no network requests at all. [Check for yourself](#verify-it-yourself).
- **Tells you first.** Every item explains what it does and its side effects, and **Preview** shows exactly what would change.
- **Can be undone.** Changes go into a restore point, and clean-up only moves files to your Recycle Bin. The three exceptions say so before you confirm: removing an app, uninstalling a brand extra, and deleting a threat for good.
- **Leaves your security alone.** Defender, SmartScreen, the firewall and Windows Update are never touched.
- **Hides nothing.** Plain-text PowerShell you can read, plus a few lines of C# that ask the graphics driver for its temperature. No installer, no `.exe`.

## What's inside

**Home.** Cards show what could be better, and **Quiet my PC now** applies the recommended items that aren't done yet, all in one restore point, so **Undo everything** really does undo everything. It never uninstalls a program on its own. If a Windows update switches things back on, Home says what came back and offers to switch exactly those off again.

**Health.** How hard the processor, graphics card and memory are working, how warm they are, and which programs are using them most, updated every 2 seconds while the tab is open. Also the battery's charge and how much it holds compared with new, and the drive's health, wear and temperature. The graphics temperature comes from the driver, as in Task Manager. The processor's comes from Windows' thermal sensor, so treat it as a guide: reading the chip itself would need a kernel driver, and Quietpane won't install one. Anything a PC doesn't share says **not shared**.

**Safety scan.** Asks Microsoft Defender what it has found, and looks for the tricks adware uses: odd startup entries and tasks, hijacked network settings, unsigned or tampered programs, cracked-software traces, browser add-ons and notification spam. For anything suspicious, it also shows the folders created at the same moment, which is usually the culprit. Looking changes nothing.

Every finding says who found it: **Microsoft Defender** (a real detection, named by Defender and explained in plain words) or a **Quietpane check** (a signal, not proof, and never a malware family). You decide what happens: let Defender handle it, quarantine it (you can put it back), move it to the Recycle Bin, or delete it for good (you're asked twice). **Leave it for now** never creates a Defender exclusion. Windows' own folders are refused, and every action is logged.

**Privacy.** 32 settings in five sections: Windows telemetry, privacy, ads and tips, background services, and browsers and other software (Edge, Chrome, Office, VS Code and more). Anything already done says so.

**Telemetry.** The background extras your PC's makers left running (NVIDIA, Intel, AMD, MSI, ASUS, Dell, HP, Lenovo, Acer), listed only if they're actually on your PC. It switches off reporting, updaters and helpers; drivers are never touched and the brand's own app still works. Extras you could remove are left unticked, and Quietpane warns you before removing one because that can't be undone.

**Apps.** *Starts when you sign in:* switch items off the way Task Manager does, with Undo; Windows Security and driver helpers are never offered. *Apps you could remove:* known bloat only. The Store, Camera, Photos, Calculator, Notepad, Paint and Snipping Tool are never on the list.

**Free up space** moves temp files, crash dumps, caches and old installers to the Recycle Bin. **Undo** puts back every recorded change. **About** holds the policies, readable offline.

## What it deliberately doesn't do

| Left alone | Why |
|---|---|
| Defender, SmartScreen, firewall, Windows Update | Your security and updates come first |
| Drivers, audio and chipset software | Your hardware has to keep working |
| The global "background apps off" switch | It breaks notifications for Store apps |
| Blocking Microsoft servers in the hosts file | It breaks Windows Update, the Store and Defender |
| Deleting NVIDIA's telemetry plugin | It breaks NVIDIA App, so the servers are blocked instead ([why](docs/LESSONS-LEARNED.md#nvidia-app-telemetry-cannot-be-deleted)) |
| Removing Microsoft Edge | Windows blocks it outside the EEA, and WebView2 must stay |

## Verify it yourself

1. **Read it.** The app is `Quietpane.ps1` (the window), `src/Quietpane.psm1` (the engine) and `src/catalog/*.psd1` (the lists of settings, apps, folders and brands). The only non-PowerShell code is a short C# block in the engine. It asks the graphics driver three read-only questions: list the adapters, ask each one, close it.
2. **Search for network code.** In the folder, run:
   ```powershell
   Select-String -Path .\Quietpane.ps1, .\src\Quietpane.psm1 -Pattern 'Invoke-WebRequest|Invoke-RestMethod|WebClient|HttpClient|BitsTransfer|TcpClient|curl|wget|DownloadString'
   ```
   You'll find exactly two matches: the scanner's **detection patterns** in `src/Quietpane.psm1`, which are text it looks *for* in malicious startup entries, not network calls.
3. **Watch it.** Open **Resource Monitor** (`resmon`) → **Network** while you use the app. Nothing connects. Your browser opens only when **you** click a link.
4. **See what it keeps.** `%ProgramData%\Quietpane` holds restore points and their logs, the audit log, the quarantine, and a few small notes (see the [Privacy Policy](PRIVACY.md)). Scan reports go on your Desktop. Delete any of it whenever you like.

## FAQ

**A window full of code opened, or Windows asked "How do you want to open this file?"**
You opened one of the app's own files. Close it, pick nothing, and double-click **Start Quietpane** instead.

**Chrome or Edge says "Managed by your organization".**
That appears whenever a browser policy is set, which is how the telemetry switches are locked. Nobody controls your browser, and Undo removes the policies.

**Windows still says diagnostic data is "Required".**
Windows Home and Pro can't go below Required. Switching off the DiagTrack service is what actually stops it, and Quietpane does that.

**Some items say [not on this PC].**
That service, task or program isn't on your Windows version, or is already gone.

**Is my download genuine?**
Only download from this repository's [Releases](https://github.com/kgntmr/quietpane/releases) page. [Here's how to check the file](SECURITY.md#check-that-your-download-is-genuine).

**How do I remove Quietpane?**
Removing it doesn't undo its changes, so use **Undo** first if you want your PC back as it was. Then delete the Quietpane folder and any Quietpane-Report files on your Desktop. Your undo history stays in `C:\ProgramData\Quietpane` until you delete that too.

## Privacy, terms and security

- **[Privacy Policy](PRIVACY.md):** collects no personal data and makes no network connections.
- **[Terms of Use](TERMS.md):** free, open source, provided as is. Irish law; your consumer rights are unaffected.
- **[Security Policy](SECURITY.md):** reporting a vulnerability, and telling a genuine copy from a fake.
- **[License](LICENSE):** MIT.

Quietpane is independent and not affiliated with or endorsed by Microsoft, NVIDIA, Intel, AMD or any PC maker. All trademarks belong to their owners.

## Code Signing Policy

Free code signing provided by [SignPath.io](https://about.signpath.io), certificate by [SignPath Foundation](https://signpath.org).

> **Status:** applied for in September 2026, waiting for approval. Until then releases are **not signed** and Windows shows "Unknown publisher". This section will say when signed releases start.

**What gets signed:** only files built from this repository's source by GitHub Actions and published on its [Releases](https://github.com/kgntmr/quietpane/releases) page. Every signing request is approved by hand.

| Role | Members |
|---|---|
| Committers and reviewers | [kgntmr](https://github.com/kgntmr) (KomodoWorks) |
| Approvers | [kgntmr](https://github.com/kgntmr) (KomodoWorks) |

**Privacy:** This program will not transfer any information to other networked systems unless specifically requested by the user or the person installing or operating it. Details: [Privacy Policy](PRIVACY.md).

## For developers

- **Run from source:** clone the repository and double-click `Start Quietpane.cmd` (or `Safety scan only.cmd`).
- **Build the download:** `powershell -ExecutionPolicy Bypass -File tools\build-release.ps1` creates `dist\Quietpane.zip` and prints its SHA256. The ZIP holds the app's files from this repository, unchanged; the tests and build tools are left out.
- **Try the window safely:** `.\Quietpane.ps1 -SelfTest` builds it without showing it; add `-Snapshot file.png -SnapshotTab 0` to save a picture.
- **Run the tests:** `powershell -ExecutionPolicy Bypass -File tests\Run-QuietpaneTests.ps1`, and add `-Live` for the EICAR check. No real malware is used anywhere, and the EICAR string is built at runtime, so it's never stored here. The six quarantine tests need administrator rights. From the repository folder, run this in an ordinary PowerShell window and answer **Yes**:
  ```powershell
  Start-Process powershell -Verb RunAs -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-File',"$PWD\tests\Run-QuietpaneTests.ps1",'-Live'
  ```
  An elevated window says "Administrator:" in its title bar. All 109 checks run there.
- **Check by hand:** [`docs/manual-checks.md`](docs/manual-checks.md) lists what still needs a person, including the AMTSO feature checks. Those stay manual on purpose: automating them would mean the app downloading files.
- **Contribute:** the lists in [`src/catalog/`](src/catalog) are plain data, so adding a setting, app, folder, brand or startup note needs no code. Describe side effects honestly, and test with **Preview** first. The reasons behind a few design choices are in [`docs/LESSONS-LEARNED.md`](docs/LESSONS-LEARNED.md).

---

<p align="center">
  <a href="https://www.komodoworks.com"><img src="assets/komodoworks-logo.png" width="40" alt="KomodoWorks"></a><br>
  <b>Developed by <a href="https://www.komodoworks.com">KomodoWorks.com</a></b>, an independent technology studio in Dublin, Ireland &middot; <a href="https://komodoworks.com/en/contact">Get in touch</a>
</p>
