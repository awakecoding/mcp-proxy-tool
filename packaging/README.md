# Package Distribution Templates

This directory contains templates and tools for distributing `mcp-proxy-tool` through various package managers.

## 📦 Available Package Managers

### 🍺 Homebrew (macOS & Linux)
- **File**: `homebrew-formula-template.rb`
- **Platforms**: macOS (ARM64/x64), Linux (ARM64/x64)
- **Installation**: `brew install mcp-proxy-tool` (via custom tap)

### 📦 Winget (Windows)
- **Files**: 
  - `winget-version-template.yaml` (version manifest)
  - `winget-installer-template.yaml` (installer details)
  - `winget-locale-template.yaml` (localization)
- **Platforms**: Windows (ARM64/x64)
- **Installation**: `winget install awakecoding.mcp-proxy-tool`

### 🍫 Chocolatey (Windows)
- **File**: `chocolatey-template.nuspec` + install/uninstall scripts
- **Platforms**: Windows (ARM64/x64)
- **Installation**: `choco install mcp-proxy-tool`

## 🛠️ Quick Update

Use the automated script to update templates with new release information:

```powershell
cd packaging/
pwsh ./Update-Packages.ps1 -Version "0.1.0"
```

This will:
1. Download `checksums.txt` from the GitHub release
2. Extract SHA256 values for all platforms
3. Update Homebrew, Winget, and Chocolatey templates
4. Generate release-specific manifests in `generated/` directory

## 📋 Manual Process

### For Homebrew

1. Update the formula template with new version and checksums
2. Create/update your Homebrew tap repository
3. Test installation: `brew install your-tap/mcp-proxy-tool`

### For Winget

1. Update the manifest template with new version and checksums
2. Fork the [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) repository
3. Create manifest under `manifests/a/awakecoding/mcp-proxy-tool/{version}/`
4. Submit a pull request

### For Chocolatey

1. Update the package templates with new version and checksums
2. Create account at [chocolatey.org](https://chocolatey.org/)
3. Test locally: `choco pack && choco install mcp-proxy-tool -source .`
4. Push to Chocolatey: `choco push mcp-proxy-tool.{version}.nupkg`

## 🔍 Release Artifact Mapping

Our CI/CD creates the following artifacts:

| Platform | Architecture | Artifact Name | Binary Name |
|----------|-------------|---------------|-------------|
| macOS | x64 | `mcp-proxy-tool-macos-x64.zip` | `mcp-proxy-tool` |
| macOS | ARM64 | `mcp-proxy-tool-macos-arm64.zip` | `mcp-proxy-tool` |
| Linux | x64 | `mcp-proxy-tool-linux-x64.zip` | `mcp-proxy-tool` |
| Linux | ARM64 | `mcp-proxy-tool-linux-arm64.zip` | `mcp-proxy-tool` |
| Windows | x64 | `mcp-proxy-tool-windows-x64.zip` | `mcp-proxy-tool.exe` |
| Windows | ARM64 | `mcp-proxy-tool-windows-arm64.zip` | `mcp-proxy-tool.exe` |

## ✅ Verification

### Homebrew Formula
```bash
# Test the formula
brew install --build-from-source ./homebrew-formula-template.rb
mcp-proxy-tool --help
```

### Winget Manifest
```bash
# Validate manifests (requires all 3 files in a directory)
winget validate --manifest path/to/manifest/directory/
```

### Chocolatey Package
```powershell
# Test the package
choco pack
choco install mcp-proxy-tool -source .
mcp-proxy-tool --help
```

## 📝 Current Status

- ✅ **Templates Updated**: Synced with v0.1.0 release artifacts
- ✅ **Binary Names**: Verified (Unix: `mcp-proxy-tool`, Windows: `mcp-proxy-tool.exe`)
- ✅ **Zip Structure**: Fixed - binaries at root level
- ✅ **Permissions**: Preserved for Unix platforms
- ✅ **Checksums**: Placeholder system ready
- ✅ **Automation**: Update script provided

## 🚀 Publishing Checklist

### Before Release
- [ ] Verify all artifacts build successfully
- [ ] Test zip extraction and binary functionality
- [ ] Update version in Cargo.toml
- [ ] Run release workflow with proper versioning

### After Release
- [ ] Run `pwsh ./Update-Packages.ps1 -Version <VERSION>`
- [ ] Review generated manifests in `generated/` directory
- [ ] Create Homebrew tap (if first time)
- [ ] Submit Winget manifest PR
- [ ] Submit Chocolatey package
- [ ] Test installations across platforms

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/awakecoding/mcp-proxy-tool/issues)
- **Documentation**: [Main README](../README.md)
- **Release Process**: [.github/workflows/](../.github/workflows/)
