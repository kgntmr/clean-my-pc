# Built-in / pre-installed apps offered in the "Remove bloat apps" tab.
# Only apps that are actually installed are shown. Anything matching the protected list in the
# module (Store, Camera, Photos, Calculator, Notepad, Paint, Snipping Tool, Terminal, codecs,
# runtimes, driver control panels...) is never offered, even if added here by mistake.
#
# Name        Appx package name (wildcards allowed)
# Recommended $true = ticked by "Select recommended"
# Removed apps can be reinstalled from the Microsoft Store.

@{
    Items = @(
        @{ Name = 'Microsoft.BingNews';                  Title = 'Microsoft News';                     Recommended = $true;  Description = 'News feed app.' }
        @{ Name = 'Microsoft.BingWeather';               Title = 'Weather';                            Recommended = $false; Description = 'Weather app. Keep it if you use it.' }
        @{ Name = 'Microsoft.BingSearch';                Title = 'Bing Search';                        Recommended = $true;  Description = 'Bing search integration app.' }
        @{ Name = 'Microsoft.GetHelp';                   Title = 'Get Help';                           Recommended = $true;  Description = 'Microsoft support chat app.' }
        @{ Name = 'Microsoft.Getstarted';                Title = 'Tips';                               Recommended = $true;  Description = 'Windows tips app.' }
        @{ Name = 'Microsoft.MicrosoftSolitaireCollection'; Title = 'Solitaire Collection';            Recommended = $true;  Description = 'Ad-supported card games.' }
        @{ Name = 'Microsoft.People';                    Title = 'People';                             Recommended = $true;  Description = 'Legacy contacts app.' }
        @{ Name = 'Microsoft.WindowsFeedbackHub';        Title = 'Feedback Hub';                       Recommended = $true;  Description = 'Sends feedback and diagnostics to Microsoft.' }
        @{ Name = 'Microsoft.549981C3F5F10';             Title = 'Cortana';                            Recommended = $true;  Description = 'Discontinued voice assistant.' }
        @{ Name = 'Microsoft.Copilot';                   Title = 'Copilot app';                        Recommended = $false; Description = 'Microsoft''s AI assistant. Keep it if you use it.' }
        @{ Name = 'Microsoft.MicrosoftOfficeHub';        Title = 'Microsoft 365 (Office) hub';         Recommended = $true;  Description = 'Launcher/ad for Microsoft 365 subscriptions. Does not remove installed Office apps.' }
        @{ Name = 'Microsoft.PowerAutomateDesktop';      Title = 'Power Automate';                     Recommended = $true;  Description = 'Automation tool most home users never open.' }
        @{ Name = 'Clipchamp.Clipchamp';                 Title = 'Clipchamp';                          Recommended = $true;  Description = 'Video editor (online account based).' }
        @{ Name = 'MicrosoftTeams';                      Title = 'Teams (old consumer chat)';          Recommended = $true;  Description = 'Legacy "Chat" Teams for home users.' }
        @{ Name = 'MSTeams';                             Title = 'Microsoft Teams';                    Recommended = $false; Description = 'Keep it if you use Teams for school or work.' }
        @{ Name = '7EE7776C.LinkedInforWindows';         Title = 'LinkedIn';                           Recommended = $true;  Description = 'Web wrapper for linkedin.com.' }
        @{ Name = 'Microsoft.WindowsMaps';               Title = 'Maps';                               Recommended = $true;  Description = 'Windows Maps app.' }
        @{ Name = 'Microsoft.ZuneVideo';                 Title = 'Films & TV';                         Recommended = $true;  Description = 'Legacy video store/player. Media Player and VLC are unaffected.' }
        @{ Name = 'Microsoft.MicrosoftJournal';          Title = 'Journal';                            Recommended = $true;  Description = 'Pen note-taking app.' }
        @{ Name = 'Microsoft.Windows.DevHome';           Title = 'Dev Home';                           Recommended = $true;  Description = 'Discontinued developer dashboard.' }
        @{ Name = 'Microsoft.Todos';                     Title = 'Microsoft To Do';                    Recommended = $false; Description = 'Keep it if you use To Do.' }
        @{ Name = 'Microsoft.OutlookForWindows';         Title = 'Outlook (new)';                      Recommended = $false; Description = 'Keep it if you use it for email.' }
        @{ Name = 'Microsoft.YourPhone';                 Title = 'Phone Link';                         Recommended = $false; Description = 'Keep it if you connect your phone to the PC.' }
        @{ Name = 'MicrosoftWindows.CrossDevice';        Title = 'Cross-Device experience host';       Recommended = $false; Description = 'Companion of Phone Link.' }
        @{ Name = 'MicrosoftWindows.Client.WebExperience'; Title = 'Widgets board';                    Recommended = $true;  Description = 'News/weather widgets panel (runs in the background).' }
        @{ Name = 'Microsoft.StartExperiencesApp';       Title = 'Start menu feed';                    Recommended = $true;  Description = 'Feeds promotions/news into Start (runs in the background).' }
        @{ Name = 'Microsoft.WidgetsPlatformRuntime';    Title = 'Widgets runtime';                    Recommended = $false; Description = 'Only useful if you keep Widgets. Remove it after removing the Widgets board.' }
        @{ Name = 'Microsoft.Edge.GameAssist';           Title = 'Edge Game Assist';                   Recommended = $true;  Description = 'In-game browser overlay.' }
        @{ Name = 'Microsoft.GamingApp';                 Title = 'Xbox app';                           Recommended = $false; Description = 'Needed for Game Pass / Microsoft Store PC games.' }
        @{ Name = 'Microsoft.XboxGamingOverlay';         Title = 'Xbox Game Bar';                      Recommended = $false; Description = 'Win+G overlay. After removing it, also tick "Turn off Game DVR" in the Privacy tab.' }
        @{ Name = 'Microsoft.XboxGameOverlay';           Title = 'Xbox Game Overlay';                  Recommended = $false; Description = 'Part of Game Bar.' }
        @{ Name = 'Microsoft.XboxSpeechToTextOverlay';   Title = 'Xbox speech-to-text overlay';        Recommended = $true;  Description = 'Party-chat captions overlay.' }
        @{ Name = 'Microsoft.Xbox.TCUI';                 Title = 'Xbox TCUI';                          Recommended = $false; Description = 'Some Microsoft Store games need it.' }
        @{ Name = 'Microsoft.XboxIdentityProvider';      Title = 'Xbox Identity Provider';             Recommended = $false; Description = 'Needed for Xbox sign-in in games like Minecraft or Forza.' }
        @{ Name = 'Microsoft.OneDriveSync';              Title = 'OneDrive (Store component)';         Recommended = $false; Description = 'Keep it if you use OneDrive. Make sure all files are synced before removing.' }
        @{ Name = 'King.com.CandyCrushSaga';             Title = 'Candy Crush Saga';                   Recommended = $true;  Description = 'Promoted game installed by Windows.' }
        @{ Name = 'King.com.CandyCrushSodaSaga';         Title = 'Candy Crush Soda Saga';              Recommended = $true;  Description = 'Promoted game installed by Windows.' }
        @{ Name = 'BytedancePte.Ltd.TikTok';             Title = 'TikTok';                             Recommended = $true;  Description = 'Promoted app installed by Windows.' }
        @{ Name = 'Facebook.Facebook';                   Title = 'Facebook';                           Recommended = $false; Description = 'Promoted app. Keep it if you use it.' }
        @{ Name = 'AmazonVideo.PrimeVideo';              Title = 'Prime Video';                        Recommended = $false; Description = 'Promoted app. Keep it if you use it.' }
        @{ Name = 'Disney.37853FC22B2CE';                Title = 'Disney+';                            Recommended = $false; Description = 'Promoted app. Keep it if you use it.' }
    )
}
