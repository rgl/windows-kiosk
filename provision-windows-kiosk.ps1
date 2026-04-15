param(
    [switch]$RunningAsScheduledTask = $false
)

Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Host
    Write-Host "ERROR: $_"
    Write-Host (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Host (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

$kioskUser = 'kioskUser0'
$windowsKioskTestAppPath = "C:\Program Files\WindowsKioskTestApp\WindowsKioskTestApp.exe"

function Set-WindowsKioskShellLauncher {
    # configure the shell launcher.
    # see https://learn.microsoft.com/en-us/windows/configuration/shell-launcher/quickstart-kiosk?tabs=ps
    # see https://learn.microsoft.com/en-us/windows/configuration/shell-launcher/xsd
    # NB the id was generated using:
    #       python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_URL, 'https://github.com/rgl/windows-kiosk-test-app'))"
    $shellLauncherConfiguration = @"
<?xml version="1.0" encoding="utf-8"?>
<ShellLauncherConfiguration xmlns="http://schemas.microsoft.com/ShellLauncher/2018/Configuration" xmlns:V2="http://schemas.microsoft.com/ShellLauncher/2019/Configuration">
    <Profiles>
        <DefaultProfile>
            <Shell Shell="%SystemRoot%\explorer.exe"/>
        </DefaultProfile>
        <Profile Id="{824fd952-0e4d-5327-a0bd-b2b26e36f833}">
            <Shell Shell="$windowsKioskTestAppPath" V2:AppType="Desktop" V2:AllAppsFullScreen="false">
                <ReturnCodeActions>
                    <ReturnCodeAction ReturnCode="0" Action="RestartShell"/>
                    <ReturnCodeAction ReturnCode="1" Action="DoNothing"/>
                    <ReturnCodeAction ReturnCode="255" Action="ShutdownDevice"/>
                    <ReturnCodeAction ReturnCode="-1" Action="RestartDevice"/>
                </ReturnCodeActions>
                <DefaultAction Action="RestartShell"/>
            </Shell>
        </Profile>
    </Profiles>
    <Configs>
        <Config>
            <AutoLogonAccount/>
            <Profile Id="{824fd952-0e4d-5327-a0bd-b2b26e36f833}"/>
        </Config>
    </Configs>
</ShellLauncherConfiguration>
"@
    $aa = Get-CimInstance -Namespace root/cimv2/mdm/dmmap -ClassName MDM_AssignedAccess
    $aa.ShellLauncher = [System.Net.WebUtility]::HtmlEncode($shellLauncherConfiguration)
    $aa | Set-CimInstance

    # ensure the kioskUser0 user was created by MDM_AssignedAccess.
    Write-Output "Ensuring the $kioskUser Kiosk User exists..."
    $localKioskUser = Get-LocalUser $kioskUser -ErrorAction SilentlyContinue
    if (!$localKioskUser) {
        throw "the $kioskUser Kiosk User was not created"
    }
    Write-Output "The $kioskUser ($($localKioskUser.SID.Value)) Kiosk User exists."
}

$taskName = 'windows-kiosk-configure'
$transcriptPath = "C:\tmp\$taskName.log"

if ($RunningAsScheduledTask) {
    Start-Transcript $transcriptPath

    Set-WindowsKioskShellLauncher
} else {
    Write-Host "Registering the Scheduled Task $taskName to run $PSCommandPath..."
    $action = New-ScheduledTaskAction `
        -Execute 'PowerShell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass $PSCommandPath -RunningAsScheduledTask"
    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -User 'SYSTEM' `
        | Out-Null
    Start-ScheduledTask `
        -TaskName $taskName

    Write-Output 'Waiting for the Scheduled Task to complete...'
    while ((Get-ScheduledTask -TaskName $taskName).State -ne 'Ready') {
        Start-Sleep -Seconds 1
    }
    $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
    $taskResult = $taskInfo.LastTaskResult

    Write-Output 'Unregistering Scheduled Task...'
    Unregister-ScheduledTask `
        -TaskName $taskName `
        -Confirm:$false

    Write-Output 'Scheduled Task output:'
    Get-Content -ErrorAction SilentlyContinue $transcriptPath
    Write-Output "Scheduled Task result: $taskResult"
    Remove-Item $transcriptPath
}
