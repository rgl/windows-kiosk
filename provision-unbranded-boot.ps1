# see https://learn.microsoft.com/en-us/windows/configuration/unbranded-boot/?tabs=powershell1%2Ccmd

function Set-BcdOption([string]$section, [string]$name, [string]$value) {
    $output = bcdedit.exe -set $section $name $value
    if ($output -notcontains "The operation completed successfully.") {
        throw "bcdedit.exe -set $section $name $value failed: $output"
    }
}

# Enable Unbranded Boot.
Enable-WindowsOptionalFeature -FeatureName Client-DeviceLockdown,Client-EmbeddedBootExp -Online | Out-Null

# Disable the F8 key during startup to prevent access to the Advanced startup options menu.
Set-BcdOption '{globalsettings}' advancedoptions false

# Disable the F10 key during startup to prevent access to the Advanced startup options menu.
Set-BcdOption '{globalsettings}' optionsedit false

# Suppress all Windows UI elements (logo, status indicator, and status message) during startup.
Set-BcdOption '{globalsettings}' bootuxdisabled on

# Suppress any error screens that are displayed during boot. When boot manager hits a
# WinLoad Error or Bad Disk Error, the system displays a black screen.
Set-BcdOption '{bootmgr}' noerrordisplay on
