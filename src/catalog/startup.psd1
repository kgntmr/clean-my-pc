@{
    # What starts when someone signs in. Quietpane only ever switches an item off the way Task Manager
    # does - the program itself is untouched and still opens normally - and Undo switches it back on.
    #
    # Keep: never offered, whatever the user ticks. Security, and helpers that drivers need to work.
    # Notes: a plain-language line for common items, matched against the item's name and command.
    # First match wins. Nothing here is ever switched off automatically; the user always chooses.

    Keep = @(
        # Why: one sentence that reads well straight after the item's name.
        @{ Match = '(?i)SecurityHealth|Windows ?Defender|MSASCui'; Why = 'It is Windows Security''s icon by the clock, which shows at a glance whether your PC is protected.' }
        @{ Match = '(?i)RtkAud|Realtek|RtHDVCpl|RtHDVBg'; Why = 'Your sound driver uses it - the audio console and headset detection can stop working without it.' }
        @{ Match = '(?i)Waves ?MaxxAudio|MaxxAudio|Dolby|Nahimic|A-Volute|DTS ?Audio'; Why = 'Your sound driver uses it for speaker and headphone settings.' }
        @{ Match = '(?i)Synaptics|SynTP|ETDCtrl|ELAN ?Smart|ElanTouch'; Why = 'Your touchpad driver uses it for gestures and settings.' }
        @{ Match = '(?i)\bctfmon\b'; Why = 'Keyboard layouts and language switching need it.' }
        @{ Match = '(?i)Bluetooth|BTTray|btsendto'; Why = 'Bluetooth devices use it.' }
        @{ Match = '(?i)\bWacom|Pen ?Tablet'; Why = 'Your pen or tablet driver uses it.' }
    )

    Notes = @(
        @{ Match = '(?i)MicrosoftEdgeAutoLaunch|msedge\.exe.*--no-startup-window'; Note = 'Microsoft Edge "startup boost": loads Edge quietly at sign-in so it opens a moment faster later. Safe to switch off - Edge still works.' }
        @{ Match = '(?i)^OneDrive|\\OneDrive\.exe'; Note = 'OneDrive keeps your files in sync. Switched off, files only sync while you have OneDrive open.' }
        @{ Match = '(?i)Steam|EpicGamesLauncher|EADesktop|\bOrigin\b|Ubisoft ?Connect|UplayWeb|Battle\.net|GalaxyClient|RiotClient|Rockstar'; Note = 'A game launcher. Safe to switch off - it opens when you start a game.' }
        @{ Match = '(?i)Discord|Spotify|Teams|WhatsApp|Telegram|\bZoom\b|Slack|Skype|Signal'; Note = 'A chat or music app. Safe to switch off - you just won''t see messages until you open it.' }
        @{ Match = '(?i)uTorrent|utweb|BitTorrent|qBittorrent'; Note = 'A torrent app. Safe to switch off - it starts when you open it.' }
        @{ Match = '(?i)MSI ?Center|MSI_Center|Dragon ?Center|Armoury|Omen ?Gaming|Alienware ?Command|Legion|Lenovo ?Vantage|MyASUS|Dell ?Update|HP ?Support'; Note = 'Your laptop maker''s control app. Switching it off at sign-in is usually fine, but fan, keyboard-light or battery settings it manages may wait until you open it.' }
        @{ Match = '(?i)NVIDIA ?App|NvBackend|GeForce ?Experience'; Note = 'NVIDIA''s app. Safe to switch off - drivers keep working, and the overlay starts when you open the app.' }
        @{ Match = '(?i)Copilot|Cortana'; Note = 'Microsoft''s assistant. Safe to switch off.' }
        @{ Match = '(?i)Adobe|Creative ?Cloud|CCXProcess'; Note = 'Adobe''s background helper. Safe to switch off - Adobe apps start it themselves when needed.' }
        @{ Match = '(?i)Update|Updater|\bUpd\b'; Note = 'Keeps a program up to date. Safer to leave on - updates often fix security holes.' }
    )
}
