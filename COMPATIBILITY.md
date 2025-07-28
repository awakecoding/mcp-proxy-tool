# Binary Compatibility Guide

This document outlines the compatibility targets and requirements for MCP Proxy Tool prebuilt binaries.

## Platform Compatibility

### macOS
- **Minimum Version**: macOS 10.15 (Catalina)
- **Intel Macs**: Supports all Intel Macs from 2009 onwards
- **Apple Silicon**: Supports all Apple Silicon Macs (M1, M2, M3+)
- **Configuration**: Built with `MACOSX_DEPLOYMENT_TARGET=10.15`

### Linux
- **glibc Version**: 2.31+ (Ubuntu 20.04, CentOS 8, RHEL 8+)
- **Supported Distributions**:
  - Ubuntu 20.04+
  - Debian 11+
  - CentOS 8+, RHEL 8+
  - Fedora 32+
  - openSUSE Leap 15.2+
  - Arch Linux (current)
- **Architecture**: x86_64 and ARM64 (aarch64)

### Windows
- **Minimum Version**: Windows 10 (x64) / Windows 11 (ARM64)
- **Architecture**: x86_64 and ARM64
- **Runtime**: No additional runtime requirements (statically linked MSVC runtime)

## Compatibility Testing

Our CI/CD pipeline includes compatibility verification:

### macOS
- Uses `otool -l` to verify deployment target
- Tests on macOS 12 builders for backward compatibility
- Ensures minimum macOS 10.15 support

### Linux
- Uses `objdump -T` to check glibc dependencies
- Built on Ubuntu 20.04 for maximum compatibility
- Verifies glibc 2.31 requirement

### Windows
- Uses MSVC toolchain with static runtime linking
- No external dependencies required

## Maximizing Compatibility

### Option 1: Current Setup (Recommended)
- **Pros**: Smaller binaries, good compatibility
- **Cons**: Requires specific system library versions
- **Target**: Modern systems (last 3-4 years)

### Option 2: Static Linking (Maximum Compatibility)
To enable fully static binaries for Linux, modify the build process:

```bash
# For completely static Linux binaries
export RUSTFLAGS="-C target-feature=+crt-static"
cargo build --release --target x86_64-unknown-linux-gnu
```

**Trade-offs**:
- **Pros**: Runs on very old Linux systems
- **Cons**: Larger binary size, may have limitations with some features

### Option 3: musl libc (Alternative for Linux)
For even better Linux compatibility, consider musl-based builds:

```bash
# Install musl target
rustup target add x86_64-unknown-linux-musl

# Build with musl
cargo build --release --target x86_64-unknown-linux-musl
```

## Checking Binary Compatibility

### Linux
```bash
# Check glibc requirements
objdump -T ./mcp-proxy-tool | grep GLIBC

# Check binary type
file ./mcp-proxy-tool

# Check dependencies
ldd ./mcp-proxy-tool
```

### macOS
```bash
# Check deployment target
otool -l ./mcp-proxy-tool | grep -A 3 LC_VERSION_MIN_MACOSX

# Check architecture
file ./mcp-proxy-tool

# Check dependencies
otool -L ./mcp-proxy-tool
```

### Windows
```powershell
# Check architecture and type
file ./mcp-proxy-tool.exe

# Using dumpbin (if available)
dumpbin /headers ./mcp-proxy-tool.exe
```

## Troubleshooting

### "GLIBC_X.XX not found" (Linux)
- User's system is too old
- Recommend using static build or newer distribution
- Minimum requirement: glibc 2.31+

### "Bad CPU type" (macOS)
- Wrong architecture (Intel vs Apple Silicon)
- Use universal binary or correct architecture-specific build

### "This app can't run on your PC" (Windows)
- Wrong architecture (x64 vs ARM64)
- Missing Visual C++ runtime (shouldn't happen with our static builds)

## Future Improvements

1. **Universal Binaries**: Consider macOS universal binaries for single download
2. **Alpine Linux**: Add musl-based builds for Alpine/Docker compatibility
3. **Older macOS**: Consider supporting macOS 10.13+ if needed
4. **Static Builds**: Offer static Linux builds as alternative downloads

## Testing Compatibility

Users can test compatibility on their systems:

```bash
# Quick compatibility test
./mcp-proxy-tool --help

# Verbose test with output
./mcp-proxy-tool --version
```

If the binary runs and shows help/version information, it's compatible with the system.
