$kioskUser = 'kioskUser0'

function Set-AppLockerConfiguration {
    $kioskUserSid = (Get-LocalUser -Name $kioskUser).SID.Value
    # see https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/working-with-applocker-rules#path
    $policyTemplateXml = @"
<AppLockerPolicy Version="1">
    <RuleCollection Type="Appx" EnforcementMode="Enabled">
        <FilePublisherRule Id="00000000-0000-0000-1000-000000000001" Name="Allow Everyone" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
            <Conditions>
                <FilePublisherCondition PublisherName="*" ProductName="*" BinaryName="*">
                    <BinaryVersionRange LowSection="0.0.0.0" HighSection="*" />
                </FilePublisherCondition>
            </Conditions>
        </FilePublisherRule>
    </RuleCollection>
    <RuleCollection Type="Exe" EnforcementMode="Enabled">
        <FilePathRule Id="00000000-0000-0000-2000-000000000001" Name="Allow Everyone" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
            <Conditions>
                <FilePathCondition Path="*" />
            </Conditions>
        </FilePathRule>@@KIOSK_USER_RULES@@
    </RuleCollection>
    <RuleCollection Type="Msi" EnforcementMode="Enabled">
        <FilePathRule Id="00000000-0000-0000-3000-000000000001" Name="Allow Administrators" Description="" UserOrGroupSid="S-1-5-32-544" Action="Allow">
            <Conditions>
                <FilePathCondition Path="*" />
            </Conditions>
        </FilePathRule>
    </RuleCollection>
    <RuleCollection Type="Script" EnforcementMode="Enabled">
        <FilePathRule Id="00000000-0000-0000-4000-000000000001" Name="Allow Administrators" Description="" UserOrGroupSid="S-1-5-32-544" Action="Allow">
            <Conditions>
                <FilePathCondition Path="*" />
            </Conditions>
        </FilePathRule>
    </RuleCollection>
</AppLockerPolicy>
"@
    # NB you can get the full windows executable list using something like:
    #       (Get-ChildItem -Recurse -filter '*.exe' C:\Windows).FullName | Sort-Object
    #       (Get-ChildItem -Recurse -filter '*.exe' C:\Windows\SysWOW64).FullName | Sort-Object
    $kioskUserXmlRules = @(
        ,@("PowerShell",                    "%PROGRAMFILES%\PowerShell\*")
        ,@("Windows PowerShell",            "%SYSTEM32%\WindowsPowerShell\*")
        ,@("cmd",                           "%SYSTEM32%\cmd.exe")
        ,@("rundll32",                      "%SYSTEM32%\rundll32.exe")
        ,@("cscript",                       "%SYSTEM32%\cscript.exe")
        ,@("wscript",                       "%SYSTEM32%\wscript.exe")
        ,@("reg",                           "%SYSTEM32%\reg.exe")
        ,@("regedit",                       "%WINDIR%\regedit.exe")
        ,@("explorer",                      "%WINDIR%\explorer.exe")
        ,@("Temp",                          "%WINDIR%\Temp\*")
        ,@("ProgramData",                   "%PROGRAMDATA%\*")
        ,@("Edge",                          "%PROGRAMFILES%\Microsoft\Edge\*")
        ,@("Removable Media",               "%REMOVABLE%\*")
        ,@("Removable Storage Device",      "%HOT%\*")
    ) | ForEach-Object -Begin { $i = 0 } {
        @"

        <FilePathRule Id="00000000-0000-0000-2001-0000$((++$i).ToString('x8'))" Name="Deny $($_[0])" Description="" UserOrGroupSid="$kioskUserSid" Action="Deny">
            <Conditions>
                <FilePathCondition Path="$($_[1])" />
            </Conditions>
        </FilePathRule>
"@
    }
    $policyXml = $policyTemplateXml `
        -replace '@@KIOSK_USER_RULES@@',$kioskUserXmlRules
    $policyXmlPath = "$env:TEMP\AppLockerPolicy.xml"
    New-Item -Force -Path $policyXmlPath -Value $policyXml | Out-Null
    Set-AppLockerPolicy -XmlPolicy $policyXmlPath
    Remove-Item $policyXmlPath
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

Write-Output "Setting up the App Locker configuration..."
Set-AppLockerConfiguration
