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
