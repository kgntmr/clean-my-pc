# Plain-language notes for threats that Microsoft Defender reports.
#
# Quietpane does NOT identify malware families by itself. Defender names the threat; this file only
# translates that name into a severity tier and a sentence a person can understand. The Defender name
# and its own classification are always shown next to ours.
#
#   Match        regex against Defender's threat name (e.g. "Ransom:Win32/WannaCrypt.A!ml")
#   Tier         Quietpane's impact tier: Critical, High, Medium, Low, Info
#   Category     what kind of thing it is, in plain words
#   What / Why   shown on the finding card
#
# Anything Defender reports that matches nothing here still appears: CategoryFallback handles the
# common name prefixes, and SeverityFallback uses Defender's own severity. Nothing is ever dropped.

@{
    Families = @(

        # ---------------------------------------------------------------- Critical: ransomware
        @{ Match = '(?i)WannaCry|WannaCrypt'; Family = 'WannaCry'; Tier = 'Critical'; Category = 'Ransomware'
           What = 'Ransomware that spreads by itself across a network and locks your files.'
           Why  = 'It encrypts documents and demands payment, and it can reach other PCs on your network without anyone clicking anything.' }
        @{ Match = '(?i)NotPetya|Petya|Nyetya'; Family = 'NotPetya'; Tier = 'Critical'; Category = 'Ransomware'
           What = 'Destructive ransomware that damages the disk so Windows will not start.'
           Why  = 'Even when a ransom is paid, files usually cannot be recovered. Treat this as data destruction, not a lock.' }
        @{ Match = '(?i)LockBit'; Family = 'LockBit'; Tier = 'Critical'; Category = 'Ransomware'
           What = 'One of the most widely used ransomware families.'
           Why  = 'It encrypts your files and its operators usually copy them first, then threaten to publish them.' }
        @{ Match = '(?i)BlackBasta|Black Basta'; Family = 'Black Basta'; Tier = 'Critical'; Category = 'Ransomware'
           What = 'Ransomware used in targeted attacks on organisations.'
           Why  = 'It encrypts files and steals them first, so the damage is both lost access and a leak.' }
        @{ Match = '(?i)BlackCat|ALPHV'; Family = 'ALPHV / BlackCat'; Tier = 'Critical'; Category = 'Ransomware'
           What = 'Ransomware that also steals data before encrypting it.'
           Why  = 'Victims are pressured twice: to unlock files, and to stop stolen data being published.' }
        @{ Match = '(?i)REvil|Sodinokibi'; Family = 'REvil / Sodinokibi'; Tier = 'Critical'; Category = 'Ransomware'
           What = 'Ransomware rented out to attackers as a service.'
           Why  = 'It encrypts files and has been used in large supply-chain attacks.' }
        @{ Match = '(?i)Ryuk'; Family = 'Ryuk'; Tier = 'Critical'; Category = 'Ransomware'
           What = 'Ransomware usually dropped after another infection has explored the network.'
           Why  = 'Its presence often means something else, such as TrickBot or Emotet, got in first.' }
        @{ Match = '(?i)\bConti\b'; Family = 'Conti'; Tier = 'Critical'; Category = 'Ransomware'
           What = 'Fast-encrypting ransomware used against businesses and hospitals.'
           Why  = 'It encrypts quickly and its operators steal files to force payment.' }
        @{ Match = '(?i)\bMaze\b'; Family = 'Maze'; Tier = 'Critical'; Category = 'Ransomware'
           What = 'The ransomware that popularised leaking stolen files.'
           Why  = 'Files are copied out before they are locked, so a backup alone does not fix the problem.' }
        @{ Match = '(?i)\bClop\b|\bCl0p\b'; Family = 'Clop'; Tier = 'Critical'; Category = 'Ransomware'
           What = 'Ransomware known for mass theft through file-transfer software.'
           Why  = 'It encrypts files and its operators publish what they stole when no payment is made.' }

        # ---------------------------------------------------------------- High: loaders, bankers, stealers, remote access
        @{ Match = '(?i)QakBot|Qbot|Quakbot'; Family = 'QakBot'; Tier = 'High'; Category = 'Banking trojan and loader'
           What = 'A banking trojan that also opens the door for ransomware.'
           Why  = 'It steals credentials and email, and hands access to other criminals.' }
        @{ Match = '(?i)Emotet|Geodo'; Family = 'Emotet'; Tier = 'High'; Category = 'Loader'
           What = 'A loader that delivers other malware and spreads through email.'
           Why  = 'It reads your mailbox to send convincing infected replies, and installs whatever it is paid to install.' }
        @{ Match = '(?i)TrickBot|Trickster'; Family = 'TrickBot'; Tier = 'High'; Category = 'Banking trojan and loader'
           What = 'A modular trojan that steals credentials and spreads inside a network.'
           Why  = 'It is a common first step before ransomware such as Ryuk or Conti.' }
        @{ Match = '(?i)IcedID|BokBot'; Family = 'IcedID'; Tier = 'High'; Category = 'Banking trojan and loader'
           What = 'A banking trojan that also loads other malware.'
           Why  = 'It steals what you type into banking sites and invites further infections.' }
        @{ Match = '(?i)Bumblebee'; Family = 'Bumblebee'; Tier = 'High'; Category = 'Loader'
           What = 'A loader used to get ransomware crews onto a PC.'
           Why  = 'On its own it does little; what it downloads next is the problem.' }
        @{ Match = '(?i)BazarLoader|BazaLoader|Bazar'; Family = 'BazarLoader'; Tier = 'High'; Category = 'Loader'
           What = 'A quiet loader linked to ransomware groups.'
           Why  = 'It gives attackers a foothold and hands it on to whoever pays for it.' }
        @{ Match = '(?i)AgentTesla|Agent Tesla'; Family = 'Agent Tesla'; Tier = 'High'; Category = 'Password stealer'
           What = 'A stealer that records what you type and takes your saved passwords.'
           Why  = 'Anything typed after the infection, including passwords and card numbers, may already be in someone else''s hands.' }
        @{ Match = '(?i)Remcos'; Family = 'Remcos'; Tier = 'High'; Category = 'Remote access tool'
           What = 'A remote-control tool sold openly and widely abused.'
           Why  = 'Someone else can see your screen, use your files and switch on your camera.' }
        @{ Match = '(?i)AsyncRAT'; Family = 'AsyncRAT'; Tier = 'High'; Category = 'Remote access tool'
           What = 'A remote-access trojan that gives an attacker live control of the PC.'
           Why  = 'It watches keystrokes and screens and can install more malware at any time.' }
        @{ Match = '(?i)RedLine'; Family = 'RedLine Stealer'; Tier = 'High'; Category = 'Password stealer'
           What = 'A stealer that empties browsers of passwords, cookies and card details.'
           Why  = 'Saved logins and session cookies are taken in seconds and sold on. Change important passwords from a clean device.' }

        # ---------------------------------------------------------------- Medium: older or narrower stealers and RATs
        @{ Match = '(?i)FormBook|XLoader'; Family = 'FormBook'; Tier = 'Medium'; Category = 'Password stealer'
           What = 'A cheap, common stealer sold to anyone who wants it.'
           Why  = 'It records typing and takes saved passwords from browsers.' }
        @{ Match = '(?i)NanoCore'; Family = 'NanoCore'; Tier = 'Medium'; Category = 'Remote access tool'
           What = 'A remote-control tool with plugins for spying.'
           Why  = 'It can watch the screen, record keys and use the webcam.' }
        @{ Match = '(?i)njRAT|Bladabindi'; Family = 'njRAT'; Tier = 'Medium'; Category = 'Remote access tool'
           What = 'A long-running remote-access trojan.'
           Why  = 'It hands control of the PC to someone else and steals credentials.' }
        @{ Match = '(?i)DarkComet|Fynloski'; Family = 'DarkComet'; Tier = 'Medium'; Category = 'Remote access tool'
           What = 'An old but still used remote-control trojan.'
           Why  = 'It allows spying through the screen, keyboard and camera.' }
        @{ Match = '(?i)SmokeLoader|Dofoil'; Family = 'SmokeLoader'; Tier = 'Medium'; Category = 'Loader'
           What = 'A small loader whose job is to fetch other malware.'
           Why  = 'Whatever it downloads next decides how bad this gets.' }
        @{ Match = '(?i)Ursnif|Gozi|ISFB|Dreambot'; Family = 'Ursnif / Gozi'; Tier = 'Medium'; Category = 'Banking trojan'
           What = 'A banking trojan that watches browser sessions.'
           Why  = 'It targets online banking and steals credentials.' }
        @{ Match = '(?i)AZORult'; Family = 'AZORult'; Tier = 'Medium'; Category = 'Password stealer'
           What = 'A stealer that collects passwords, wallets and files.'
           Why  = 'It takes saved credentials and cryptocurrency wallets, then often downloads more malware.' }
        @{ Match = '(?i)LokiBot|Loki\.'; Family = 'LokiBot'; Tier = 'Medium'; Category = 'Password stealer'
           What = 'A stealer aimed at saved passwords and crypto wallets.'
           Why  = 'Credentials stored in browsers, mail and FTP clients are copied out.' }
        @{ Match = '(?i)Raccoon'; Family = 'Raccoon Stealer'; Tier = 'Medium'; Category = 'Password stealer'
           What = 'A rented stealer for browser data and wallets.'
           Why  = 'Saved logins, cookies and card details are taken and sold.' }
        @{ Match = '(?i)\bVidar\b'; Family = 'Vidar'; Tier = 'Medium'; Category = 'Password stealer'
           What = 'A stealer often spread through cracked software and fake downloads.'
           Why  = 'It grabs passwords, cookies and documents, and can bring more malware with it.' }

        # ---------------------------------------------------------------- Low: unwanted and ad-serving software
        @{ Match = '(?i)CrossRider'; Family = 'CrossRider'; Tier = 'Low'; Category = 'Unwanted software'
           What = 'A platform for browser add-ons that inject adverts.'
           Why  = 'It changes what you see in your browser and follows you between sites.' }
        @{ Match = '(?i)CandyOpen|OpenCandy'; Family = 'CandyOpen'; Tier = 'Low'; Category = 'Unwanted software'
           What = 'A bundler that slips extra programs into ordinary installers.'
           Why  = 'It installs software you did not ask for and is paid per install.' }
        @{ Match = '(?i)BrowseFox'; Family = 'BrowseFox'; Tier = 'Low'; Category = 'Adware'
           What = 'Adware that injects adverts into web pages.'
           Why  = 'It adds adverts that are not part of the site and slows browsing.' }
        @{ Match = '(?i)Softonic'; Family = 'Softonic'; Tier = 'Low'; Category = 'Unwanted software'
           What = 'A download manager that bundles extra offers.'
           Why  = 'It pushes additional software and changes browser settings.' }
        @{ Match = '(?i)DownloadAssistant|Download Assistant'; Family = 'DownloadAssistant'; Tier = 'Low'; Category = 'Unwanted software'
           What = 'A download helper that adds offers to installs.'
           Why  = 'It exists to install extra programs alongside the one you wanted.' }
        @{ Match = '(?i)VOPackage'; Family = 'VOPackage'; Tier = 'Low'; Category = 'Unwanted software'
           What = 'A bundling installer that delivers additional software.'
           Why  = 'It brings programs you did not choose.' }
        @{ Match = '(?i)\bDowner\b'; Family = 'Downer'; Tier = 'Low'; Category = 'Unwanted software'
           What = 'A downloader for additional unwanted programs.'
           Why  = 'It fetches software in the background without asking.' }
        @{ Match = '(?i)Gamarue|Andromeda'; Family = 'Gamarue'; Tier = 'Low'; Category = 'Worm and loader'
           What = 'A worm that spreads on USB sticks and downloads other malware.'
           Why  = 'It can travel to other machines and install whatever it is told to. Check any USB sticks you use.' }
        @{ Match = '(?i)DealPly'; Family = 'DealPly'; Tier = 'Low'; Category = 'Adware'
           What = 'Adware that shows shopping offers while you browse.'
           Why  = 'It tracks browsing to choose adverts and is hard to remove by hand.' }
        @{ Match = '(?i)InstallCore'; Family = 'InstallCore'; Tier = 'Low'; Category = 'Unwanted software'
           What = 'A bundler that wraps ordinary programs in extra offers.'
           Why  = 'It installs additional software and changes browser settings.' }

        # ---------------------------------------------------------------- Info: test files, not malware
        @{ Match = '(?i)EICAR'; Family = 'EICAR test file'; Tier = 'Info'; Category = 'Antivirus test file'
           What = 'The standard harmless file used to check that antivirus software is awake.'
           Why  = 'This is not malware. Finding it means your antivirus is working. It is safe to delete.' }
        @{ Match = '(?i)AMTSO|TestFile|Test_File'; Family = 'Security test file'; Tier = 'Info'; Category = 'Antivirus test file'
           What = 'A harmless file used to test antivirus features.'
           Why  = 'Not malware. It exists so people can check their protection works.' }
    )

    # Used when the family is not in the list above. Based on the category Defender puts in front of the name.
    CategoryFallback = @(
        @{ Match = '^Ransom:'; Tier = 'Critical'; Category = 'Ransomware'
           What = 'Defender classified this as ransomware.'; Why = 'Ransomware encrypts your files and demands payment. Act on this now.' }
        @{ Match = '^(Backdoor|RemoteAccess):'; Tier = 'High'; Category = 'Remote access tool'
           What = 'Defender classified this as a backdoor.'; Why = 'It can give someone else control of this PC.' }
        @{ Match = '^(PWS|Spyware|PasswordStealer):'; Tier = 'High'; Category = 'Password stealer'
           What = 'Defender classified this as a password stealer.'; Why = 'Saved passwords and typed credentials may have been taken. Change important passwords from a clean device.' }
        @{ Match = '^(TrojanDownloader|TrojanDropper|Dropper|Downloader):'; Tier = 'High'; Category = 'Loader'
           What = 'Defender classified this as a downloader.'; Why = 'Its job is to install more malware.' }
        @{ Match = '^(Worm|Virus):'; Tier = 'High'; Category = 'Self-spreading malware'
           What = 'Defender classified this as self-spreading malware.'; Why = 'It can copy itself to other files, drives or PCs.' }
        @{ Match = '^(Exploit|VirTool|HackTool|Rootkit):'; Tier = 'High'; Category = 'Attack tool'
           What = 'Defender classified this as an attack or hacking tool.'; Why = 'These are used to break into or take control of systems.' }
        @{ Match = '^Trojan:'; Tier = 'High'; Category = 'Trojan'
           What = 'Defender classified this as a trojan.'; Why = 'It pretends to be something harmless while doing something else.' }
        @{ Match = '^(Behavior|BehavSys):'; Tier = 'Medium'; Category = 'Suspicious behaviour'
           What = 'Defender flagged the behaviour of a program rather than the file itself.'; Why = 'Something acted the way malware acts. It may be a false alarm, so check what it was.' }
        @{ Match = '^(PUA|PUP|UwS|SoftwareBundler|AdWare|BrowserModifier):'; Tier = 'Low'; Category = 'Unwanted software'
           What = 'Defender classified this as unwanted software.'; Why = 'Not malware exactly, but it advertises, bundles extras or changes settings without being asked.' }
    )

    # Last resort: Defender's own severity number (5 = severe, 4 = high, 2 = moderate, 1 = low).
    SeverityFallback = @{ '5' = 'Critical'; '4' = 'High'; '2' = 'Medium'; '1' = 'Low' }
}
