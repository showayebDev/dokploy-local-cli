# Dokploy Local CLI Installer for Windows for Windows PowerShell
# Run via: irm https://raw.githubusercontent.com/showayebDev/dokploy-local-cli/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$CliName = "dok"
if ($args.Count -gt 0 -and $args[0] -and ($args[0] -notlike "-*")) {
    $CliName = $args[0]
}

function Write-Success ($msg) { Write-Host "✔ $msg" -ForegroundColor Green }
function Write-Info ($msg)    { Write-Host "  -> $msg" -ForegroundColor Cyan }
function Write-Warn ($msg)    { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Write-Err ($msg)     { Write-Host "Error: $msg" -ForegroundColor Red }

$InstallDir = Join-Path $HOME ".local\bin"
$ConfigDir  = Join-Path $HOME ".config\dokploy-cli"
$ConfigFile = Join-Path $ConfigDir "config"

# Handle Uninstall
$DoUninstall = ($args -contains "--uninstall") -or ($args -contains "-u") -or ($env:DOK_UNINSTALL -eq "1") -or ($env:UNINSTALL -eq "1")
if ($DoUninstall) {
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
    Remove-Item env:DOK_UNINSTALL -ErrorAction SilentlyContinue
    Remove-Item env:UNINSTALL -ErrorAction SilentlyContinue
    return
}

Write-Host ""
Write-Host "=== Dokploy Local CLI Windows Installer ===" -ForegroundColor Cyan
Write-Host "Target command name: $CliName"
Write-Host ""

# Check for Git Bash (bash.exe)
$GitBashPath = "$env:ProgramFiles\Git\bin\bash.exe"
if (-not (Test-Path $GitBashPath)) {
    $bashCmd = Get-Command "bash.exe" -ErrorAction SilentlyContinue
    if ($bashCmd) {
        $GitBashPath = $bashCmd.Source
    } else {
        $gitCmd = Get-Command "git.exe" -ErrorAction SilentlyContinue
        if ($gitCmd) {
            $possibleBash = Join-Path (Split-Path (Split-Path $gitCmd.Source)) "bin\bash.exe"
            if (Test-Path $possibleBash) { $GitBashPath = $possibleBash }
        }
    }
}

if (-not (Test-Path $GitBashPath)) {
    Write-Err "Git Bash is required to run the CLI on Windows."
    Write-Host "Please install Git for Windows from: https://git-scm.com/download/win"
    return
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
    $ReleaseUrl = "https://github.com/showayebDev/dokploy-local-cli/releases/latest/download/dok"
    $RawUrl = "https://raw.githubusercontent.com/showayebDev/dokploy-local-cli/main/dok"
    Write-Info "Downloading CLI script from GitHub..."
    $Downloaded = $false
    if (Get-Command "curl.exe" -ErrorAction SilentlyContinue) {
        & curl.exe -fsSL "$ReleaseUrl" -o "$TargetBin" 2>$null
        if ((Test-Path $TargetBin) -and (Get-Item $TargetBin).Length -gt 1000) { $Downloaded = $true }
    }
    if (-not $Downloaded) {
        try {
            Invoke-WebRequest -Uri $ReleaseUrl -OutFile $TargetBin -UseBasicParsing -ErrorAction Stop
            $Downloaded = $true
        } catch {
            Invoke-WebRequest -Uri $RawUrl -OutFile $TargetBin -UseBasicParsing -ErrorAction Stop
            $Downloaded = $true
        }
    }
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
    $cmdLines = @(
        '@echo off',
        'setlocal',
        'set "SCRIPT_DIR=%~dp0"',
        'if exist "%ProgramFiles%\Git\bin\bash.exe" (',
        ("    `"%ProgramFiles%\Git\bin\bash.exe`" `"`%SCRIPT_DIR`%{0}`" `%* & goto :eof" -f $cmdName),
        ')',
        ("bash `"`%SCRIPT_DIR`%{0}`" `%* & goto :eof" -f $cmdName)
    )
    $cmdContent = $cmdLines -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($cmdFile, $cmdContent, [System.Text.Encoding]::ASCII)
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
    $configLines = @(
        ("CLI_NAME=`"{0}`"" -f $CliName),
        'CONTAINER_ENGINE="auto"',
        'DOKPLOY_PORT=3000',
        'DOKPLOY_NETWORK="dokploy-network"',
        'STATE_DIR="$HOME/.cache/dokploy"'
    )
    $ConfigContent = $configLines -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($ConfigFile, $ConfigContent, [System.Text.Encoding]::ASCII)
    Write-Info "Configuration saved: $ConfigFile"
}

Write-Host ""
Write-Host "✔ Installation successful on Windows!" -ForegroundColor Green
Write-Host "You can now run commands directly in any PowerShell or CMD terminal:"
Write-Host ""
Write-Host "  dok start         # Start Dokploy core + Traefik" -ForegroundColor Cyan
Write-Host "  dok status        # Check status & web dashboard URL" -ForegroundColor Cyan
Write-Host "  dok open          # Open dashboard in browser" -ForegroundColor Cyan
Write-Host "  dok stop          # Stop Dokploy to free CPU & RAM" -ForegroundColor Cyan
Write-Host "  dok reset -f      # Completely reset database & containers" -ForegroundColor Cyan
Write-Host ""
Write-Host "Both 'dok' and 'dk' are available out of the box!" -ForegroundColor Green
Write-Host ""

if ($args -contains "--install-dokploy" -or $env:INSTALL_DOKPLOY -eq "1") {
    & "$InstallDir\dok.cmd" install-dokploy
}
