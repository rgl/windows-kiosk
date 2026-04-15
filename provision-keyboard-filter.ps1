# see https://learn.microsoft.com/en-us/windows/configuration/keyboard-filter/

function Disable-PredefinedKey([string]$id) {
    $predefinedKey = Get-CimInstance `
        -Namespace root/standardcimv2/embedded `
        -Class WEKF_PredefinedKey `
        | Where-Object { $_.Id -eq $id }
    if ($predefinedKey) {
        $predefinedKey.Enabled = 1
        $predefinedKey | Set-CimInstance
    } else {
        throw "$id WEKF_PredefinedKey does not exist"
    }
}

Write-Output "Disabling predefined keys..."
Disable-PredefinedKey 'Ctrl+Alt+Del'    # Open the Windows Security screen.
Disable-PredefinedKey 'Shift+Ctrl+Esc'  # Open Task Manager.
Disable-PredefinedKey 'Alt+Space'       # Open shortcut menu for the active window.
Disable-PredefinedKey 'Windows'         # All combinations that use the Win/Windows key. This includes, e.g.,:
                                        #   Win+L Lock the device.
                                        #   Win+I Open Settings charm.
                                        #   Win+P Cycle through Presentation Mode. Also blocks the Windows key + Shift + P and the Windows key + Ctrl + P key combinations.
                                        #   Win+U Open Ease of Access Center.
                                        #   Win+A Shows Accessability pane, and from there, we can open the Windows Settings app.
                                        #   Ctrl+Win+S Shows Voice Access.
                                        #   Ctrl+Win+V Shows Sound Output.
                                        #   Ctrl+Win+O Shows On-Screen Keyboard.

Write-Output "Disabled predefined keys:"
Get-CimInstance `
    -Namespace root/standardcimv2/embedded `
    -Class WEKF_PredefinedKey `
    | Where-Object { $_.Enabled } `
    | Select-Object Id `
    | Sort-Object Id

Write-Output "Enabled predefined keys:"
Get-CimInstance `
    -Namespace root/standardcimv2/embedded `
    -Class WEKF_PredefinedKey `
    | Where-Object { -not $_.Enabled } `
    | Select-Object Id `
    | Sort-Object Id
