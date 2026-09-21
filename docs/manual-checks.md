# Checks a person has to do by hand

Most of Quietpane is covered by `tests\Run-QuietpaneTests.ps1`. A few things cannot be, and this is
the list. Nothing here uses real malware: every file below is a harmless industry test file that
antivirus products agree to detect so people can check their protection works.

**Why these are not automated:** they need a file to arrive from the internet, and Quietpane makes no
network requests at all. Automating them would mean the app downloading something, which would break
the one promise the whole product rests on. So a person opens a browser instead.

Run these after any release that touches the Safety scan.

## 1. EICAR, offline (also covered by `-Live`)

The automated suite already writes the EICAR string into a temp folder and asks Defender to scan it.
Run it as administrator:

    powershell -ExecutionPolicy Bypass -File tests\Run-QuietpaneTests.ps1 -Live

Expected: Defender detects it, Quietpane shows it as **Info**, source **Microsoft Defender**, family
**EICAR test file** - never as Critical, and never as a malware family.

## 2. AMTSO feature checks (browser, a few minutes)

AMTSO (the Anti-Malware Testing Standards Organization) hosts safe feature-check pages at
<https://www.amtso.org/check-desktop-solution/>. Work down the list in a browser, with Microsoft
Defender real-time protection on:

| AMTSO check | What should happen in Windows | Then in Quietpane |
|---|---|---|
| EICAR download over HTTP | Defender blocks the download | Run the check: either nothing to show, or an Info-level EICAR line |
| EICAR download over HTTPS | Defender blocks it too | Same |
| Compressed EICAR (`.zip`) | Defender blocks it | Same |
| Potentially Unwanted Application (PUA) test | Defender flags it as PUA | Shows as **Low**, category unwanted software, with a "leave it or remove it" choice |
| Phishing page test | SmartScreen warns in the browser | Nothing - Quietpane does not look at web pages, and should not claim to |
| Cloud protection test | Defender reacts within a few seconds | Whatever Defender recorded, named as Defender's finding |
| Drive-by download test | Defender blocks it | Same |

What to look for in Quietpane afterwards:

- Every threat name shown is Defender's, with **found by Microsoft Defender** on the card.
- Confidence is **Confirmed** for Defender detections, never for Quietpane's own checks.
- The doughnut's centre number equals the number of findings listed, and clicking a legend row filters
  the list to that severity.
- Nothing is removed, quarantined or deleted unless you click it.

If Defender does not react at all, check whether another antivirus has taken over. Quietpane says so
on the results panel when it happens; that message should appear rather than a clean bill of health.

## 3. The window itself

These need eyes, not assertions:

- **Health tab.** The four tiles change every couple of seconds. Compare the graphics temperature
  and video memory with Task Manager > Performance > GPU: they come from the same place and should
  match. Hover a temperature to see where it comes from.
- **Health pauses.** Switch to another tab, or minimise the window, and Quietpane's own CPU use in
  Task Manager should drop to nothing: it reads nothing until the Health tab is back on screen.
- **Undo is up to date straight away.** Apply something, then open the Undo tab at once: the new
  restore point is at the top, with the right number of changes. Nothing ever shows "0 change(s)".
- **Slowing down to cool off.** Under a long, heavy game on a laptop, the processor tile may say it
  is slowing down to cool off. If it appears while the PC is idle and cool, that is a bug.
- **Not shared.** On a PC with no dedicated graphics card or no thermal zone, the tiles say "not
  shared" or "temperature not shared" - never 0 degrees.
- **What's using it.** The programs under the processor and graphics tiles should match the top of
  Task Manager > Processes, sorted by CPU and by GPU. Quietpane lists itself as "Quietpane (this app)".
- **Battery and drive.** On a laptop, the Battery card's "holds N% of what it did when new" should
  match Windows' own report (`powercfg /batteryreport`). The Drive card should say what Windows says
  in Settings > System > Storage > Disks & volumes. Wear and temperature need Quietpane's usual
  administrator rights; without them the card just says "Healthy".
- **Came back.** Switch one of Quietpane's privacy settings back on yourself in Windows Settings,
  then open Quietpane: Home says one setting came back. "That was me" hides it for good; doing it
  again and choosing "Switch them off again" puts exactly that one setting right, with a restore point.
- **Startup items match Task Manager.** Apps tab > Starts when you sign in should list the same
  things as Task Manager > Startup apps, with the same on/off state. Switch one off in Quietpane and
  Task Manager shows it as Disabled straight away; Undo, and it shows Enabled again. Sign out and
  back in to confirm it really stays quiet.
- **Stop.** Start "Check this PC", press **Stop** after a few seconds. The progress line changes to
  "Stopping as soon as it is safe to...", then the summary says the check was stopped and that
  nothing was changed. No report is written to the Desktop.
- **Stop during a Defender scan.** Same again with "Check and ask Defender to scan". Defender may
  carry on in the background for a while - that is Defender's own scan and is safe to leave.
- **Progress.** While a check runs, the line under the heading shows the step, what it is looking at,
  how many things it has seen and how long it has been going.
- **The summary.** After a check: looked at, found by severity, dealt with, and one next step. Act on
  a finding and the "dealt with" line updates without re-running the check.
- **Quarantine round trip.** Quarantine something, confirm it disappears from its folder, then use
  "Put it back" and confirm it returns to the same place.
- **Preview, Apply, Undo.** On the Privacy tab: Preview changes nothing, Apply writes a restore point,
  and the Undo tab puts it back.
- **Dark mode.** Open a saved report with Windows set to dark mode; the chart and severity colours
  should still be readable.

## 4. What is deliberately not tested

- Live ransomware, remote access tools, stealers or loaders. Never, in any environment.
- Anything that asks Quietpane to prove a PC is clean. It cannot, and the product says so.
