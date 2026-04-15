$url = "https://github.com/rgl/windows-kiosk-test-app/releases/download/v0.0.3/WindowsKioskTestApp.zip"
$localZipPath = "$env:TEMP\WindowsKioskTestApp.zip"
$destinationPath = "C:\Program Files\WindowsKioskTestApp"
(New-Object System.Net.WebClient).DownloadFile($url, $localZipPath)
if (Test-Path $destinationPath) {
    Remove-Item -Recurse -Force $destinationPath
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($localZipPath, $destinationPath)
Remove-Item $localZipPath
