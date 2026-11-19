# Dokploy Local CLI Uninstaller for Windows for Windows PowerShell
# Run via: irm https://raw.githubusercontent.com/showayebDev/dokploy-local-cli/main/uninstall.ps1 | iex

$ErrorActionPreference = "SilentlyContinue"

Write-Host "`n=== Dokploy Local CLI Windows Uninstaller ===" -ForegroundColor Yellow
Write-Host "Uninstalling Dokploy Local CLI..." -ForegroundColor Yellow

$InstallDir = Join-Path $HOME ".local\bin"
$ConfigDir  = Join-Path $HOME ".config\dokploy-cli"

$Aliases = @("dok", "dk", "dokploy")
foreach ($name in $Aliases) {
    $binPath = Join-Path $InstallDir $name
    $cmdPath = Join-Path $InstallDir "$name.cmd"
    if (Test-Path $binPath) { Remove-Item -Force $binPath; Write-Host "  -> Removed $binPath" -ForegroundColor Cyan }
    if (Test-Path $cmdPath) { Remove-Item -Force $cmdPath; Write-Host "  -> Removed $cmdPath" -ForegroundColor Cyan }
}

if (Test-Path $ConfigDir) {
    Remove-Item -Recurse -Force $ConfigDir
    Write-Host "  -> Removed $ConfigDir" -ForegroundColor Cyan
}

Write-Host "`n✔ Dokploy Local CLI has been completely uninstalled from Windows.`n" -ForegroundColor Green
