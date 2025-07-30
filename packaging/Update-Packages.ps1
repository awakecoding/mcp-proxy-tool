#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Updates packaging manifests for mcp-proxy-tool releases
.DESCRIPTION
    Cross-platform PowerShell script that generates Homebrew and Winget manifests
    from templates using actual release data from GitHub releases.
.PARAMETER Version
    Version number (e.g., "0.1.0")
.PARAMETER ReleaseTag
    Release tag (defaults to "v$Version")
.PARAMETER ChecksumsFile
    Path to checksums.txt file (downloads if not provided)
.PARAMETER OutputDir
    Directory to output generated manifests (defaults to ./generated/)
.PARAMETER SubmitHomebrew
    Generate Homebrew submission files
.PARAMETER SubmitWinget
    Generate Winget submission files
.PARAMETER SubmitChocolatey
    Generate Chocolatey submission files
.EXAMPLE
    ./Update-Packages.ps1 -Version "0.1.0"
.EXAMPLE
    ./Update-Packages.ps1 -Version "0.1.0" -SubmitHomebrew -SubmitWinget -SubmitChocolatey
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter(Mandatory = $false)]
    [string]$ReleaseTag,
    
    [Parameter(Mandatory = $false)]
    [string]$ChecksumsFile,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "./generated",
    
    [Parameter(Mandatory = $false)]
    [switch]$SubmitHomebrew,
    
    [Parameter(Mandatory = $false)]
    [switch]$SubmitWinget,
    
    [Parameter(Mandatory = $false)]
    [switch]$SubmitChocolatey
)

# Set error handling
$ErrorActionPreference = "Stop"

# Determine release tag
if (-not $ReleaseTag) {
    $ReleaseTag = "v$Version"
}

Write-Host "🚀 Updating packaging manifests for version $Version (tag: $ReleaseTag)" -ForegroundColor Green

# Create output directory
$OutputPath = Join-Path $PSScriptRoot $OutputDir
# Normalize the path to remove any "./" components
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "📁 Created output directory: $OutputPath" -ForegroundColor Blue
}

# Download checksums if not provided
if (-not $ChecksumsFile) {
    Write-Host "📥 Downloading checksums.txt from GitHub release..." -ForegroundColor Yellow
    
    # Use cross-platform temp directory
    if ($IsWindows) {
        $tempDir = $env:TEMP
    } else {
        $tempDir = "/tmp"
    }
    
    $ChecksumsFile = Join-Path $tempDir "checksums.txt"
    
    # Remove existing file if present
    if (Test-Path $ChecksumsFile) {
        Remove-Item $ChecksumsFile -Force
    }
    
    try {
        & gh release download $ReleaseTag -p "checksums.txt" -D $tempDir
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to download checksums.txt"
        }
    }
    catch {
        Write-Error "Failed to download checksums from release $ReleaseTag. Make sure the release exists and you're authenticated with gh CLI."
        exit 1
    }
}

# Verify checksums file exists
if (-not (Test-Path $ChecksumsFile)) {
    Write-Error "Checksums file not found: $ChecksumsFile"
    exit 1
}

Write-Host "📊 Reading checksums from: $ChecksumsFile" -ForegroundColor Blue

# Parse checksums file
$checksums = @{}
$checksumContent = Get-Content $ChecksumsFile
foreach ($line in $checksumContent) {
    if ($line -match '^([A-F0-9]+)\s+(.+)$') {
        $hash = $Matches[1]
        $filename = $Matches[2]
        $checksums[$filename] = $hash
    }
}

# Extract platform-specific checksums
$platformChecksums = @{
    "linux-x64"     = $checksums["mcp-proxy-tool-linux-x64.zip"]
    "linux-arm64"   = $checksums["mcp-proxy-tool-linux-arm64.zip"]
    "macos-x64"     = $checksums["mcp-proxy-tool-macos-x64.zip"]
    "macos-arm64"   = $checksums["mcp-proxy-tool-macos-arm64.zip"]
    "windows-x64"   = $checksums["mcp-proxy-tool-windows-x64.zip"]
    "windows-arm64" = $checksums["mcp-proxy-tool-windows-arm64.zip"]
}

# Verify all checksums were found
$missingChecksums = @()
foreach ($platform in $platformChecksums.Keys) {
    if (-not $platformChecksums[$platform]) {
        $missingChecksums += $platform
    }
}

if ($missingChecksums.Count -gt 0) {
    Write-Error "Missing checksums for platforms: $($missingChecksums -join ', ')"
    exit 1
}

