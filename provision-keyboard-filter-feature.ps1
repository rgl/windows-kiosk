# see https://learn.microsoft.com/en-us/windows/configuration/keyboard-filter/

Enable-WindowsOptionalFeature -FeatureName Client-KeyboardFilter -Online -NoRestart | Out-Null
