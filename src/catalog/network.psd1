@{
    # Who is behind the addresses programs connect to, matched against the names Windows already has
    # in its own DNS cache. Nothing is looked up online, and this is only ever used to label a line.
    #
    # An empty result is normal: plenty of addresses have no name in the cache, and that is fine.

    Owners = @(
        @{ Match = '(?i)(^|\.)(microsoft|windowsupdate|windows|msn|live|office|office365|sharepoint|onedrive|skype|xbox|msftconnecttest|msedge|bing)\.(com|net|org)$'; Name = 'Microsoft' }
        @{ Match = '(?i)(^|\.)(azure|azureedge|azurewebsites|windows|trafficmanager)\.(net|com)$'; Name = 'Microsoft (cloud)' }
        @{ Match = '(?i)(^|\.)(google|googleapis|googleusercontent|gstatic|googlevideo|youtube|ytimg|doubleclick|googlesyndication)\.(com|net)$'; Name = 'Google' }
        @{ Match = '(?i)(^|\.)(cloudflare|cloudflare-dns|cdnjs)\.(com|net)$'; Name = 'Cloudflare (content delivery)' }
        @{ Match = '(?i)(^|\.)(amazonaws|cloudfront|amazon|media-amazon)\.(com|net)$'; Name = 'Amazon (cloud and shops)' }
        @{ Match = '(?i)(^|\.)(akamai|akamaiedge|akamaized|akadns|edgekey|edgesuite)\.(net|com)$'; Name = 'Akamai (content delivery)' }
        @{ Match = '(?i)(^|\.)(fastly|fastlylb|edgecastcdn|llnwd|cdn77)\.(net|com)$'; Name = 'A content delivery network' }
        @{ Match = '(?i)(^|\.)(apple|icloud|mzstatic|cdn-apple)\.(com|net)$'; Name = 'Apple' }
        @{ Match = '(?i)(^|\.)(facebook|fbcdn|instagram|whatsapp|meta)\.(com|net)$'; Name = 'Meta (Facebook, Instagram, WhatsApp)' }
        @{ Match = '(?i)(^|\.)(steampowered|steamcommunity|steamstatic|steamcontent|valvesoftware)\.(com|net)$'; Name = 'Steam (Valve)' }
        @{ Match = '(?i)(^|\.)(epicgames|unrealengine|helpshift)\.(com|net)$'; Name = 'Epic Games' }
        @{ Match = '(?i)(^|\.)(ea|origin|easports|eaassets-a)\.(com|net|akamaihd\.net)$'; Name = 'EA' }
        @{ Match = '(?i)(^|\.)(ubisoft|ubi|ubisoftconnect)\.(com|net)$'; Name = 'Ubisoft' }
        @{ Match = '(?i)(^|\.)(rockstargames|socialclub)\.(com|net)$'; Name = 'Rockstar Games' }
        @{ Match = '(?i)(^|\.)(riotgames|leagueoflegends)\.(com|net)$'; Name = 'Riot Games' }
        @{ Match = '(?i)(^|\.)(nvidia|nvidiagrid|geforce)\.(com|net)$'; Name = 'NVIDIA' }
        @{ Match = '(?i)(^|\.)(intel|intelcorp)\.(com|net)$'; Name = 'Intel' }
        @{ Match = '(?i)(^|\.)(msi|msicomputer|micro-star)\.(com|net|com\.tw)$'; Name = 'MSI' }
        @{ Match = '(?i)(^|\.)(discord|discordapp|discord-cdn)\.(com|net|gg)$'; Name = 'Discord' }
        @{ Match = '(?i)(^|\.)(spotify|scdn|spotifycdn)\.(com|co)$'; Name = 'Spotify' }
        @{ Match = '(?i)(^|\.)(netflix|nflxvideo|nflximg|nflxso)\.(com|net)$'; Name = 'Netflix' }
        @{ Match = '(?i)(^|\.)(twitch|ttvnw|jtvnw)\.(tv|net)$'; Name = 'Twitch' }
        @{ Match = '(?i)(^|\.)(github|githubusercontent|githubassets)\.(com|io)$'; Name = 'GitHub' }
        @{ Match = '(?i)(^|\.)(mozilla|firefox|cdn\.mozilla)\.(org|net|com)$'; Name = 'Mozilla (Firefox)' }
        @{ Match = '(?i)(^|\.)(brave|bravesoftware)\.(com|net)$'; Name = 'Brave' }
        @{ Match = '(?i)(^|\.)(openai|oaistatic|chatgpt)\.(com|net)$'; Name = 'OpenAI' }
        @{ Match = '(?i)(^|\.)(anthropic|claude)\.(com|ai)$'; Name = 'Anthropic' }
        @{ Match = '(?i)(^|\.)(adobe|adobesc|typekit|adobelogin)\.(com|net|io)$'; Name = 'Adobe' }
        @{ Match = '(?i)(^|\.)(dropbox|dropboxapi|dropboxstatic)\.(com|net)$'; Name = 'Dropbox' }
        @{ Match = '(?i)(^|\.)(realtek|logitech|logi|razer|corsair|steelseries)\.(com|net)$'; Name = 'A hardware maker' }
    )

    # Addresses that read as usage data, crash reports or ads. This is a hint from the name alone,
    # not proof of what is being sent - so the wording says "looks like", and nothing is blocked.
    Reporting = @(
        @{ Match = '(?i)(^|\.)(vortex|telemetry|telemetry-[\w-]+|watson|aria|mobile\.pipe\.aria)\.'; Note = 'looks like usage data' }
        @{ Match = '(?i)(^|\.)(events|eventhub|metrics|analytics|stats|beacon|insights)\.'; Note = 'looks like usage data' }
        @{ Match = '(?i)(^|\.)(crash|crashes|crashlytics|sentry|bugsnag|rollbar)\.'; Note = 'looks like crash reports' }
        @{ Match = '(?i)(^|\.)(logs|log-intake|http-intake|datadoghq|newrelic|logstash)\.'; Note = 'looks like logs being sent' }
        @{ Match = '(?i)(^|\.)(doubleclick|googlesyndication|googleadservices|adservice|adnxs|scorecardresearch|criteo|taboola|outbrain)\.'; Note = 'looks like ads or tracking' }
        @{ Match = '(?i)(^|\.)(gfe|ls\.telemetry|events\.gfe)\.nvidia\.com$'; Note = 'looks like usage data' }
    )
}