Write-Host "✅ Extracted checksums:" -ForegroundColor Green
foreach ($platform in $platformChecksums.Keys) {
    Write-Host "  $platform`: $($platformChecksums[$platform])" -ForegroundColor Cyan
}

# Generate Homebrew formula
Write-Host "🍺 Generating Homebrew formula..." -ForegroundColor Magenta

$homebrewTemplate = Join-Path $PSScriptRoot "homebrew-formula-template.rb"
if (-not (Test-Path $homebrewTemplate)) {
    Write-Error "Homebrew template not found: $homebrewTemplate"
    exit 1
}

$homebrewContent = Get-Content $homebrewTemplate -Raw

# Replace placeholders in Homebrew formula
$homebrewContent = $homebrewContent -replace 'version "\{VERSION\}"', "version `"$Version`""
$homebrewContent = $homebrewContent -replace 'version "[^"]*" # Updated to current version from Cargo\.toml', "version `"$Version`""
$homebrewContent = $homebrewContent -replace '\{SHA256_LINUX_X64\}', $platformChecksums["linux-x64"]
$homebrewContent = $homebrewContent -replace '\{SHA256_LINUX_ARM64\}', $platformChecksums["linux-arm64"]
$homebrewContent = $homebrewContent -replace '\{SHA256_MACOS_X64\}', $platformChecksums["macos-x64"]
$homebrewContent = $homebrewContent -replace '\{SHA256_MACOS_ARM64\}', $platformChecksums["macos-arm64"]

# Clean up any remaining placeholder comments
$homebrewContent = $homebrewContent -replace ' # Replace with actual SHA256.*', ""

$homebrewOutput = Join-Path $OutputPath "mcp-proxy-tool.rb"
$homebrewContent | Set-Content $homebrewOutput -Encoding UTF8
Write-Host "  ✓ Generated: $homebrewOutput" -ForegroundColor Green

# Generate Winget manifests (multi-file format)
Write-Host "🪟 Generating Winget manifests..." -ForegroundColor Magenta

# Get current date for release date
$releaseDate = Get-Date -Format "yyyy-MM-dd"

# Generate version manifest
$wingetVersionTemplate = Join-Path $PSScriptRoot "winget-version-template.yaml"
if (-not (Test-Path $wingetVersionTemplate)) {
    Write-Error "Winget version template not found: $wingetVersionTemplate"
    exit 1
}

$versionContent = Get-Content $wingetVersionTemplate -Raw
$versionContent = $versionContent -replace '\{VERSION\}', $Version

$versionOutput = Join-Path $OutputPath "awakecoding.mcp-proxy-tool.yaml"
$versionContent | Set-Content $versionOutput -Encoding UTF8
Write-Host "  ✓ Generated: $versionOutput" -ForegroundColor Green

# Generate installer manifest
$wingetInstallerTemplate = Join-Path $PSScriptRoot "winget-installer-template.yaml"
if (-not (Test-Path $wingetInstallerTemplate)) {
    Write-Error "Winget installer template not found: $wingetInstallerTemplate"
    exit 1
}

$installerContent = Get-Content $wingetInstallerTemplate -Raw
$installerContent = $installerContent -replace '\{VERSION\}', $Version
$installerContent = $installerContent -replace '\{SHA256_WINDOWS_X64\}', $platformChecksums["windows-x64"]
$installerContent = $installerContent -replace '\{SHA256_WINDOWS_ARM64\}', $platformChecksums["windows-arm64"]

$installerOutput = Join-Path $OutputPath "awakecoding.mcp-proxy-tool.installer.yaml"
$installerContent | Set-Content $installerOutput -Encoding UTF8
Write-Host "  ✓ Generated: $installerOutput" -ForegroundColor Green

# Generate locale manifest
$wingetLocaleTemplate = Join-Path $PSScriptRoot "winget-locale-template.yaml"
if (-not (Test-Path $wingetLocaleTemplate)) {
    Write-Error "Winget locale template not found: $wingetLocaleTemplate"
    exit 1
}

$localeContent = Get-Content $wingetLocaleTemplate -Raw
$localeContent = $localeContent -replace '\{VERSION\}', $Version
$localeContent = $localeContent -replace '\{RELEASE_DATE\}', $releaseDate

$localeOutput = Join-Path $OutputPath "awakecoding.mcp-proxy-tool.locale.en-US.yaml"
$localeContent | Set-Content $localeOutput -Encoding UTF8
Write-Host "  ✓ Generated: $localeOutput" -ForegroundColor Green

# Generate Chocolatey package
Write-Host "🍫 Generating Chocolatey package..." -ForegroundColor Magenta

