# Distribution and Packaging Setup for MCP Proxy Tool

## Overview

This document outlines the complete setup for automated building and distributing the MCP Proxy Tool across multiple platforms and package managers.

## 🚀 Automated Build & Release Pipeline

### GitHub Actions Workflows

1. **CI Pipeline** (`.github/workflows/ci.yml`)
   - Runs on every push/PR to main/master
   - Tests on Windows, macOS, and Linux
   - Includes security audits and code formatting checks

2. **Release Pipeline** (`.github/workflows/release.yml`)
   - Triggers on git tags (`v*`) or manual dispatch
   - Builds for 6 target platforms:
     - Windows: x86_64, ARM64
     - macOS: Intel (x86_64), Apple Silicon (ARM64)
     - Linux: x86_64, ARM64
   - Generates checksums for all artifacts
   - Creates GitHub releases with downloadable binaries

### Supported Platforms

| Platform | Architecture | Binary Name |
|----------|-------------|-------------|
| Windows | x86_64 | `mcp-proxy-tool.exe` |
| Windows | ARM64 | `mcp-proxy-tool.exe` |
| macOS | x86_64 (Intel) | `mcp-proxy-tool` |
| macOS | ARM64 (Apple Silicon) | `mcp-proxy-tool` |
| Linux | x86_64 | `mcp-proxy-tool` |
| Linux | ARM64 | `mcp-proxy-tool` |

## 📦 Package Manager Distribution

### Windows - Winget

**Status:** Template Ready
**Location:** `packaging/winget-manifest-template.yaml`

**Steps to Publish:**
1. Create a release using the GitHub Actions workflow
2. Run `scripts/prepare-release.ps1 <version>` to generate manifest
3. Fork [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs)
4. Create `manifests/a/awakecoding/mcp-proxy-tool/<version>/awakecoding.mcp-proxy-tool.yaml`
5. Submit PR to winget-pkgs repository

**User Installation:**
```powershell
winget install awakecoding.mcp-proxy-tool
```

### macOS - Homebrew

**Status:** Template Ready
**Location:** `packaging/homebrew-formula-template.rb`

**Option 1: Custom Tap (Recommended)**
1. Create repository: `awakecoding/homebrew-tap`
2. Run `scripts/prepare-release.ps1 <version>` to generate formula
3. Add formula to `Formula/mcp-proxy-tool.rb` in tap repository

**User Installation:**
```bash
brew tap awakecoding/tap
brew install mcp-proxy-tool
```

**Option 2: Homebrew Core**
- Requires significant user adoption
- Submit to [homebrew/homebrew-core](https://github.com/Homebrew/homebrew-core)

### Rust Ecosystem - Cargo

**Status:** Ready (configured in Cargo.toml)

**To Publish:**
```bash
cargo login  # One-time setup with crates.io token
cargo publish
```

**User Installation:**
```bash
cargo install mcp-proxy-tool
```

### Linux Distributions

**Options for Future Implementation:**
1. **AppImage** - Universal Linux binary
2. **Debian/Ubuntu** - `.deb` packages via PPA
3. **Arch Linux** - AUR package
4. **Flatpak** - Sandboxed application
5. **Snap** - Universal Linux packages

## 🛠️ Release Process

### 1. Prepare Release

1. Update version in `Cargo.toml`
2. Update `CHANGELOG.md` (if exists)
3. Commit changes: `git commit -m "Bump version to v1.0.0"`
4. Create and push tag: `git tag v1.0.0 && git push origin v1.0.0`

### 2. Automated Build

GitHub Actions will automatically:
- Build binaries for all platforms
- Generate checksums
- Create GitHub release
- Upload artifacts

### 3. Package Manager Updates

**Windows (Winget):**
```powershell
scripts\prepare-release.ps1 1.0.0
# Follow winget submission process
```

**macOS (Homebrew):**
```powershell
./scripts/prepare-release.ps1 1.0.0
# Update tap repository
```

**Rust (Cargo):**
```bash
cargo publish
```

## 📁 Repository Structure

```
mcp-proxy-tool/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml              # Continuous integration
│   │   └── release.yml         # Release automation
│   └── ISSUE_TEMPLATE/
│       └── package-manager-request.md
├── .cargo/
│   └── config.toml             # Cross-compilation config
├── packaging/
│   ├── winget-manifest-template.yaml
│   └── homebrew-formula-template.rb
├── scripts/
│   └── prepare-release.ps1     # Cross-platform PowerShell release script
├── src/
│   └── main.rs
├── Cargo.toml                  # Enhanced with metadata
├── LICENSE                     # MIT license
└── README.md                   # Installation instructions
```

## 🔧 Development Workflow

### Local Testing

```bash
# Run tests
cargo test

# Check formatting
cargo fmt --check

# Run clippy
cargo clippy -- -D warnings

# Build release
cargo build --release
```

### Cross-Platform Testing

The CI pipeline automatically tests on:
- Ubuntu Latest (Linux)
- Windows Latest
- macOS Latest

## 📊 Distribution Statistics

Once published, you can track adoption through:
- **GitHub Releases**: Download counts
- **Winget**: Microsoft Store analytics
- **Homebrew**: Analytics API
- **Cargo/crates.io**: Download statistics

## 🎯 Next Steps

1. **Immediate**: Test the GitHub Actions workflows by creating a test release
2. **Short-term**: Submit to Winget and create Homebrew tap
3. **Medium-term**: Publish to crates.io
4. **Long-term**: Consider Linux distribution packages based on adoption

## 🔍 Quality Assurance

The setup includes:
- **Automated testing** on multiple platforms
- **Security audits** with cargo-audit
- **Code formatting** enforcement
- **Checksum verification** for all releases
- **Reproducible builds** with locked dependencies

This comprehensive setup ensures reliable, secure, and easily distributable releases across all major platforms and package managers.
