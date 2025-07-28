# Release preparation script for mcp-proxy-tool
# This script helps prepare package manager manifests after a GitHub release

param(
    [Parameter(Mandatory=$true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

# Configuration
$Repo = "awakecoding/mcp-proxy-tool"
$ReleaseUrl = "https://github.com/$Repo/releases/download/v$Version"
$TempDir = Join-Path $env:TEMP "mcp-proxy-tool-release-$Version"

Write-Host "Preparing release manifests for version $Version" -ForegroundColor Green
Write-Host "Working directory: $TempDir" -ForegroundColor Cyan

# Create temp directory
if (Test-Path $TempDir) {
    Remove-Item $TempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

# Define artifacts with user-friendly names
$Artifacts = @(
    "windows-x64.zip",
    "windows-arm64.zip", 
    "macos-x64.tar.gz",
    "macos-arm64.tar.gz",
    "linux-x64.tar.gz",
    "linux-arm64.tar.gz"
)

# Download artifacts and calculate checksums
Write-Host "`nDownloading release artifacts..." -ForegroundColor Yellow
$Checksums = @{}

foreach ($artifact in $Artifacts) {
    $filename = "mcp-proxy-tool-$artifact"
    $url = "$ReleaseUrl/$filename"
    $filePath = Join-Path $TempDir $filename
    
    Write-Host "Downloading $filename..." -ForegroundColor Cyan
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $filePath -UseBasicParsing
        $hash = Get-FileHash $filePath -Algorithm SHA256
        $Checksums[$artifact] = $hash.Hash.ToLower()
        Write-Host "✓ $filename`: $($hash.Hash.ToLower())" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to download $filename`: $($_.Exception.Message)"
        exit 1
    }
}

# Generate Winget manifest
Write-Host "`nGenerating Winget manifest..." -ForegroundColor Yellow
$WingetManifest = "packaging\winget-manifest-v$Version.yaml"

if (Test-Path "packaging\winget-manifest-template.yaml") {
    $wingetContent = Get-Content "packaging\winget-manifest-template.yaml" -Raw
    $currentDate = Get-Date -Format "yyyy-MM-dd"
    
    $wingetContent = $wingetContent -replace '\{VERSION\}', $Version
    $wingetContent = $wingetContent -replace '\{RELEASE_DATE\}', $currentDate
    $wingetContent = $wingetContent -replace '\{SHA256_X64\}', $Checksums["windows-x64.zip"]
    $wingetContent = $wingetContent -replace '\{SHA256_ARM64\}', $Checksums["windows-arm64.zip"]
    
    Set-Content -Path $WingetManifest -Value $wingetContent
    Write-Host "✓ Winget manifest created: $WingetManifest" -ForegroundColor Green
}
else {
    Write-Warning "Winget template not found: packaging\winget-manifest-template.yaml"
}

# Generate Homebrew formula
Write-Host "`nGenerating Homebrew formula..." -ForegroundColor Yellow
$HomebrewFormula = "packaging\homebrew-formula-v$Version.rb"

if (Test-Path "packaging\homebrew-formula-template.rb") {
    $homebrewContent = Get-Content "packaging\homebrew-formula-template.rb" -Raw
    
    $homebrewContent = $homebrewContent -replace '\{VERSION\}', $Version
    $homebrewContent = $homebrewContent -replace '\{SHA256_MACOS_X64\}', $Checksums["macos-x64.tar.gz"]
    $homebrewContent = $homebrewContent -replace '\{SHA256_MACOS_ARM64\}', $Checksums["macos-arm64.tar.gz"]
    $homebrewContent = $homebrewContent -replace '\{SHA256_LINUX_X64\}', $Checksums["linux-x64.tar.gz"]
    $homebrewContent = $homebrewContent -replace '\{SHA256_LINUX_ARM64\}', $Checksums["linux-arm64.tar.gz"]
    
    Set-Content -Path $HomebrewFormula -Value $homebrewContent
    Write-Host "✓ Homebrew formula created: $HomebrewFormula" -ForegroundColor Green
}
else {
    Write-Warning "Homebrew template not found: packaging\homebrew-formula-template.rb"
}

# Cleanup
Remove-Item $TempDir -Recurse -Force

Write-Host "`n🎉 Release preparation complete!" -ForegroundColor Green

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Review the generated files:" -ForegroundColor White
Write-Host "   - $WingetManifest" -ForegroundColor Gray
Write-Host "   - $HomebrewFormula" -ForegroundColor Gray
Write-Host ""
Write-Host "2. For Winget submission:" -ForegroundColor White
Write-Host "   - Fork https://github.com/microsoft/winget-pkgs" -ForegroundColor Gray
Write-Host "   - Create manifests/a/awakecoding/mcp-proxy-tool/$Version/" -ForegroundColor Gray
Write-Host "   - Copy the manifest content and submit a PR" -ForegroundColor Gray
Write-Host ""
Write-Host "3. For Homebrew:" -ForegroundColor White
Write-Host "   - Create a tap repository (homebrew-tap)" -ForegroundColor Gray
Write-Host "   - Add the formula to Formula/mcp-proxy-tool.rb" -ForegroundColor Gray
Write-Host "   - Or submit to homebrew-core if the tool gains popularity" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Update your README.md with installation instructions" -ForegroundColor White