# Generate nuspec file
$chocolateyNuspecTemplate = Join-Path $PSScriptRoot "chocolatey-template.nuspec"
if (-not (Test-Path $chocolateyNuspecTemplate)) {
    Write-Error "Chocolatey nuspec template not found: $chocolateyNuspecTemplate"
    exit 1
}

$nuspecContent = Get-Content $chocolateyNuspecTemplate -Raw
$nuspecContent = $nuspecContent -replace '\{VERSION\}', $Version

$nuspecOutput = Join-Path $OutputPath "mcp-proxy-tool.nuspec"
$nuspecContent | Set-Content $nuspecOutput -Encoding UTF8
Write-Host "  ✓ Generated: $nuspecOutput" -ForegroundColor Green

# Generate chocolateyInstall.ps1
$chocolateyInstallTemplate = Join-Path $PSScriptRoot "chocolateyinstall-template.ps1"
if (-not (Test-Path $chocolateyInstallTemplate)) {
    Write-Error "Chocolatey install template not found: $chocolateyInstallTemplate"
    exit 1
}

$installContent = Get-Content $chocolateyInstallTemplate -Raw
$installContent = $installContent -replace '\{VERSION\}', $Version
$installContent = $installContent -replace '\{SHA256_X64\}', $platformChecksums["windows-x64"]
$installContent = $installContent -replace '\{SHA256_ARM64\}', $platformChecksums["windows-arm64"]

$installOutput = Join-Path $OutputPath "chocolateyInstall.ps1"
$installContent | Set-Content $installOutput -Encoding UTF8
Write-Host "  ✓ Generated: $installOutput" -ForegroundColor Green

# Generate chocolateyUninstall.ps1
$chocolateyUninstallTemplate = Join-Path $PSScriptRoot "chocolateyuninstall-template.ps1"
if (-not (Test-Path $chocolateyUninstallTemplate)) {
    Write-Error "Chocolatey uninstall template not found: $chocolateyUninstallTemplate"
    exit 1
}

$uninstallContent = Get-Content $chocolateyUninstallTemplate -Raw
$uninstallOutput = Join-Path $OutputPath "chocolateyUninstall.ps1"
$uninstallContent | Set-Content $uninstallOutput -Encoding UTF8
Write-Host "  ✓ Generated: $uninstallOutput" -ForegroundColor Green

# Generate submission instructions
$instructionsOutput = Join-Path $OutputPath "SUBMISSION_INSTRUCTIONS.md"
$instructions = @"
# Package Submission Instructions for v$Version

Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Homebrew Submission

### Option 1: Custom Tap (Recommended for initial releases)
1. Create/update repository: ``https://github.com/awakecoding/homebrew-tap``
2. Copy ``mcp-proxy-tool.rb`` to ``Formula/mcp-proxy-tool.rb``
3. Commit and push
4. Users install with: ``brew tap awakecoding/tap && brew install mcp-proxy-tool``

### Option 2: Homebrew Core (Requires significant usage)
1. Fork: ``https://github.com/Homebrew/homebrew-core``
2. Copy ``mcp-proxy-tool.rb`` to ``Formula/mcp-proxy-tool.rb``
3. Submit pull request following Homebrew guidelines

## Winget Submission

1. Fork: ``https://github.com/microsoft/winget-pkgs``
2. Create directory: ``manifests/a/awakecoding/mcp-proxy-tool/$Version/``
3. Copy ``awakecoding.mcp-proxy-tool.yaml`` to the created directory
4. Submit pull request following Winget guidelines

## Chocolatey Submission

1. Create account at: ``https://chocolatey.org/``
2. Install Chocolatey CLI: ``choco install chocolatey-cli``
3. Create package directory structure:
   - ``tools/chocolateyInstall.ps1``
   - ``tools/chocolateyUninstall.ps1``
   - ``mcp-proxy-tool.nuspec``
4. Test locally: ``choco pack && choco install mcp-proxy-tool -source .``
5. Push to Chocolatey: ``choco push mcp-proxy-tool.$Version.nupkg``

## Verification Commands

### Test Homebrew Formula
``````bash
# Local testing
brew install --build-from-source ./mcp-proxy-tool.rb
mcp-proxy-tool --help

# Test different architectures
brew uninstall mcp-proxy-tool
brew install ./mcp-proxy-tool.rb
``````

### Test Winget Manifest
``````powershell
# Local testing (Windows)
winget install --manifest awakecoding.mcp-proxy-tool.yaml
mcp-proxy-tool --help
``````

