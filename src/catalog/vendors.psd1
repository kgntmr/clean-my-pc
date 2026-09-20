# Brand and hardware software: the extras that laptop makers and chip makers put on a PC.
#
# Rules for this file (please keep them if you send a pull request):
#   * Only name a service, scheduled task or registry value that really exists. Quietpane checks
#     before it shows or changes anything, so a wrong name simply never appears - but it is still wrong.
#   * A vendor section only appears when the PC matches Detect AND at least one of its items is found.
#   * Never list a driver, a driver service or a control panel people rely on. Use NeverTouch below.
#   * Junk = ordinary programs a person can uninstall and reinstall. Quietpane always asks first,
#     one by one, and says plainly that an uninstall cannot be undone.
#
# Item action types are the same ones the privacy catalog uses: Service, Task, Reg - plus Hosts.

@{
    # Never switched off, never uninstalled, whatever else a catalog entry says.
    NeverTouch = @(
        'nvlddmkm', 'nvvad*', 'NVDisplay.ContainerLocalSystem', 'amdkmdap', 'AMD External Events Utility',
        'igfxCUIService*', 'IntelAudioService', 'Intel(R) Platform License Manager Service',
        'RtkAudUService*', 'NahimicService', 'A-Volute*', 'AudioEndpointBuilder', 'Audiosrv',
        'MSI Foundation Service', 'ibtsiva', 'BthAvctpSvc', 'WlanSvc'
    )

    Vendors = @(

        # ------------------------------------------------------------------ NVIDIA
        @{
            Id     = 'nvidia'
            Name   = 'NVIDIA'
            Kind   = 'Graphics'
            Detect = @{ Gpu = 'NVIDIA'; Paths = @('%ProgramFiles%\NVIDIA Corporation') }
            Note   = 'NVIDIA App, driver updates and game optimisation keep working. Deleting NVIDIA''s telemetry plugin breaks the app, so Quietpane blocks its servers instead.'
            Items  = @(
                @{
                    Id          = 'nvidia.hosts'
                    Title       = 'Stop NVIDIA sending usage data and surveys'
                    Description = 'Blocks only NVIDIA''s telemetry, analytics, survey and experiment servers. Driver updates, your account and game optimisation are untouched.'
                    Recommended = $true
                    Actions     = @(
                        @{
                            Type  = 'Hosts'
                            Tag   = 'Quietpane-NVIDIA'
                            Hosts = @(
                                'events.telemetry.data.nvidia.com'
                                'feedbacks.telemetry.data.nvidia.com'
                                'telemetry.gfe.nvidia.com'
                                'events.gfe.nvidia.com'
                                'prod.otel.kaizen.nvidia.com'
                                'gx-surveys.nvidia.com'
                                'gx-target-experiments-frontend-api.gx.nvidia.com'
                                'gx-target-survey-frontend-api.gx.nvidia.com'
                            )
                        }
                    )
                }
                @{
                    Id          = 'nvidia.flags'
                    Title       = 'Turn on NVIDIA''s own "do not collect" settings'
                    Description = 'Sets the opt-out values NVIDIA provides in its own software.'
                    Recommended = $true
                    Actions     = @(
                        @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client'; Name = 'OptInOrOutPreference'; Value = 0 }
                        @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS'; Name = 'EnableRID44231'; Value = 0 }
                        @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS'; Name = 'EnableRID64640'; Value = 0 }
                        @{ Type = 'Reg'; Path = 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS'; Name = 'EnableRID66610'; Value = 0 }
                    )
                }
            )
            Junk   = @()
        }

        # ------------------------------------------------------------------ Intel
        @{
            Id     = 'intel'
            Name   = 'Intel'
            Kind   = 'Processor and graphics'
            Detect = @{ Paths = @('%ProgramFiles%\Intel', '%ProgramFiles(x86)%\Intel'); Services = @('dptftcs', 'DSAService') }
            Note   = 'Your Intel drivers, graphics and Bluetooth keep working. Only the reporting and update-checking extras are switched off.'
            Items  = @(
                @{
                    Id          = 'intel.dtt'
                    Title       = 'Stop Intel''s tuning telemetry service'
                    Description = 'Dynamic Tuning Technology keeps managing heat and power. Only its telemetry client is switched off.'
                    Recommended = $true
                    Actions     = @(@{ Type = 'Service'; Name = 'dptftcs'; StartType = 'Disabled' })
                }
                @{
                    Id          = 'intel.dsa'
                    Title       = 'Stop Intel Driver & Support Assistant running in the background'
                    Description = 'It checks for drivers and reports on your hardware. You can still check for drivers yourself at intel.com.'
                    Recommended = $true
                    Actions     = @(
                        @{ Type = 'Service'; Name = 'DSAService'; StartType = 'Disabled' }
                        @{ Type = 'Service'; Name = 'DSAUpdateService'; StartType = 'Disabled' }
                    )
                }
            )
            Junk   = @(
                @{ Match = 'Intel.*Computing Improvement Program'; Title = 'Intel Computing Improvement Program'; Why = 'A data-collection programme about how you use your PC. Nothing needs it.' }
                @{ Match = 'Intel.*Driver & Support Assistant'; Title = 'Intel Driver & Support Assistant'; Why = 'Background driver checker. Drivers can be downloaded from intel.com when you want them.' }
            )
        }

        # ------------------------------------------------------------------ AMD
        @{
            Id     = 'amd'
            Name   = 'AMD'
            Kind   = 'Processor and graphics'
            Detect = @{ Gpu = 'AMD|Radeon'; Paths = @('%ProgramFiles%\AMD'); Services = @('AMD Crash Defender Service') }
            Note   = 'Your Radeon drivers and AMD Software keep working. Only crash reporting and the auto-start helper are switched off.'
            Items  = @(
                @{
                    Id          = 'amd.crash'
                    Title       = 'Stop AMD sending crash reports'
                    Description = 'Crash Defender uploads crash information. Your graphics driver is not affected.'
                    Recommended = $true
                    Actions     = @(@{ Type = 'Service'; Name = 'AMD Crash Defender Service'; StartType = 'Disabled' })
                }
                @{
                    Id          = 'amd.autostart'
                    Title       = 'Stop AMD Software opening at sign-in'
                    Description = 'You can still open AMD Software from the Start menu. Tick this only if you do not use its overlay.'
                    Recommended = $false
                    Actions     = @(@{ Type = 'Task'; Path = '\'; Name = 'StartCN' })
                }
            )
            Junk   = @()
        }

        # ------------------------------------------------------------------ MSI
        @{
            Id     = 'msi'
            Name   = 'MSI'
            Kind   = 'Laptop maker'
            Detect = @{ Manufacturer = 'Micro-Star|MSI'; Paths = @('%ProgramFiles(x86)%\MSI'); Services = @('MSI_Center_Service') }
            Note   = 'Fan control, performance modes and the hardware buttons keep working. MSI Center still opens normally.'
            Items  = @(
                @{
                    Id          = 'msi.sendev'
                    Title       = 'Stop MSI''s event reporting service'
                    Description = 'Sendevsvc reports events back to MSI. Fan control and the hardware buttons do not need it.'
                    Recommended = $true
                    Actions     = @(@{ Type = 'Service'; Name = 'MSI Sendevsvc'; StartType = 'Disabled' })
                }
                @{
                    Id          = 'msi.updater'
                    Title       = 'Stop MSI Center checking for updates in the background'
                    Description = 'You can still update MSI Center yourself from inside the app.'
                    Recommended = $true
                    Actions     = @(@{ Type = 'Task'; Path = '\'; Name = 'OneDC_Updater' })
                }
            )
            Junk   = @(
                @{ Match = '^MSI Center$'; Title = 'MSI Center'; Why = 'The dashboard app. Remove it only if you do not use fan control or performance modes. Individual modules can also be removed from inside MSI Center.' }
            )
        }

        # ------------------------------------------------------------------ ASUS
        @{
            Id     = 'asus'
            Name   = 'ASUS'
            Kind   = 'Laptop maker'
            Detect = @{ Manufacturer = 'ASUS'; Paths = @('%ProgramFiles(x86)%\ASUS', '%ProgramFiles%\ASUS'); Services = @('ASUSOptimization', 'AsusAppService') }
            Note   = 'Armoury Crate and MyASUS still open and work. Only the background analysis and update helpers are switched off.'
            Items  = @(
                @{
                    Id          = 'asus.analysis'
                    Title       = 'Stop ASUS analysing and diagnosing in the background'
                    Description = 'These services collect system information for ASUS support tools.'
                    Recommended = $true
                    Actions     = @(
                        @{ Type = 'Service'; Name = 'ASUSSystemAnalysis'; StartType = 'Disabled' }
                        @{ Type = 'Service'; Name = 'ASUSSystemDiagnosis'; StartType = 'Disabled' }
                    )
                }
                @{
                    Id          = 'asus.updater'
                    Title       = 'Stop the ASUS software updater running in the background'
                    Description = 'You can still update from MyASUS or Armoury Crate when you want to.'
                    Recommended = $true
                    Actions     = @(@{ Type = 'Service'; Name = 'ASUSSoftwareManager'; StartType = 'Disabled' })
                }
            )
            Junk   = @(
                @{ Match = 'ASUS GIFTBOX'; Title = 'ASUS GIFTBOX'; Why = 'Advertises apps and offers.' }
                @{ Match = 'GameFirst'; Title = 'ASUS GameFirst'; Why = 'Network "optimiser" that most people never open.' }
            )
        }

        # ------------------------------------------------------------------ Dell
        @{
            Id     = 'dell'
            Name   = 'Dell'
            Kind   = 'Laptop maker'
            Detect = @{ Manufacturer = 'Dell'; Paths = @('%ProgramFiles%\Dell', '%ProgramFiles(x86)%\Dell'); Services = @('SupportAssistAgent', 'DellDataVault') }
            Note   = 'Your Dell drivers stay exactly as they are. SupportAssist still opens if you want to run a check yourself.'
            Items  = @(
                @{
                    Id          = 'dell.datavault'
                    Title       = 'Stop Dell Data Vault collecting information'
                    Description = 'Data Vault gathers usage and hardware data for Dell. Nothing on the PC needs it.'
                    Recommended = $true
                    Actions     = @(
                        @{ Type = 'Service'; Name = 'DellDataVault'; StartType = 'Disabled' }
                        @{ Type = 'Service'; Name = 'DDVDataCollector'; StartType = 'Disabled' }
                        @{ Type = 'Service'; Name = 'DDVCollectorSvcApi'; StartType = 'Disabled' }
                    )
                }
                @{
                    Id          = 'dell.supportassist'
                    Title       = 'Stop SupportAssist scanning in the background'
                    Description = 'You can still open SupportAssist and run a check whenever you like.'
                    Recommended = $true
                    Actions     = @(@{ Type = 'Service'; Name = 'SupportAssistAgent'; StartType = 'Disabled' })
                }
            )
            Junk   = @(
                @{ Match = 'Dell Customer Connect'; Title = 'Dell Customer Connect'; Why = 'Shows Dell offers and surveys.' }
                @{ Match = 'Dell Digital Delivery'; Title = 'Dell Digital Delivery'; Why = 'Delivers software you bought with the PC. Usually finished its job long ago.' }
            )
        }

        # ------------------------------------------------------------------ HP
        @{
            Id     = 'hp'
            Name   = 'HP'
            Kind   = 'Laptop maker'
            Detect = @{ Manufacturer = 'HP|Hewlett'; Paths = @('%ProgramFiles%\HP', '%ProgramFiles(x86)%\HP'); Services = @('HPAppHelperCap', 'HotKeyServiceUWP') }
            Note   = 'HP drivers and the hardware keys keep working. HP Support Assistant still opens when you want it.'
            Items  = @(
                @{
                    Id          = 'hp.analytics'
                    Title       = 'Stop HP Analytics collecting usage data'
                    Description = 'Touchpoint Analytics reports how you use the PC back to HP.'
                    Recommended = $true
                    Actions     = @(@{ Type = 'Service'; Name = 'HpTouchpointAnalyticsService'; StartType = 'Disabled' })
                }
                @{
                    Id          = 'hp.support'
                    Title       = 'Stop HP Support Assistant running in the background'
                    Description = 'You can still open it from the Start menu to check for updates.'
                    Recommended = $true
                    Actions     = @(@{ Type = 'Service'; Name = 'HPSupportSolutionsFrameworkService'; StartType = 'Disabled' })
                }
            )
            Junk   = @(
                @{ Match = 'HP JumpStart'; Title = 'HP JumpStart'; Why = 'A welcome and offers app.' }
                @{ Match = 'HP Documentation'; Title = 'HP Documentation'; Why = 'The manual, also available on hp.com.' }
            )
        }

        # ------------------------------------------------------------------ Lenovo
        @{
            Id     = 'lenovo'
            Name   = 'Lenovo'
            Kind   = 'Laptop maker'
            Detect = @{ Manufacturer = 'Lenovo'; Paths = @('%ProgramFiles%\Lenovo', '%ProgramFiles(x86)%\Lenovo'); Services = @('ImControllerService', 'LenovoVantageService') }
            Note   = 'Vantage still opens for battery and display settings. Only its background parts are switched off.'
            Items  = @(
                @{
                    Id          = 'lenovo.imcontroller'
                    Title       = 'Stop the Lenovo background controller'
                    Description = 'ImController downloads and runs Lenovo helper tasks in the background.'
                    Recommended = $true
                    Actions     = @(@{ Type = 'Service'; Name = 'ImControllerService'; StartType = 'Disabled' })
                }
                @{
                    Id          = 'lenovo.vantage'
                    Title       = 'Stop Lenovo Vantage running in the background'
                    Description = 'Vantage still opens normally from the Start menu.'
                    Recommended = $true
                    Actions     = @(@{ Type = 'Service'; Name = 'LenovoVantageService'; StartType = 'Disabled' })
                }
            )
            Junk   = @(
                @{ Match = 'Lenovo Now|Lenovo Smart Appearance'; Title = 'Lenovo extras'; Why = 'Promotional and novelty apps that came with the PC.' }
            )
        }

        # ------------------------------------------------------------------ Acer
        @{
            Id     = 'acer'
            Name   = 'Acer'
            Kind   = 'Laptop maker'
            Detect = @{ Manufacturer = 'Acer'; Paths = @('%ProgramFiles%\Acer', '%ProgramFiles(x86)%\Acer') }
            Note   = 'Acer drivers stay as they are. Care Center still opens if you want to use it.'
            Items  = @(
                @{
                    Id          = 'acer.care'
                    Title       = 'Stop Acer Care Center running in the background'
                    Description = 'It checks your PC and shows Acer offers. You can still open it yourself.'
                    Recommended = $true
                    Actions     = @(@{ Type = 'Service'; Name = 'ACCSvc'; StartType = 'Disabled' })
                }
            )
            Junk   = @(
                @{ Match = 'Acer Jumpstart'; Title = 'Acer Jumpstart'; Why = 'Promotes apps and offers.' }
            )
        }
    )
}
