# NVIDIA telemetry block.
#
# Why block instead of delete?
# In NVIDIA App 11.x the telemetry plugin (NvTelemetry64.dll) is a hard dependency of the
# app's account/backend plugin. Deleting it - or uninstalling the "NVIDIA Telemetry Client"
# package, which also uninstalls NVIDIA App as a dependent - breaks game optimization and
# driver updates. Blocking only the telemetry servers keeps every feature working.
#
# Hosts: ONLY telemetry / analytics / survey / experiment servers observed in NVIDIA App logs.
# Deliberately NOT blocked (needed for features): gfwsl.geforce.com, public.games.geforce.com,
# ota.nvidia.com, ota-downloads.nvidia.com, login.nvidia.com, api-prod.nvidia.com,
# userstore.nvidia.com, activation.gfe.nvidia.com, localized-config-api.gx.nvidia.com.

@{
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

    # NVIDIA's own telemetry opt-out values.
    Flags = @(
        @{ Path = 'HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client'; Name = 'OptInOrOutPreference'; Value = 0 }
        @{ Path = 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS'; Name = 'EnableRID44231'; Value = 0 }
        @{ Path = 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS'; Name = 'EnableRID64640'; Value = 0 }
        @{ Path = 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS'; Name = 'EnableRID66610'; Value = 0 }
    )
}
