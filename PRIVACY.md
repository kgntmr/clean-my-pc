# Privacy Policy: Quietpane

**Last updated: 21 September 2026**

Quietpane is free, open-source software developed by **KomodoWorks**, an independent technology studio in Dublin, Ireland ([komodoworks.com](https://www.komodoworks.com)).
Contact: **info@komodoworks.com**

## The short version

- **Quietpane collects no personal data.** It has no accounts, analytics, telemetry, crash reporting, advertising, tracking, cookies or fingerprinting.
- **It makes no network connections.** It never "phones home", checks for updates in the background, downloads anything or uploads anything.
- **Everything it reads stays on your PC.** KomodoWorks never receives it and has no way to see it.
- **Nothing is sold or shared**, because nothing is collected.

You don't have to take our word for it. See [Verify it yourself](README.md#verify-it-yourself).

## What the app looks at on your computer, and why

The app runs only on your PC, only when you start it, and only does what you click.

| Feature | What it reads or changes | Where results are kept |
|---|---|---|
| **Scan** (read-only) | Startup entries, scheduled tasks, services, selected registry values, the hosts file, proxy and DNS settings, names and digital signatures of program files in user folders, browser **extension manifests** and **notification permission lists**, Microsoft Defender and firewall status, the running-process list, folder sizes | An HTML report saved on **your** Desktop |
| **Microsoft Defender detections** (part of the scan) | Defender's own list of what it has found on this PC: threat names, file paths, dates and status, read through Windows' built-in Defender commands. Quietpane also works out the SHA256 of a detected file so you can look it up yourself. **Nothing is sent to Microsoft by Quietpane, and nothing is sent to us.** | Shown on screen and in the report on your Desktop |
| **Acting on a threat** | Asks Defender to remove what Defender found, quarantines a file, moves it to the Recycle Bin, deletes it when you choose that, or records that you left it alone | Quarantined files live in `%ProgramData%\Quietpane\quarantine\`, locked to administrators, with a small `meta.json` holding the original path, size, times and SHA256 so they can be put back. A line per action goes to `%ProgramData%\Quietpane\audit.log`, and allowed items to `allowed.json`. Leaving something alone is Quietpane's own note: it never creates a Defender exclusion. |
| **Telemetry tab** | Your PC's maker and graphics chip, the list of installed programs, services and scheduled tasks, to recognise brand software | Shown on screen only |
| **Privacy, Telemetry, Apps** (only when you click Apply) | The settings, services, tasks, apps and hosts-file entries you ticked | Restore points and logs in `%ProgramData%\Quietpane\restore\` on your PC. These hold the previous values, so Undo can put them back. |
| **Clean up space** (only when you click Apply) | The folders you ticked | Files are moved to **your Recycle Bin** |
| **Home screen** | Free space on your system drive. How busy the processor, graphics card and memory are, and how much video memory is in use, from Windows performance counters. Temperatures from Windows' thermal sensor and from your graphics driver, asked through a short C# block that's compiled on your PC from the readable source in `src/Quietpane.psm1`. | Shown on screen, refreshed every 2 seconds while Home is open and paused otherwise. **Live readings are never saved.** Totals of what the app has freed are kept in `%ProgramData%\Quietpane\totals.json` (two numbers, a count of runs and the date of the last one). Nothing else is recorded, and none of it leaves your PC. |

**What the scan does not read:** your browsing history, passwords, cookies, emails, messages, documents or the contents of web pages.

**Scan reports can contain personal information**, for example your Windows username inside folder paths, or the names of programs and browser extensions you use. They exist only on your PC. **Review a report before you share it with anyone**, including us.

## Legal basis (GDPR)

All processing happens locally on your own device, under your control, for your own purposes, and none of it is transmitted to us. KomodoWorks therefore does **not** act as a data controller or processor for anything the app reads on your computer. We can't access, view, copy or delete data on your PC.

You can remove everything the app has stored at any time:
- **Scan reports:** delete `Quietpane-Report-*.html` from your Desktop.
- **Restore points, logs, the totals file and the audit log:** delete the folder `%ProgramData%\Quietpane`, and `%ProgramData%\CleanMyPC` if you used the app under its former name. Do this after you're sure you won't need Undo.
- **The app itself:** delete the folder you extracted it to. There is no installer and nothing else to remove.

## When you leave the app

- **Links.** If you click "KomodoWorks.com" or an email link, your own browser or email program opens it. That is a normal website visit or email, covered by the [KomodoWorks website privacy policy](https://komodoworks.com/en/privacy). The app adds **no tracking parameters** to these links.
- **Downloading the app from GitHub** is subject to the [GitHub Privacy Statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement). We receive no personal information about who downloads it.
- **If you email us** (a question, a bug report), we use your email address and message only to reply. We keep them only as long as needed, as described in the website privacy policy. Please don't send scan reports unless we ask, and remove anything personal first.

## Your rights

For any personal data you send us by email, you have the rights set out in the GDPR: access, rectification, erasure, restriction, objection and portability. Contact **info@komodoworks.com**. You can also complain to the **Irish Data Protection Commission** ([dataprotection.ie](https://www.dataprotection.ie)) or to the data protection authority in your own country.

## Children

The app collects no data from anyone, including children.

## Changes to this policy

If this policy changes, the date at the top changes, and the full history is visible in the GitHub repository. A future version will **not** start collecting data quietly. If that ever changed, it would be stated clearly at the top of this document and in the release notes before the release.
