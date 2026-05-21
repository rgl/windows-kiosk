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

function Start-AsScheduledTask([string]$taskName, [bool]$runningAsScheduledTask) {
    $transcriptPath = "C:\tmp\$taskName.log"

    if ($runningAsScheduledTask) {
        Start-Transcript $transcriptPath

        return
    }

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

    Write-Host 'Waiting for the Scheduled Task to complete...'
    while ((Get-ScheduledTask -TaskName $taskName).State -ne 'Ready') {
        Start-Sleep -Seconds 1
    }
    $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
    $taskResult = $taskInfo.LastTaskResult

    Write-Host 'Unregistering Scheduled Task...'
    Unregister-ScheduledTask `
        -TaskName $taskName `
        -Confirm:$false

    Write-Host 'Scheduled Task output:'
    Get-Content -ErrorAction SilentlyContinue $transcriptPath
    Write-Host "Scheduled Task result: $taskResult"
    Remove-Item $transcriptPath

    Exit 0
}

function Format-Xml {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [xml]$InputObject
    )
    process {
        $stringWriter = New-Object System.IO.StringWriter
        $xmlWriter = New-Object System.Xml.XmlTextWriter($stringWriter)
        $xmlWriter.Formatting = [System.Xml.Formatting]::Indented
        $xmlWriter.Indentation = 4
        $InputObject.WriteContentTo($xmlWriter)
        $xmlWriter.Flush()
        $stringWriter.Flush()
        $stringWriter.ToString()
    }
}

function Write-Title($title) {
    Write-Host "#`n# $title`n#"
}

Start-AsScheduledTask 'summary' $RunningAsScheduledTask

Write-Title "App Locker services status"
Get-Service AppLockerFltr,AppID,AppIDSvc `
    | Format-Table `
        -Property Name,DisplayName,RequiredServices,StartType,Status

Write-Title "App Locker Policy"
Get-AppLockerPolicy -Local `
    | Format-Xml

Write-Title "Kiosk Shell Launcher"
$aa = Get-CimInstance -Namespace root\cimv2\mdm\dmmap -ClassName MDM_AssignedAccess
[System.Net.WebUtility]::HtmlDecode($aa.ShellLauncher)
