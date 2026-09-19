<p align="center">
  <a href="https://www.komodoworks.com"><img src="assets/komodoworks-logo.png" width="96" alt="KomodoWorks emblem"></a>
</p>

<h1 align="center">Clean My PC</h1>

<p align="center">
  <b>Take your Windows PC back.</b><br>
  Scan for adware tricks, switch off telemetry, remove bloat and free up space. Everything happens on your PC, and nothing leaves it.<br><br>
  Developed by <a href="https://www.komodoworks.com"><b>KomodoWorks.com</b></a> &middot; Free &amp; open source (MIT) &middot; Windows 10 / 11
</p>

<p align="center">
  <a href="https://github.com/kgntmr/clean-my-pc/releases/latest/download/CleanMyPC.zip"><b>⬇&nbsp;&nbsp;Download Clean My PC</b></a> &nbsp;(one small ZIP file)
</p>

---

## Get started in 3 steps

1. **[Download Clean My PC](https://github.com/kgntmr/clean-my-pc/releases/latest/download/CleanMyPC.zip)**.
2. **Unzip it:** right-click the downloaded **CleanMyPC.zip** → **Extract All** → **Extract**. *It can't start from inside the ZIP.*
3. In the new **CleanMyPC** folder, double-click **Start Clean My PC**, then click the big **Clean my PC now** button.

That's it. It tells you what it will do before it does anything, finishes in about a minute, and has an **Undo everything** button. You never need to open the *App files* folder.

<p align="center"><img src="docs/screenshot-home.png" width="820" alt="Clean My PC home screen with one big 'Clean my PC now' button"></p>

**If Windows asks questions first** (this is normal for new free software):

| Windows says | Click |
|---|---|
| "Windows protected your PC" | **More info** → **Run anyway** |
| "Do you want to run this file?" | **Run** |
| "Do you want to allow this app to make changes?" | **Yes** |

Why? Clean My PC isn't digitally signed yet, so Windows says the publisher is unknown. We've applied for free code signing (see [Code Signing Policy](#code-signing-policy)). Meanwhile, every file is plain text, so you can open any of them in Notepad and read exactly what it does.

**Windows asked "How do you want to open this file?" or a window full of code opened?** You opened one of the app's own files. Close it (pick nothing) and double-click **Start Clean My PC** instead.

Just want a check-up that changes nothing? Double-click **Safety scan only** instead. Want to make sure your download is genuine? [Here's how](SECURITY.md#check-that-your-download-is-genuine).

**Requirements:** Windows 10 or 11 and an administrator account. Nothing needs to be installed.

---

## Why this exists

Almost everything on a modern PC reports home. Windows sends diagnostic data, browsers send usage statistics, graphics drivers ship telemetry plugins, and "free" downloads bring adware that hides in scheduled tasks. Most people never agreed to any of it knowingly, and most clean-up tools either don't explain what they change or collect data of their own.

**Clean My PC works the other way round:**

- 🔒 **Collects nothing.** No accounts, analytics, telemetry, crash reports, ads, cookies or tracking.
- 🌐 **Connects to nothing.** The app makes no network requests. Don't take our word for it: [verify it yourself](#verify-it-yourself).
- 👀 **Shows you everything first.** Every item explains what it does and its side effects. **Preview** shows exactly what would change.
- 🖱️ **One click for everyone.** "Clean my PC now" applies only the safe, recommended changes. The detailed tabs are there if you'd rather choose yourself.
- ↩️ **Can be undone.** Every change creates a restore point, and files only ever go to your Recycle Bin.
- 📖 **Hides nothing.** Plain-text PowerShell you can read line by line. No `.exe`, no installer, no obfuscation.
- 🛡️ **Leaves your security alone.** Defender, SmartScreen, the firewall and Windows Update are never touched.

It was built from a real, hands-on clean-up of a gaming and development laptop. That clean-up found adware that re-installed itself from a scheduled task and traced it back to the cracked game that brought it in. Those [lessons learned](docs/LESSONS-LEARNED.md) are built into the tool.

---

## What each tab does

### Home
The one-click screen. Cards show what can be improved on this PC (tracking and ads, unneeded apps, space, NVIDIA, adware check). **Clean my PC now** applies only the recommended items that aren't done yet, all in **one** restore point, so **Undo everything** really undoes everything.

### Safety scan (read-only)
| Check | What it looks for |
|---|---|
| Startup entries | Run keys and Startup folders that open websites, hidden PowerShell, `mshta`/`wscript`, or programs in Temp |
| Scheduled tasks | Tasks that re-create startup entries (`reg add ...\Run`), open URLs or run hidden scripts |
| **"What installed this?"** | For every suspicious task, lists folders created **within 3 minutes** of it. That's usually the game or program that brought it in. |
| Other persistence | WMI event consumers, IFEO debugger hijacks, Winlogon shell changes, AppInit_DLLs |
| Network hijacks | Hosts-file redirects, proxies, DNS servers |
| Files | Unsigned programs in user folders, **modified signed programs** (broken signature), cracked-software traces |
| Browsers | Extensions that can read every site, and sites allowed to push notifications |
| Security | Defender status and definition age, suspicious Defender exclusions, firewall |
| Privacy | Recommended privacy settings still off, NVIDIA telemetry status |
| Performance and space | RAM use, top processes, startup count, reclaimable space, folders unused for 6+ months |

### Privacy
32 settings across **Windows telemetry**, **Privacy**, **Ads, tips & suggestions**, **Background services** and **Browsers & other software** (Edge, Chrome, Office, Intel DTT, VS Code, .NET/PowerShell CLIs). Items already done show **[already applied]**.

### NVIDIA
Blocks only NVIDIA's telemetry, analytics, survey and experiment servers, and sets NVIDIA's own opt-out flags. **NVIDIA App, driver updates and game optimisation keep working.** Deleting NVIDIA's telemetry plugin breaks NVIDIA App 11, and we [found that out the hard way](docs/LESSONS-LEARNED.md#nvidia-app-telemetry-cannot-be-deleted).

### Apps
Shows only known bloat that's actually installed. Store, Camera, Photos, Calculator, Notepad, Paint, Snipping Tool, Terminal, codecs and driver control panels are **never** offered.

### Free up space
Temp files, crash dumps, error-report archives, old NVIDIA installers, shader caches, browser caches and the Windows Update download cache, each with its size. Everything goes to the Recycle Bin.

### Undo
Restore points for every change (one-click or Apply). Undo puts back services, tasks, registry values, environment variables, VS Code settings and hosts entries.

### About
Privacy Policy, Terms of Use, License and Security policy, readable offline inside the app.

---

## Verify it yourself

Every claim above can be checked in a few minutes.

**1. Read it.** Three places hold the whole app: `CleanMyPC.ps1` (the window), `src/CleanMyPC.psm1` (the engine) and `src/catalog/*.psd1` (the lists of settings, apps and folders). `tools/` only contains the download's start files and the script that builds the download ZIP. In the download, the app is in the *App files - no need to open* folder.

**2. Search for network code.** Open PowerShell in the folder and run:
```powershell
Select-String -Path .\CleanMyPC.ps1, .\src\CleanMyPC.psm1 -Pattern 'Invoke-WebRequest|Invoke-RestMethod|WebClient|HttpClient|BitsTransfer|TcpClient|curl|wget|DownloadString'
```
You'll find exactly two matches, both in `src/CleanMyPC.psm1`: the lines defining `$suspiciousCmd` and `$suspiciousTask`. Those are the **scanner's detection patterns**. They look **for** malware that uses `downloadstring`/`invoke-webrequest` in startup entries and scheduled tasks. They're text patterns, not network calls.

**3. Watch it.** Open **Resource Monitor** (`resmon`) → **Network** while you use the app. PowerShell makes no connections. The only thing that goes online is your browser, and only when **you** click a link.

**4. See what it stored.** Everything is in `%ProgramData%\CleanMyPC` (restore points and logs) and in the report on your Desktop. Delete them any time.

---

## What it deliberately does *not* do

| Not touched | Why |
|---|---|
| Microsoft Defender, SmartScreen, firewall | Security |
| Windows Update, update compatibility checks | Keeps updates safe (DiagTrack is off, so nothing gets uploaded anyway) |
| The global "background apps off" switch | Breaks notifications and background work for packaged apps |
| Hosts-file blocking of Microsoft servers | Breaks Windows Update, the Store and Defender |
| Deleting NVIDIA's telemetry plugin | Breaks NVIDIA App. We block its servers instead. |
| Removing Microsoft Edge | Windows blocks it outside the EEA, and WebView2 must stay |
| Permanently deleting anything | Your Recycle Bin, your decision |

Windows Home/Pro treat "diagnostic data = 0" as "Required". The effective switch is disabling the DiagTrack service, which this tool does. Big Windows updates can quietly turn tips back on, so run it again after them.

---

## Privacy, terms & security

- **[Privacy Policy](PRIVACY.md):** the app collects no personal data and makes no network connections.
- **[Terms of Use](TERMS.md):** free, open source, provided as is. Irish law applies, and consumer rights are unaffected.
- **[Security Policy](SECURITY.md):** how to report a vulnerability, and how to tell a genuine copy from a fake. **Only download it from this repository's [Releases](https://github.com/kgntmr/clean-my-pc/releases) page.**
- **[License](LICENSE):** MIT.

Clean My PC is independent and not affiliated with or endorsed by Microsoft, NVIDIA, Intel or Google. All trademarks belong to their owners.

---

## Code Signing Policy

Free code signing provided by [SignPath.io](https://about.signpath.io), certificate by [SignPath Foundation](https://signpath.org).

> **Status:** applied for in September 2026, waiting for approval. Until it's approved, releases are **not signed yet** and Windows shows "Unknown publisher". This section will say when signed releases start.

**What gets signed:** only files built from this repository's source code by GitHub Actions and published on this repository's [Releases](https://github.com/kgntmr/clean-my-pc/releases) page. Every signing request is approved by hand.

**Team roles**

| Role | Members |
|---|---|
| Committers and reviewers | [kgntmr](https://github.com/kgntmr) (KomodoWorks) |
| Approvers | [kgntmr](https://github.com/kgntmr) (KomodoWorks) |

**Privacy:** This program will not transfer any information to other networked systems unless specifically requested by the user or the person installing or operating it. Details: [Privacy Policy](PRIVACY.md).

---

## FAQ

**Chrome or Edge says "Managed by your organization".**
That appears whenever a browser policy is set, which is how the telemetry switches are locked. Nobody controls your browser. Undo removes the policies.

**Some items say [not on this PC].**
That service, task or program doesn't exist on your Windows version, or has already been removed.

**Does it work on several PCs?**
Yes. Each PC keeps its own restore points.

**How do I remove Clean My PC?**
Removing Clean My PC doesn't undo its changes. If you want your PC back exactly as it was, click **Undo** first, then delete the CleanMyPC folder (and any CleanMyPC-Report files on your Desktop). Nothing is installed, so that's all.
Your undo history stays in `C:\ProgramData\CleanMyPC`. If you change your mind later, download Clean My PC again and use the Undo tab. Delete that folder too once you're sure you won't need it.

---

## For developers

- **Run from source:** clone the repo and double-click `Start Clean My PC.cmd` (or `Safety scan only.cmd`).
- **Build the download ZIP:** `powershell -ExecutionPolicy Bypass -File tools\build-release.ps1`. This creates `dist\CleanMyPC.zip` with the friendly layout (`Start Clean My PC`, `Safety scan only` and `HOW TO USE.txt` from `tools\release\`, and everything else in `App files - no need to open\`) and prints its SHA256 checksum. The ZIP contains exactly the files in this repo, and nothing is compiled.
- **Test without changing anything:** `.\CleanMyPC.ps1 -SelfTest` builds the window without showing it, and `-Snapshot file.png -SnapshotTab 0` renders it to an image.

## Contributing
The lists are plain data files in [`src/catalog/`](src/catalog), so adding a setting, app or folder needs no code. Please describe side effects honestly and test with **Preview** first.

---

<p align="center">
  <a href="https://www.komodoworks.com"><img src="assets/komodoworks-logo.png" width="40" alt="KomodoWorks"></a><br>
  <b>Developed by <a href="https://www.komodoworks.com">KomodoWorks.com</a></b><br>
  An independent technology studio in Dublin, Ireland: websites and apps, business systems, AI integration and data analytics.<br>
  Work directly with the person who scopes, builds and launches your project. &middot; <a href="https://komodoworks.com/en/contact">Get in touch</a>
</p>
