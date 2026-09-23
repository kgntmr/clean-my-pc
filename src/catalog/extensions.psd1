@{
    # What a browser add-on is allowed to do, in plain words.
    #
    # The names on the left are the browser's own, exactly as the add-on's manifest.json lists them.
    # Nothing here is a judgement about a particular add-on: an ad blocker and a password stealer ask
    # for the same permissions, and only you know which one you meant to install.
    #
    # Level orders the list and nothing else:
    #   Everything - it can read or change the pages you visit, or reach outside the browser
    #   Watching   - it can see where you go, what you have open, or who you are signed in as
    #   Ordinary   - worth knowing, but nothing follows you around

    Permissions = @(
        @{ Name = 'proxy';                 Level = 'Everything'; Plain = 'can send your browsing through another server' }
        @{ Name = 'debugger';              Level = 'Everything'; Plain = 'can drive the browser the way a developer tool does' }
        @{ Name = 'nativeMessaging';       Level = 'Everything'; Plain = 'can talk to a program installed on this PC' }
        @{ Name = 'declarativeNetRequest'; Level = 'Everything'; Plain = 'can block or change what your browser loads' }
        @{ Name = 'declarativeNetRequestWithHostAccess'; Level = 'Everything'; Plain = 'can block or change what your browser loads' }
        @{ Name = 'webRequest';            Level = 'Everything'; Plain = 'can watch every request your browser makes' }
        @{ Name = 'webRequestBlocking';    Level = 'Everything'; Plain = 'can stop or redirect requests your browser makes' }
        @{ Name = 'history';               Level = 'Watching';   Plain = 'can read your browsing history' }
        @{ Name = 'cookies';               Level = 'Watching';   Plain = 'can read the cookies that keep you signed in' }
        @{ Name = 'tabs';                  Level = 'Watching';   Plain = 'can see every page you have open' }
        @{ Name = 'webNavigation';         Level = 'Watching';   Plain = 'can see every page you move to' }
        @{ Name = 'topSites';              Level = 'Watching';   Plain = 'can see the sites you visit most' }
        @{ Name = 'management';            Level = 'Watching';   Plain = 'can switch your other add-ons on and off' }
        @{ Name = 'clipboardRead';         Level = 'Watching';   Plain = 'can read what you copy' }
        @{ Name = 'geolocation';           Level = 'Watching';   Plain = 'can ask where you are' }
        @{ Name = 'desktopCapture';        Level = 'Watching';   Plain = 'can record your screen once you allow it' }
        @{ Name = 'tabCapture';            Level = 'Watching';   Plain = 'can record what is in a tab' }
        @{ Name = 'pageCapture';           Level = 'Watching';   Plain = 'can save a whole page as it looks to you' }
        @{ Name = 'privacy';               Level = 'Watching';   Plain = 'can change your privacy settings in the browser' }
        @{ Name = 'identity';              Level = 'Watching';   Plain = 'can sign in as you with your browser account' }
        @{ Name = 'identity.email';        Level = 'Watching';   Plain = 'can read the email address you signed in with' }
        @{ Name = 'bookmarks';             Level = 'Ordinary';   Plain = 'can read and change your bookmarks' }
        @{ Name = 'downloads';             Level = 'Ordinary';   Plain = 'can see your downloads and start new ones' }
        @{ Name = 'browsingData';          Level = 'Ordinary';   Plain = 'can clear your browsing data' }
        @{ Name = 'contentSettings';       Level = 'Ordinary';   Plain = 'can change what websites are allowed to do' }
        @{ Name = 'search';                Level = 'Ordinary';   Plain = 'can search on your behalf' }
        @{ Name = 'notifications';         Level = 'Ordinary';   Plain = 'can show you notifications' }
        @{ Name = 'activeTab';             Level = 'Ordinary';   Plain = 'can read the page you are on, but only when you click it' }
    )

    # Permissions that say nothing a person needs to read: the add-on's own storage, timers, menus and
    # the browser's internal plumbing. Anything ending in "Private" belongs to the browser itself.
    Quiet = @(
        'storage', 'unlimitedStorage', 'alarms', 'offscreen', 'scripting', 'contextMenus', 'idle', 'power',
        'tts', 'ttsEngine', 'sidePanel', 'favicon', 'fontSettings', 'gcm', 'background', 'declarativeContent',
        'printing', 'printingMetrics', 'system.cpu', 'system.memory', 'system.display', 'system.storage',
        'system.network', 'processes', 'metricsPrivate', 'enterprise.hardwarePlatform', 'errorReporting',
        'unlimitedloadtimes', 'webstorePrivate', 'hubPrivate', 'fullscreen', 'windows', 'resourcesPrivate',
        'mediaInternalsPrivate', 'webrtcInternalsPrivate', 'webrtcLoggingPrivate', 'pdfViewerPrivate'
    )

    # The host patterns that mean "everywhere".
    Everywhere = @('<all_urls>', '*://*/*', 'http://*/*', 'https://*/*', 'http://*/', 'https://*/', '*://*/', 'file:///*')
}
