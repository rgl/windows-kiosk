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

$windowsKioskTestAppPath = "C:\Program Files\WindowsKioskTestApp\WindowsKioskTestApp.exe"
if (!(Test-Path $windowsKioskTestAppPath)) {
    throw "the kiosk shell $windowsKioskTestAppPath was not found"
}

# NB set $useShellLauncherAutoLogon to $true to let the shell launcher create
#    and manage the kiosk account; otherwise, this script will create a local
#    account and configure the windows auto logon to use it.
$useShellLauncherAutoLogon = $true
$kioskUserName = if ($useShellLauncherAutoLogon) {
    # NB do not modify this user name. this user is managed by the shell
    #    launcher, and cannot be changed.
    'kioskUser0'
} else {
    # NB you can modify this user name. this user will be managed by this
    #    script.
    'kiosk'
}
# NB in some places we need to use the full name because the user name cannot be
#    the same as the computer/domain name.
if ($kioskUserName -match '^.+\\') {
    throw "`$kioskUserName cannot be a domain user. it must be a local user (without a domain name)."
}
$kioskUserFullName = "$env:COMPUTERNAME\$kioskUserName"

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

    Exit $taskResult
}

function Set-WindowsKioskShellLauncher {
    # configure the shell launcher.
    # see https://learn.microsoft.com/en-us/windows/configuration/shell-launcher/quickstart-kiosk?tabs=ps
    # see https://learn.microsoft.com/en-us/windows/configuration/shell-launcher/xsd
    # NB the id was generated using:
    #       python3 -c "import uuid; print(uuid.uuid5(uuid.NAMESPACE_URL, 'https://github.com/rgl/windows-kiosk-test-app'))"
    # NB Configs/Config can have a <AutoLogonAccount/>, <Account Name="{user-full-name}"/>, or <Account Sid="{user-sid}"/>.
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
            $(if ($useShellLauncherAutoLogon) { '<AutoLogonAccount/>' } else { "<Account Name=`"$kioskUserFullName`"/>" })
            <Profile Id="{824fd952-0e4d-5327-a0bd-b2b26e36f833}"/>
        </Config>
    </Configs>
</ShellLauncherConfiguration>
"@
    $aa = Get-CimInstance -Namespace root\cimv2\mdm\dmmap -ClassName MDM_AssignedAccess
    $aa.ShellLauncher = [System.Net.WebUtility]::HtmlEncode($shellLauncherConfiguration)
    $aa | Set-CimInstance
    # ensure the kioskUser0 user was created by MDM_AssignedAccess.
    Write-Host "Ensuring the $kioskUserName Kiosk User exists..."
    $localKioskUser = Get-LocalUser $kioskUserName -ErrorAction SilentlyContinue
    if (!$localKioskUser) {
        throw "the $kioskUserName Kiosk User was not created"
    }
    Write-Host "The $kioskUserName ($($localKioskUser.SID.Value)) Kiosk User exists."
}

function Set-WindowsAutoLogon([string]$userName, [string]$password) {
    # see https://learn.microsoft.com/en-us/windows/win32/secauthn/msgina-dll-features
    # see http://www.pinvoke.net/default.aspx/advapi32.lsaretrieveprivatedata
    # see https://attack.mitre.org/techniques/T1003/004/
    Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace PInvoke
{
    public class LSAUtil
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct LSA_UNICODE_STRING
        {
            public UInt16 Length;
            public UInt16 MaximumLength;
            public IntPtr Buffer;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct LSA_OBJECT_ATTRIBUTES
        {
            public int Length;
            public IntPtr RootDirectory;
            public LSA_UNICODE_STRING ObjectName;
            public uint Attributes;
            public IntPtr SecurityDescriptor;
            public IntPtr SecurityQualityOfService;
        }

        private enum LSA_AccessPolicy : long
        {
            POLICY_VIEW_LOCAL_INFORMATION = 0x00000001L,
            POLICY_VIEW_AUDIT_INFORMATION = 0x00000002L,
            POLICY_GET_PRIVATE_INFORMATION = 0x00000004L,
            POLICY_TRUST_ADMIN = 0x00000008L,
            POLICY_CREATE_ACCOUNT = 0x00000010L,
            POLICY_CREATE_SECRET = 0x00000020L,
            POLICY_CREATE_PRIVILEGE = 0x00000040L,
            POLICY_SET_DEFAULT_QUOTA_LIMITS = 0x00000080L,
            POLICY_SET_AUDIT_REQUIREMENTS = 0x00000100L,
            POLICY_AUDIT_LOG_ADMIN = 0x00000200L,
            POLICY_SERVER_ADMIN = 0x00000400L,
            POLICY_LOOKUP_NAMES = 0x00000800L,
            POLICY_NOTIFICATION = 0x00001000L
        }

        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
        private static extern uint LsaRetrievePrivateData(
            IntPtr PolicyHandle,
            ref LSA_UNICODE_STRING KeyName,
            out IntPtr PrivateData
        );

        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
        private static extern uint LsaStorePrivateData(
            IntPtr policyHandle,
            ref LSA_UNICODE_STRING KeyName,
            ref LSA_UNICODE_STRING PrivateData
        );

        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
        private static extern uint LsaOpenPolicy(
            ref LSA_UNICODE_STRING SystemName,
            ref LSA_OBJECT_ATTRIBUTES ObjectAttributes,
            uint DesiredAccess,
            out IntPtr PolicyHandle
        );

        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
        private static extern uint LsaNtStatusToWinError(
            uint status
        );

        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
        private static extern uint LsaClose(
            IntPtr policyHandle
        );

        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
        private static extern uint LsaFreeMemory(
            IntPtr buffer
        );

        private LSA_OBJECT_ATTRIBUTES objectAttributes;
        private LSA_UNICODE_STRING localsystem;
        private LSA_UNICODE_STRING secretName;

        public LSAUtil(string key)
        {
            if (key.Length == 0)
            {
                throw new Exception("Key length zero");
            }
            objectAttributes = new LSA_OBJECT_ATTRIBUTES();
            objectAttributes.Length = 0;
            objectAttributes.RootDirectory = IntPtr.Zero;
            objectAttributes.Attributes = 0;
            objectAttributes.SecurityDescriptor = IntPtr.Zero;
            objectAttributes.SecurityQualityOfService = IntPtr.Zero;
            localsystem = new LSA_UNICODE_STRING();
            localsystem.Buffer = IntPtr.Zero;
            localsystem.Length = 0;
            localsystem.MaximumLength = 0;
            secretName = new LSA_UNICODE_STRING();
            secretName.Buffer = Marshal.StringToHGlobalUni(key);
            secretName.Length = (UInt16)(key.Length * UnicodeEncoding.CharSize);
            secretName.MaximumLength = (UInt16)((key.Length + 1) * UnicodeEncoding.CharSize);
        }

        private IntPtr GetLsaPolicy(LSA_AccessPolicy access)
        {
            IntPtr LsaPolicyHandle;
            uint ntsResult = LsaOpenPolicy(ref this.localsystem, ref this.objectAttributes, (uint)access, out LsaPolicyHandle);
            uint winErrorCode = LsaNtStatusToWinError(ntsResult);
            if (winErrorCode != 0)
            {
                throw new Exception("LsaOpenPolicy failed: " + winErrorCode);
            }
            return LsaPolicyHandle;
        }

        private static void ReleaseLsaPolicy(IntPtr LsaPolicyHandle)
        {
            uint ntsResult = LsaClose(LsaPolicyHandle);
            uint winErrorCode = LsaNtStatusToWinError(ntsResult);
            if (winErrorCode != 0)
            {
                throw new Exception("LsaClose failed: " + winErrorCode);
            }
        }

        private static void FreeMemory(IntPtr Buffer)
        {
            uint ntsResult = LsaFreeMemory(Buffer);
            uint winErrorCode = LsaNtStatusToWinError(ntsResult);
            if (winErrorCode != 0)
            {
                throw new Exception("LsaFreeMemory failed: " + winErrorCode);
            }
        }

        public void SetSecret(string value)
        {
            LSA_UNICODE_STRING lusSecretData = new LSA_UNICODE_STRING();
            if (value.Length > 0)
            {
                // Create data and key.
                lusSecretData.Buffer = Marshal.StringToHGlobalUni(value);
                lusSecretData.Length = (UInt16)(value.Length * UnicodeEncoding.CharSize);
                lusSecretData.MaximumLength = (UInt16)((value.Length + 1) * UnicodeEncoding.CharSize);
            }
            else
            {
                // Delete data and key.
                lusSecretData.Buffer = IntPtr.Zero;
                lusSecretData.Length = 0;
                lusSecretData.MaximumLength = 0;
            }
            IntPtr LsaPolicyHandle = GetLsaPolicy(LSA_AccessPolicy.POLICY_CREATE_SECRET);
            uint result = LsaStorePrivateData(LsaPolicyHandle, ref secretName, ref lusSecretData);
            ReleaseLsaPolicy(LsaPolicyHandle);
            uint winErrorCode = LsaNtStatusToWinError(result);
            if (winErrorCode != 0)
            {
                throw new Exception("LsaStorePrivateData failed: " + winErrorCode);
            }
        }

        public string GetSecret()
        {
            IntPtr PrivateData = IntPtr.Zero;
            IntPtr LsaPolicyHandle = GetLsaPolicy(LSA_AccessPolicy.POLICY_GET_PRIVATE_INFORMATION);
            uint ntsResult = LsaRetrievePrivateData(LsaPolicyHandle, ref secretName, out PrivateData);
            ReleaseLsaPolicy(LsaPolicyHandle);
            uint winErrorCode = LsaNtStatusToWinError(ntsResult);
            if (winErrorCode != 0)
            {
                throw new Exception("LsaRetrievePrivateData failed: " + winErrorCode);
            }
            LSA_UNICODE_STRING lusSecretData = (LSA_UNICODE_STRING)Marshal.PtrToStructure(PrivateData, typeof(LSA_UNICODE_STRING));
            string value = Marshal.PtrToStringAuto(lusSecretData.Buffer).Substring(0, lusSecretData.Length / 2);
            FreeMemory(PrivateData);
            return value;
        }
    }
}
"@
    $lsaUtil = New-Object PInvoke.LSAUtil -ArgumentList DefaultPassword
    $autoLogonKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    # reset the auto logon.
    Set-ItemProperty -Path $autoLogonKeyPath -Name AutoAdminLogon -Value 0
    @(
        ,'AutoLogonCount'
        ,'AutoLogonSID'
        ,'DefaultDomainName'
        ,'DefaultUserName'
        ,'DefaultPassword'
    ) | ForEach-Object {
        Remove-ItemProperty -Path $autoLogonKeyPath -Name $_ -ErrorAction SilentlyContinue
    }
    $lsaUtil.SetSecret('')
    # set the auto logon.
    Set-ItemProperty -Path $autoLogonKeyPath -Name AutoAdminLogon -Value 1
    Set-ItemProperty -Path $autoLogonKeyPath -Name DefaultUserName -Value $userName
    $lsaUtil.SetSecret($password)
}

Start-AsScheduledTask 'windows-kiosk-configure' $RunningAsScheduledTask

if (-not $useShellLauncherAutoLogon) {
    Write-Host "Creating the $kioskUserName local user account..."
    [Reflection.Assembly]::LoadWithPartialName('System.Web') | Out-Null
    $kioskUserPassword = [Web.Security.Membership]::GeneratePassword(32, 8)
    $kioskUserPasswordSecureString = ConvertTo-SecureString $kioskUserPassword -AsPlainText -Force
    $kioskUserCredential = New-Object `
        Management.Automation.PSCredential `
        -ArgumentList `
            $kioskUserFullName,
            $kioskUserPasswordSecureString
    New-LocalUser `
        -Name $kioskUserName `
        -FullName 'Kiosk User' `
        -Password $kioskUserPasswordSecureString `
        -PasswordNeverExpires `
        | Out-Null
    Add-LocalGroupMember `
        -Group Users `
        -Member $kioskUserFullName
    # login to force the system to create the home directory.
    # NB the home directory will have the correct permissions, only the
    #    SYSTEM, Administrators and the user account are granted full
    #    permissions to it.
    Start-Process `
        -Wait `
        -WindowStyle Hidden `
        -Credential $kioskUserCredential `
        -WorkingDirectory 'C:\' `
        -FilePath cmd `
        -ArgumentList '/c'
    Write-Host "The $kioskUserName ($((Get-LocalUser $kioskUserName).SID.Value)) local user was successfully created."
    Write-Host "Setting the $kioskUserName local user account to automatically logon..."
    Set-WindowsAutoLogon `
        $kioskUserFullName `
        $kioskUserPassword
}

Write-Host "Setting the Windows Kiosk Shell Launcher..."
Set-WindowsKioskShellLauncher
