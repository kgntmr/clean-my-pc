# Privacy Policy: Clean My PC

**Last updated: 19 September 2026**

Clean My PC is free, open-source software developed by **KomodoWorks**, an independent technology studio in Dublin, Ireland ([komodoworks.com](https://www.komodoworks.com)).
Contact: **info@komodoworks.com**

## The short version

- **Clean My PC collects no personal data.** It has no accounts, analytics, telemetry, crash reporting, advertising, tracking, cookies or fingerprinting.
- **It makes no network connections.** It never "phones home", checks for updates in the background, downloads anything or uploads anything.
- **Everything it reads stays on your PC.** KomodoWorks never receives it and has no way to see it.
- **Nothing is sold or shared**, because nothing is collected.

You don't have to take our word for it. See [Verify it yourself](README.md#verify-it-yourself).

## What the app looks at on your computer, and why

The app runs only on your PC, only when you start it, and only does what you click.

| Feature | What it reads or changes | Where results are kept |
|---|---|---|
| **Scan** (read-only) | Startup entries, scheduled tasks, services, selected registry values, the hosts file, proxy and DNS settings, names and digital signatures of program files in user folders, browser **extension manifests** and **notification permission lists**, Microsoft Defender and firewall status, the running-process list, folder sizes | An HTML report saved on **your** Desktop |
| **Privacy, NVIDIA, Apps** (only when you click Apply) | The settings, services, tasks, apps and hosts-file entries you ticked | Restore points and logs in `%ProgramData%\CleanMyPC\restore\` on your PC. These hold the previous values, so Undo can put them back. |
| **Clean up space** (only when you click Apply) | The folders you ticked | Files are moved to **your Recycle Bin** |

**What the scan does not read:** your browsing history, passwords, cookies, emails, messages, documents or the contents of web pages.

**Scan reports can contain personal information**, for example your Windows username inside folder paths, or the names of programs and browser extensions you use. They exist only on your PC. **Review a report before you share it with anyone**, including us.

## Legal basis (GDPR)

All processing happens locally on your own device, under your control, for your own purposes, and none of it is transmitted to us. KomodoWorks therefore does **not** act as a data controller or processor for anything the app reads on your computer. We can't access, view, copy or delete data on your PC.

You can remove everything the app has stored at any time:
- **Scan reports:** delete `CleanMyPC-Report-*.html` from your Desktop.
- **Restore points and logs:** delete the folder `%ProgramData%\CleanMyPC`. Do this after you're sure you won't need Undo.
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
