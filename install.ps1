<#
.SYNOPSIS
    Dokploy Local CLI Installer for Windows (PowerShell)
.DESCRIPTION
    Installs the Dokploy Local CLI on Windows and configures PowerShell
    and Command Prompt (CMD) wrappers (dok.cmd, dk.cmd, dokploy.cmd).
.EXAMPLE
    irm https://raw.githubusercontent.com/showayebDev/dokploy-local-cli/main/install.ps1 | iex
#>

[CmdletBinding()]
param (
    [string]$CliName = "dok",
    [switch]$Uninstall,
    [switch]$InstallDokploy
)

$ErrorActionPreference = "Stop"

function Write-Success ($msg) { Write-Host "✔ $msg" -ForegroundColor Green }
function Write-Info ($msg)    { Write-Host "  -> $msg" -ForegroundColor Cyan }
function Write-Warn ($msg)    { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Write-Err ($msg)     { Write-Host "Error: $msg" -ForegroundColor Red }

$InstallDir = Join-Path $HOME ".local\bin"
$ConfigDir  = Join-Path $HOME ".config\dokploy-cli"
$ConfigFile = Join-Path $ConfigDir "config"

# Handle Uninstall
if ($Uninstall) {
    Write-Host "Uninstalling Dokploy Local CLI..." -ForegroundColor Yellow
    $Aliases = @("dok", "dk", "dokploy", $CliName) | Select-Object -Unique
    foreach ($name in $Aliases) {
        $binPath = Join-Path $InstallDir $name
        $cmdPath = Join-Path $InstallDir "$name.cmd"
        if (Test-Path $binPath) { Remove-Item -Force $binPath; Write-Info "Removed $binPath" }
        if (Test-Path $cmdPath) { Remove-Item -Force $cmdPath; Write-Info "Removed $cmdPath" }
    }
    if (Test-Path $ConfigDir) {
        Remove-Item -Recurse -Force $ConfigDir
        Write-Info "Removed $ConfigDir"
    }
    Write-Success "Dokploy Local CLI has been completely uninstalled."
    exit 0
}

Write-Host "`n=== Dokploy Local CLI Windows Installer ===" -ForegroundColor Cyan
Write-Host "Target command name: $CliName`n"

# Check for Git Bash (bash.exe)
$GitBashPath = "$env:ProgramFiles\Git\bin\bash.exe"
if (-not (Test-Path $GitBashPath)) {
    $bashCmd = Get-Command "bash.exe" -ErrorAction SilentlyContinue
    if ($bashCmd) {
        $GitBashPath = $bashCmd.Source
    } else {
        Write-Err "Git Bash is required to run the CLI on Windows."
        Write-Host "Please install Git for Windows from: https://git-scm.com/download/win"
        exit 1
    }
}
Write-Info "Found Bash engine: $GitBashPath"

# Ensure Install Directory exists
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# Locate or Download 'dok' script
$SourceBin = if ($PSScriptRoot) { Join-Path $PSScriptRoot "dok" } else { "" }
$TargetBin = Join-Path $InstallDir $CliName

if ($SourceBin -and (Test-Path $SourceBin)) {
    Write-Info "Installing from local source: $SourceBin"
    Copy-Item -Path $SourceBin -Destination $TargetBin -Force
} else {
    $RawUrl = "https://raw.githubusercontent.com/showayebDev/dokploy-local-cli/main/dok"
    Write-Info "Downloading CLI script from GitHub..."
    Invoke-WebRequest -Uri $RawUrl -OutFile $TargetBin -UseBasicParsing
}

# Create convenience copies for aliases (dok, dk, dokploy)
$Aliases = @("dok", "dk", "dokploy")
foreach ($aliasName in $Aliases) {
    $aliasPath = Join-Path $InstallDir $aliasName
    if ($aliasName -ne $CliName) {
        Copy-Item -Path $TargetBin -Destination $aliasPath -Force
    }
}

# Create .cmd wrappers for PowerShell and Command Prompt
Write-Info "Generating PowerShell and CMD batch wrappers..."
$AllTargets = @($Aliases + $CliName) | Select-Object -Unique
foreach ($cmdName in $AllTargets) {
    $cmdFile = Join-Path $InstallDir "$cmdName.cmd"
    $cmdContent = @"
@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
if exist "%ProgramFiles%\Git\bin\bash.exe" (
    "%ProgramFiles%\Git\bin\bash.exe" "%SCRIPT_DIR%$cmdName" %*
) else (
    bash "%SCRIPT_DIR%$cmdName" %*
)
"@
    Set-Content -Path $cmdFile -Value $cmdContent -Encoding ASCII
    Write-Info "Wrapper created: $cmdFile"
}

# Check & Configure Windows User PATH
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    Write-Warn "Adding $InstallDir to User PATH..."
    $NewPath = "$InstallDir;$UserPath"
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
    $env:Path = "$InstallDir;$env:Path"
    Write-Success "Added $InstallDir to User PATH."
} else {
    Write-Success "$InstallDir is already in PATH."
}

# Create Default Config
if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}
if (-not (Test-Path $ConfigFile)) {
    $ConfigContent = @"
CLI_NAME="$CliName"
CONTAINER_ENGINE="auto"
DOKPLOY_PORT=3000
DOKPLOY_NETWORK="dokploy-network"
STATE_DIR="`$HOME/.cache/dokploy"
"@
    Set-Content -Path $ConfigFile -Value $ConfigContent -Encoding ASCII
    Write-Info "Configuration saved: $ConfigFile"
}

Write-Host "`n✔ Installation successful on Windows!" -ForegroundColor Green
Write-Host "You can now run commands directly in any PowerShell or CMD terminal:`n"
Write-Host "  dok start         # Start Dokploy core + Traefik" -ForegroundColor Cyan
Write-Host "  dok status        # Check status & web dashboard URL" -ForegroundColor Cyan
Write-Host "  dok open          # Open dashboard in browser" -ForegroundColor Cyan
Write-Host "  dok stop          # Stop Dokploy to free CPU & RAM" -ForegroundColor Cyan
Write-Host "  dok reset -f      # Completely reset database & containers`n" -ForegroundColor Cyan
Write-Host "Both 'dok' and 'dk' are available out of the box!`n" -ForegroundColor Green

if ($InstallDokploy) {
    & "$InstallDir\dok.cmd" install-dokploy
}
