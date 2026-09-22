# Privacy & telemetry tweaks shown in the "Privacy & Telemetry" tab.
#
# Each item:
#   Id          unique id
#   Group       heading in the UI
#   Title       one line, plain language - no jargon
#   Short       a few plain words shown under it (keep any side effect here)
#   Description the full explanation, shown when you point at the item (be honest about side effects)
#   Recommended $true = ticked by "Select recommended"
#   Actions     list of changes. Types:
#                 Service  Name, StartType (Disabled | Manual | Automatic)
#                 Task     Path, Name (wildcards allowed) - tasks are DISABLED, never deleted
#                 Reg      Path, Name, Value, Kind (DWord default | String)
#                 Env      Name, Value (machine-wide environment variable)
#                 VSCodeTelemetry  (no parameters)
# Every action is recorded in a restore point and can be undone from the Undo tab.

@{
    Items = @(

        # ---------------------------------------------------------------- Windows telemetry
        @{
            Id          = 'tel.diagtrack'
            Group       = 'What Windows sends to Microsoft'
            Title       = 'Stop Windows sending diagnostic data'
            Short       = 'The main switch. Windows works the same without it.'
            Description = 'Connected User Experiences and Telemetry collects and uploads diagnostic data. On Windows Home this is the switch that actually stops the upload. Windows works normally without it.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Service'; Name = 'DiagTrack'; StartType = 'Disabled' }
                @{ Type = 'Service'; Name = 'dmwappushservice'; StartType = 'Disabled' }
            )
        }
        @{
            Id          = 'tel.policy'
            Group       = 'What Windows sends to Microsoft'
            Title       = 'Keep diagnostic data to the minimum'
            Short       = 'Also stops "give us feedback" notifications.'
            Description = 'Group-policy values for diagnostic data. Windows Home/Pro treat 0 as "Required only". Also limits diagnostic logs and crash dumps sent to Microsoft.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'DoNotShowFeedbackNotifications'; Value = 1 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'LimitDiagnosticLogCollection'; Value = 1 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'LimitDumpCollection'; Value = 1 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowDeviceNameInTelemetry'; Value = 0 }
            )
        }
        @{
            Id          = 'tel.tasks'
            Group       = 'What Windows sends to Microsoft'
            Title       = 'Switch off data-collection background tasks'
            Short       = 'Switched off, never deleted.'
            Description = 'Compatibility appraiser, customer experience program, device census, feature-usage reporting, feedback, sustainability telemetry and similar background tasks. Tasks are disabled (not deleted) so they can be re-enabled.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Application Experience\'; Name = 'Microsoft Compatibility Appraiser*' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Application Experience\'; Name = 'MareBackup' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Application Experience\'; Name = 'ProgramDataUpdater' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = '*' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Autochk\'; Name = 'Proxy' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Device Information\'; Name = '*' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\DiskFootprint\'; Name = 'Diagnostics' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Feedback\Siuf\'; Name = '*' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Flighting\FeatureConfig\'; Name = 'UsageData*' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Flighting\FeatureConfig\'; Name = 'GovernedFeatureUsageProcessing' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Windows Error Reporting\'; Name = 'QueueReporting' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Sustainability\'; Name = '*' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\PerformanceTrace\'; Name = '*' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Power Efficiency Diagnostics\'; Name = 'AnalyzeSystem' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\ConsentUX\UnifiedConsent\'; Name = 'UnifiedConsentSyncTask' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Diagnosis\'; Name = 'UnexpectedCodepath' }
                @{ Type = 'Task'; Path = '\Microsoft\Windows\Maps\'; Name = 'MapsToastTask' }
            )
        }
        @{
            Id          = 'tel.wer'
            Group       = 'What Windows sends to Microsoft'
            Title       = 'Stop sending crash reports to Microsoft'
            Short       = 'Programs behave the same; the reports just stay here.'
            Description = 'Stops crash reports and memory dumps being sent to Microsoft. Programs still crash the same way - the report just is not uploaded.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Service'; Name = 'WerSvc'; StartType = 'Disabled' }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled'; Value = 1 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name = 'DontSendAdditionalData'; Value = 1 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled'; Value = 1 }
            )
        }
        @{
            Id          = 'tel.insights'
            Group       = 'What Windows sends to Microsoft'
            Title       = 'Turn off Windows 11 usage and health reporting'
            Short       = 'Skipped if your Windows doesn''t have it.'
            Description = 'Newer Windows 11 services that gather usage/health data and show feedback toasts. Skipped automatically if your Windows version does not have them.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Service'; Name = 'wuqisvc'; StartType = 'Disabled' }
                @{ Type = 'Service'; Name = 'whesvc'; StartType = 'Disabled' }
            )
        }
        @{
            Id          = 'tel.ceip'
            Group       = 'What Windows sends to Microsoft'
            Title       = 'Turn off older Windows data collectors'
            Short       = 'Leftovers from earlier versions of Windows.'
            Description = 'Legacy CEIP, Application Impact Telemetry and the Steps Recorder data collector.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows'; Name = 'CEIPEnable'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'AITEnable'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'DisableUAR'; Value = 1 }
            )
        }
        @{
            Id          = 'tel.handwriting'
            Group       = 'What Windows sends to Microsoft'
            Title       = 'Stop sharing handwriting samples'
            Short       = 'Your pen writing stays on this PC.'
            Description = 'Pen/ink samples are no longer sent to Microsoft to "improve recognition".'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC'; Name = 'PreventHandwritingDataSharing'; Value = 1 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports'; Name = 'PreventHandwritingErrorReports'; Value = 1 }
            )
        }

        # ---------------------------------------------------------------- Privacy
        @{
            Id          = 'priv.adid'
            Group       = 'Privacy'
            Title       = 'Turn off the advertising ID'
            Short       = 'Apps can''t follow you around for ads.'
            Description = 'Apps can no longer use a per-user ID to personalise ads across apps.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy'; Value = 1 }
            )
        }
        @{
            Id          = 'priv.tailored'
            Group       = 'Privacy'
            Title       = 'Turn off tips and ads based on your data'
            Short       = 'Microsoft stops personalising what it shows you.'
            Description = 'Microsoft stops using your diagnostic data to personalise tips, ads and recommendations.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableTailoredExperiencesWithDiagnosticData'; Value = 1 }
            )
        }
        @{
            Id          = 'priv.activity'
            Group       = 'Privacy'
            Title       = 'Turn off activity history'
            Short       = 'Windows stops recording what you open.'
            Description = 'Windows stops recording and uploading which apps, files and websites you use.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed'; Value = 0 }
            )
        }
        @{
            Id          = 'priv.feedback'
            Group       = 'Privacy'
            Title       = 'Never ask for feedback'
            Short       = 'No more survey pop-ups.'
            Description = 'No more "How likely are you to recommend Windows..." pop-ups.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Siuf\Rules'; Name = 'NumberOfSIUFInPeriod'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Siuf\Rules'; Name = 'PeriodInNanoSeconds'; Value = 0 }
            )
        }
        @{
            Id          = 'priv.typing'
            Group       = 'Privacy'
            Title       = 'Turn off typing personalisation'
            Short       = 'Side effect: word suggestions learn less from you.'
            Description = 'Windows stops collecting what you type and write to build a personal dictionary. Side effect: word suggestions learn less from you.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitTextCollection'; Value = 1 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitInkCollection'; Value = 1 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore'; Name = 'HarvestContacts'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Personalization\Settings'; Name = 'AcceptedPrivacyPolicy'; Value = 0 }
            )
        }
        @{
            Id          = 'priv.speech'
            Group       = 'Privacy'
            Title       = 'Turn off online speech recognition'
            Short       = 'Side effect: voice typing (Win+H) stops working.'
            Description = 'Your voice is no longer sent to Microsoft''s cloud. Side effect: cloud voice typing (Win+H) stops working.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'; Name = 'HasAccepted'; Value = 0 }
            )
        }
        @{
            Id          = 'priv.crossdevice'
            Group       = 'Privacy'
            Title       = 'Stop syncing your clipboard and apps across devices'
            Short       = 'Side effect: Phone Link''s "continue on PC" stops.'
            Description = 'Stops clipboard and app activity syncing between your devices. Side effect: Phone Link "continue on PC" features stop.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'AllowCrossDeviceClipboard'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'; Name = 'IsResumeAllowed'; Value = 0 }
            )
        }
        @{
            Id          = 'priv.delivery'
            Group       = 'Privacy'
            Title       = 'Stop sharing Windows updates with other PCs'
            Short       = 'Updates still download normally.'
            Description = 'Delivery Optimization peer-to-peer sharing is turned off. Updates still download normally from Microsoft. Saves upload bandwidth and mobile data.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode'; Value = 0 }
            )
        }
        @{
            Id          = 'priv.location'
            Group       = 'Privacy'
            Title       = 'Turn off location for all apps'
            Short       = 'Side effect: weather, maps and Find my device may stop.'
            Description = 'Side effects: weather, maps, "Find my device" and automatic time zone may stop working. Leave unticked if you use them.'
            Recommended = $false
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'; Name = 'Value'; Value = 'Deny'; Kind = 'String' }
            )
        }

        # ---------------------------------------------------------------- Ads, tips & suggestions
        @{
            Id          = 'ads.silentinstall'
            Group       = 'Ads, tips & suggestions'
            Title       = 'Stop Windows installing promoted apps'
            Short       = 'Like games you never asked for turning up in Start.'
            Description = 'This is how games and apps you never asked for (Candy Crush, TikTok and similar) appear in the Start menu.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'ContentDeliveryAllowed'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'OemPreInstalledAppsEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEverEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'FeatureManagementEnabled'; Value = 0 }
            )
        }
        @{
            Id          = 'ads.tips'
            Group       = 'Ads, tips & suggestions'
            Title       = 'Turn off tips and "finish setting up" nags'
            Short       = 'Big updates can bring these back.'
            Description = 'Also disables the SoftLanding tips tasks. Windows sometimes recreates those tasks after big updates - just run this again.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SoftLandingEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-310093Enabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338388Enabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338389Enabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353694Enabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353696Enabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353698Enabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Name = 'ScoobeSystemSettingEnabled'; Value = 0 }
                @{ Type = 'Task'; Path = '\SoftLanding\*'; Name = '*' }
            )
        }
        @{
            Id          = 'ads.lockscreen'
            Group       = 'Ads, tips & suggestions'
            Title       = 'Turn off ads on the lock screen'
            Short       = 'Your lock-screen picture stays.'
            Description = 'Your lock-screen picture stays; the promotional text on top of it goes.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'RotatingLockScreenOverlayEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338387Enabled'; Value = 0 }
            )
        }
        @{
            Id          = 'ads.start'
            Group       = 'Ads, tips & suggestions'
            Title       = 'Turn off Start menu recommendations'
            Short       = 'No promoted apps or account nags in Start.'
            Description = 'Removes promoted apps/tips from the Recommended area and Microsoft-account nags in Start.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_IrisRecommendations'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_AccountNotifications'; Value = 0 }
            )
        }
        @{
            Id          = 'ads.search'
            Group       = 'Ads, tips & suggestions'
            Title       = 'Turn off web results in Start search'
            Short       = 'Search looks at your PC only.'
            Description = 'Start search only searches your PC; no daily trivia pictures in the search box.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name = 'IsDynamicSearchBoxEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BingSearchEnabled'; Value = 0 }
            )
        }
        @{
            Id          = 'ads.recent'
            Group       = 'Ads, tips & suggestions'
            Title       = 'Stop showing recently opened files'
            Short       = 'Side effect: they vanish from Start and File Explorer.'
            Description = 'Side effect: recent files disappear from Start, jump lists and File Explorer Quick Access. Leave unticked if you use those.'
            Recommended = $false
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_TrackDocs'; Value = 0 }
            )
        }

        # ---------------------------------------------------------------- Background services
        @{
            Id          = 'svc.maps'
            Group       = 'Background services'
            Title       = 'Turn off offline map downloads'
            Short       = 'Only needed for offline maps.'
            Description = 'Only needed for offline maps in the Windows Maps app.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Service'; Name = 'MapsBroker'; StartType = 'Disabled' }
            )
        }
        @{
            Id          = 'svc.spooler'
            Group       = 'Background services'
            Title       = 'Turn off printing'
            Short       = 'Only if you never print - not even to PDF.'
            Description = 'Only if you never print. Side effect: printing and "Microsoft Print to PDF" stop working (browsers can still "Save as PDF").'
            Recommended = $false
            Actions     = @(
                @{ Type = 'Service'; Name = 'Spooler'; StartType = 'Disabled' }
            )
        }
        @{
            Id          = 'svc.gamedvr'
            Group       = 'Background services'
            Title       = 'Turn off Game Bar recording'
            Short       = 'Also stops Game Bar pop-ups after removing Xbox apps.'
            Description = 'Stops background game recording hooks. Also fixes "You''ll need a new app to open this ms-gamingoverlay link" pop-ups after removing the Xbox apps.'
            Recommended = $false
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled'; Value = 0 }
            )
        }
        @{
            Id          = 'svc.xbox'
            Group       = 'Background services'
            Title       = 'Turn off Xbox services'
            Short       = 'Only if you don''t play Xbox or Game Pass games.'
            Description = 'Only if you do NOT play Xbox / Game Pass / Microsoft Store games (for example Minecraft, Forza). Steam, EA and other launchers are not affected.'
            Recommended = $false
            Actions     = @(
                @{ Type = 'Service'; Name = 'XblAuthManager'; StartType = 'Disabled' }
                @{ Type = 'Service'; Name = 'XblGameSave'; StartType = 'Disabled' }
                @{ Type = 'Service'; Name = 'XboxNetApiSvc'; StartType = 'Disabled' }
                @{ Type = 'Task'; Path = '\Microsoft\XblGameSave\'; Name = '*' }
            )
        }

        # ---------------------------------------------------------------- Browsers & other software
        @{
            Id          = 'app.edge'
            Group       = 'Browsers & other software'
            Title       = 'Microsoft Edge: stop data sharing and shopping pop-ups'
            Short       = 'Edge may then say "Managed by your organization" - that''s fine.'
            Description = 'Applies to Edge (and is harmless if you never open it). Edge may show "Managed by your organization" - that only means a policy is set.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'DiagnosticData'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'PersonalizationReportingEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'UserFeedbackAllowed'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'EdgeShoppingAssistantEnabled'; Value = 0 }
            )
        }
        @{
            Id          = 'app.chrome'
            Group       = 'Browsers & other software'
            Title       = 'Google Chrome: stop usage and crash reports'
            Short       = 'Chrome may then say "Managed by your organization" - that''s fine.'
            Description = 'Locked with policies so updates cannot switch them back on. Safe Browsing (security) stays on. Chrome will show "Managed by your organization" - harmless, it only means a policy is set.'
            Recommended = $false
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'MetricsReportingEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'ChromeCleanupEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'ChromeCleanupReportingEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'UrlKeyedAnonymizedDataCollectionEnabled'; Value = 0 }
                @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\Policies\Google\Chrome'; Name = 'UserFeedbackAllowed'; Value = 0 }
            )
        }
        @{
            Id          = 'app.office'
            Group       = 'Browsers & other software'
            Title       = 'Microsoft Office: stop optional data sharing'
            Short       = 'Harmless if Office isn''t installed.'
            Description = 'Harmless if Office is not installed.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Policies\Microsoft\Office\Common\ClientTelemetry'; Name = 'DisableTelemetry'; Value = 1 }
                @{ Type = 'Reg'; Path = 'HKCU:\Software\Policies\Microsoft\Office\Common\ClientTelemetry'; Name = 'SendTelemetry'; Value = 3 }
            )
        }
        @{
            Id          = 'app.intel'
            Group       = 'Browsers & other software'
            Title       = 'Intel: turn off its reporting service'
            Short       = 'Graphics and cooling are untouched.'
            Description = 'Only the telemetry service (dptftcs). The thermal/power driver itself is untouched. Skipped if not present.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Service'; Name = 'dptftcs'; StartType = 'Disabled' }
            )
        }
        @{
            Id          = 'app.vscode'
            Group       = 'Browsers & other software'
            Title       = 'Visual Studio Code: stop data sharing'
            Short       = 'Your settings file is backed up first.'
            Description = 'Adds "telemetry.telemetryLevel": "off" to your VS Code user settings (a backup of the file is kept). Skipped if VS Code is not installed.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'VSCodeTelemetry' }
            )
        }
        @{
            Id          = 'app.devcli'
            Group       = 'Browsers & other software'
            Title       = 'Developer tools: stop .NET and PowerShell data sharing'
            Short       = 'Harmless if you don''t use them.'
            Description = 'Sets the official opt-out environment variables. Harmless if you do not use these tools.'
            Recommended = $true
            Actions     = @(
                @{ Type = 'Env'; Name = 'DOTNET_CLI_TELEMETRY_OPTOUT'; Value = '1' }
                @{ Type = 'Env'; Name = 'POWERSHELL_TELEMETRY_OPTOUT'; Value = '1' }
            )
        }
    )
}
