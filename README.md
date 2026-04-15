# About

An example Windows 11 Kiosk.

## Usage

Execute the following instructions in a Ubuntu 24.04 host.

Install the [`windows-11-24h2-uefi-amd64` vagrant box](https://github.com/rgl/windows-vagrant).

Start the vagrant environment:

```bash
vagrant up --no-destroy-on-error --no-tty
```

At the machine console you should see the [WindowsKioskTestApp](https://github.com/rgl/windows-kiosk-test-app) application running in full screen mode.

Try executing the calculator.

Then try executing the other applications, they should fail to execute due to the App Locker policy that is applied to the Kiosk user.

When you are done, destroy the vagrant environment:

```bash
vagrant destroy -f
```

## References

* [Quickstart: configure a kiosk with Shell Launcher](https://learn.microsoft.com/en-us/windows/configuration/shell-launcher/quickstart-kiosk?tabs=ps)
* [Configure Shell Launcher](https://learn.microsoft.com/en-us/windows/configuration/shell-launcher/configure?tabs=powershell1%2Cintune)
  * [Shell Launcher XML Schema Definition (XSD)](https://learn.microsoft.com/en-us/windows/configuration/shell-launcher/xsd)
* [Unbranded Boot](https://learn.microsoft.com/en-us/windows/configuration/unbranded-boot/?tabs=powershell1%2Ccmd)
* [Keyboard Filter](https://learn.microsoft.com/en-us/windows/configuration/keyboard-filter/)
  * [Predefined key combinations](https://learn.microsoft.com/en-us/windows/configuration/keyboard-filter/predefined-key-combinations)
* [Application Control for Windows](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/)
  * [AppLocker](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/applocker-overview)
    * You can use the `Local Security Policy` editor to edit the current policy.
      * Select the `Security Settings` tree node.
      * Select the `Application Control Policies` tree node.
      * Select the `AppLocker` tree node.
      * Select the `Executable Rules` tree node.
      * On the right hand pane, right click to open the context menu, then select `Create Default Rules`.
        * See [Understanding AppLocker default rules](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/understanding-applocker-default-rules).
      * On the left hand pane, select the `AppLocker` tree node, then select `Export Policy...` to save the policy as a XML document file.
        * Or use the `Get-AppLockerPolicy -Local -Xml` cmdlet.
* Also see:
  * [AppLocker Guidance](https://github.com/nsacyber/applocker-guidance)
  * [UltimateAppLockerByPassList](https://github.com/api0cradle/UltimateAppLockerByPassList)
  * [WDAC Toolkit](https://github.com/MicrosoftDocs/WDAC-Toolkit)
