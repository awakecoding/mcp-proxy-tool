# Chocolatey Uninstall Script Template for mcp-proxy-tool
#
# This script cleans up the mcp-proxy-tool installation

$ErrorActionPreference = 'Stop'

$packageName = 'mcp-proxy-tool'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

Write-Host "Uninstalling $packageName..." -ForegroundColor Yellow

# Remove the executable
$exePath = Join-Path $toolsDir 'mcp-proxy-tool.exe'
if (Test-Path $exePath) {
    Remove-Item $exePath -Force
    Write-Host "🗑️  Removed: $exePath" -ForegroundColor Green
}

# Clean up any other files that might have been created
$filesToRemove = @(
    'mcp-proxy-tool.exe'
)

foreach ($file in $filesToRemove) {
    $filePath = Join-Path $toolsDir $file
    if (Test-Path $filePath) {
        Remove-Item $filePath -Force
        Write-Host "🗑️  Removed: $filePath" -ForegroundColor Green
    }
}

Write-Host "✅ $packageName uninstalled successfully!" -ForegroundColor Green