### Test Chocolatey Package
``````powershell
# Local testing (Windows)
choco pack
choco install mcp-proxy-tool -source .
mcp-proxy-tool --help
``````

## Generated Files
- ``mcp-proxy-tool.rb`` - Homebrew formula
- ``awakecoding.mcp-proxy-tool.yaml`` - Winget manifest
- ``mcp-proxy-tool.nuspec`` - Chocolatey package manifest
- ``chocolateyInstall.ps1`` - Chocolatey install script
- ``chocolateyUninstall.ps1`` - Chocolatey uninstall script
- ``SUBMISSION_INSTRUCTIONS.md`` - This file

## Checksums Used
"@

foreach ($platform in $platformChecksums.Keys) {
    $instructions += "- $platform`: $($platformChecksums[$platform])`n"
}

$instructions | Set-Content $instructionsOutput -Encoding UTF8
Write-Host "  ✓ Generated: $instructionsOutput" -ForegroundColor Green

# Optional: Prepare submission directories
if ($SubmitHomebrew) {
    Write-Host "🍺 Preparing Homebrew submission structure..." -ForegroundColor Magenta
    $homebrewDir = Join-Path $OutputPath "homebrew-submission"
    $formulaDir = Join-Path $homebrewDir "Formula"
    New-Item -ItemType Directory -Path $formulaDir -Force | Out-Null
    Copy-Item $homebrewOutput (Join-Path $formulaDir "mcp-proxy-tool.rb")
    Write-Host "  ✓ Homebrew submission ready in: $homebrewDir" -ForegroundColor Green
}

if ($SubmitWinget) {
    Write-Host "🪟 Preparing Winget submission structure..." -ForegroundColor Magenta
    $wingetDir = Join-Path $OutputPath "winget-submission"
    $manifestDir = Join-Path $wingetDir "manifests/a/awakecoding/mcp-proxy-tool/$Version"
    New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
    
    # Copy all three manifest files
    Copy-Item $versionOutput (Join-Path $manifestDir "awakecoding.mcp-proxy-tool.yaml")
    Copy-Item $installerOutput (Join-Path $manifestDir "awakecoding.mcp-proxy-tool.installer.yaml")
    Copy-Item $localeOutput (Join-Path $manifestDir "awakecoding.mcp-proxy-tool.locale.en-US.yaml")
    
    Write-Host "  ✓ Winget submission ready in: $wingetDir" -ForegroundColor Green
}

if ($SubmitChocolatey) {
    Write-Host "🍫 Preparing Chocolatey submission structure..." -ForegroundColor Magenta
    $chocolateyDir = Join-Path $OutputPath "chocolatey-submission"
    $toolsDir = Join-Path $chocolateyDir "tools"
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    
    # Copy files to proper locations
    Copy-Item $nuspecOutput (Join-Path $chocolateyDir "mcp-proxy-tool.nuspec")
    Copy-Item $installOutput (Join-Path $toolsDir "chocolateyInstall.ps1")
    Copy-Item $uninstallOutput (Join-Path $toolsDir "chocolateyUninstall.ps1")
    
    Write-Host "  ✓ Chocolatey submission ready in: $chocolateyDir" -ForegroundColor Green
    Write-Host "  📦 Run 'choco pack' in the chocolatey-submission directory" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 Package manifests generated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Summary:" -ForegroundColor Yellow
Write-Host "  Version: $Version" -ForegroundColor Cyan
Write-Host "  Output directory: $OutputPath" -ForegroundColor Cyan
Write-Host "  Generated files:" -ForegroundColor Cyan
Write-Host "    - mcp-proxy-tool.rb (Homebrew)" -ForegroundColor Cyan
Write-Host "    - awakecoding.mcp-proxy-tool.yaml (Winget)" -ForegroundColor Cyan
Write-Host "    - mcp-proxy-tool.nuspec (Chocolatey)" -ForegroundColor Cyan
Write-Host "    - chocolateyInstall.ps1 (Chocolatey)" -ForegroundColor Cyan
Write-Host "    - chocolateyUninstall.ps1 (Chocolatey)" -ForegroundColor Cyan
Write-Host "    - SUBMISSION_INSTRUCTIONS.md (Guide)" -ForegroundColor Cyan
Write-Host ""
Write-Host "📖 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review generated manifests in: $OutputPath" -ForegroundColor White
Write-Host "  2. Follow instructions in SUBMISSION_INSTRUCTIONS.md" -ForegroundColor White
Write-Host "  3. Submit to respective package repositories" -ForegroundColor White
Write-Host ""
