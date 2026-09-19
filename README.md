<p align="center">
  <a href="https://www.komodoworks.com"><img src="assets/komodoworks-logo.png" width="96" alt="KomodoWorks emblem"></a>
</p>

<h1 align="center">Clean My PC</h1>

<p align="center">
  <b>Take your Windows PC back.</b><br>
  Scan for adware tricks, switch off telemetry, remove bloat and free up space. Everything happens on your PC, and nothing leaves it.<br><br>
  Developed by <a href="https://www.komodoworks.com"><b>KomodoWorks.com</b></a> &middot; Free &amp; open source (MIT) &middot; Windows 10 / 11
</p>

---

## Why this exists

Almost everything on a modern PC reports home. Windows sends diagnostic data, browsers send usage statistics, graphics drivers ship telemetry plugins, and "free" downloads bring adware that hides in scheduled tasks. Most people never agreed to any of it knowingly, and most clean-up tools either don't explain what they change or collect data of their own.

**Clean My PC works the other way round:**

- 🔒 **Collects nothing.** No accounts, analytics, telemetry, crash reports, ads, cookies or tracking.
- 🌐 **Connects to nothing.** The app makes no network requests. Don't take our word for it: [verify it yourself](#verify-it-yourself).
- 👀 **Shows you everything first.** Every item explains what it does and its side effects. **Preview** shows exactly what would change.
- ↩️ **Can be undone.** Every Apply creates a restore point, and files only ever go to your Recycle Bin.
- 📖 **Hides nothing.** Plain-text PowerShell you can read line by line. No `.exe`, no installer, no obfuscation.
- 🛡️ **Leaves your security alone.** Defender, SmartScreen, the firewall and Windows Update are never touched.

It was built from a real, hands-on clean-up of a gaming and development laptop. That clean-up found adware that re-installed itself from a scheduled task and traced it back to the cracked game that brought it in. Those [lessons learned](docs/LESSONS-LEARNED.md) are built into the tool.

---

## Quick start

1. Download: **Code → Download ZIP**, then extract it to a short path such as `C:\Tools\clean-my-pc`.
2. Double-click **`CleanMyPC.cmd`** and click **Yes** when Windows asks for administrator rights.
3. Go through the tabs from left to right:
   **Scan → Privacy & Telemetry → NVIDIA → Remove bloat apps → Clean up space**.
   On each tab: tick items → **Preview (no changes)** → **Apply selected**.
4. Restart the PC when you're done, and empty the Recycle Bin once you're happy.

Only want a health check? Double-click **`CleanMyPC-ScanOnly.cmd`**. It changes nothing and opens a report.

> Windows may warn about files downloaded from the internet. Every file here is plain text, so you can open any of them in Notepad first.

**Requirements:** Windows 10/11, Windows PowerShell 5.1 (built in) and an administrator account. Nothing else needs installing.

---

## What each tab does

### 1. Scan (read-only)
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

### 2. Privacy & Telemetry
32 settings across **Windows telemetry**, **Privacy**, **Ads, tips & suggestions**, **Background services** and **Browsers & other software** (Edge, Chrome, Office, Intel DTT, VS Code, .NET/PowerShell CLIs). Items already done show **[already applied]**.

### 3. NVIDIA
Blocks only NVIDIA's telemetry, analytics, survey and experiment servers, and sets NVIDIA's own opt-out flags. **NVIDIA App, driver updates and game optimisation keep working.** Deleting NVIDIA's telemetry plugin breaks NVIDIA App 11, and we [found that out the hard way](docs/LESSONS-LEARNED.md#nvidia-app-telemetry-cannot-be-deleted).

### 4. Remove bloat apps
Shows only known bloat that's actually installed. Store, Camera, Photos, Calculator, Notepad, Paint, Snipping Tool, Terminal, codecs and driver control panels are **never** offered.

### 5. Clean up space
Temp files, crash dumps, error-report archives, old NVIDIA installers, shader caches, browser caches and the Windows Update download cache, each with its size. Everything goes to the Recycle Bin.

### 6. Undo
Restore points for every Apply. Undo puts back services, tasks, registry values, environment variables, VS Code settings and hosts entries.

### 7. About
Privacy Policy, Terms of Use, License and Security policy, readable offline inside the app.

---

## Verify it yourself

Every claim above can be checked in a few minutes.

**1. Read it.** Three places hold everything: `CleanMyPC.ps1` (the window), `src/CleanMyPC.psm1` (the engine) and `src/catalog/*.psd1` (the lists of settings, apps and folders).

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
- **[Security Policy](SECURITY.md):** how to report a vulnerability, and how to tell a genuine copy from a fake. **We never distribute `.exe` files.**
- **[License](LICENSE):** MIT.

Clean My PC is independent and not affiliated with or endorsed by Microsoft, NVIDIA, Intel or Google. All trademarks belong to their owners.

---

## FAQ

**Chrome or Edge says "Managed by your organization".**
That appears whenever a browser policy is set, which is how the telemetry switches are locked. Nobody controls your browser. Undo removes the policies.

**Some items say [not on this PC].**
That service, task or program doesn't exist on your Windows version, or has already been removed.

**Does it work on several PCs?**
Yes. Each PC keeps its own restore points.

---

## Contributing
The lists are plain data files in [`src/catalog/`](src/catalog), so adding a setting, app or folder needs no code. Please describe side effects honestly and test with **Preview** first.

---

<p align="center">
  <a href="https://www.komodoworks.com"><img src="assets/komodoworks-logo.png" width="40" alt="KomodoWorks"></a><br>
  <b>Developed by <a href="https://www.komodoworks.com">KomodoWorks.com</a></b><br>
  An independent technology studio in Dublin, Ireland: websites and apps, business systems, AI integration and data analytics.<br>
  Work directly with the person who scopes, builds and launches your project. &middot; <a href="https://komodoworks.com/en/contact">Get in touch</a>
</p>
