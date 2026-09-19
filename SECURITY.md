# Security Policy

## Reporting a vulnerability
Please **don't** open a public GitHub issue for security problems.
Email **info@komodoworks.com** with the subject **"Security: Clean My PC"**, and include:
- the version (shown in the app footer and in scan reports)
- what you found, and the steps to reproduce it
- your Windows version

We aim to acknowledge reports within **5 working days**, agree a fix and a disclosure date with you, and credit you in the release notes if you'd like.

## Supported versions
Security fixes go into the latest release.

## Getting a genuine copy
- The only official source is **[github.com/kgntmr/clean-my-pc](https://github.com/kgntmr/clean-my-pc)**, published by KomodoWorks ([komodoworks.com](https://www.komodoworks.com)).
- Right now Clean My PC is **only** distributed as plain-text PowerShell scripts in `CleanMyPC.zip`. **There is no `.exe` version.** Treat any `.exe`, installer or "cracked/pro" version claiming to be Clean My PC as fake. If that ever changes, it will be announced here and in the [Code Signing Policy](README.md#code-signing-policy) first.
- Because everything is plain text, you can read every line before running it. See [Verify it yourself](README.md#verify-it-yourself).
- The ZIP is built with [`tools/build-release.ps1`](tools/build-release.ps1) and contains exactly the files in this repository. Nothing is compiled or added.

## Check that your download is genuine
Optional, and takes a minute. Each release lists the **SHA256 checksum** of `CleanMyPC.zip`, a fingerprint that changes if even one byte of the file is different.

1. Press **Start**, type **PowerShell**, and open **Windows PowerShell**.
2. Paste this line and press **Enter** (it assumes the file is in your Downloads folder):
   ```powershell
   Get-FileHash "$HOME\Downloads\CleanMyPC.zip"
   ```
3. Compare the **Hash** it shows with the SHA256 on the [release page](https://github.com/kgntmr/clean-my-pc/releases/latest). If they match, your copy is genuine. If they don't, delete it and download it again from the release page.
