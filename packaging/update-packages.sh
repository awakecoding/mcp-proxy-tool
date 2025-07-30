#!/bin/bash

# Update Packaging Templates Script
# This script helps update packaging templates with release information

set -e

VERSION=""
RELEASE_TAG=""
CHECKSUMS_FILE=""

usage() {
    echo "Usage: $0 -v VERSION [-t TAG] [-c CHECKSUMS_FILE]"
    echo "  -v VERSION          Version number (e.g., 0.1.0)"
    echo "  -t TAG              Release tag (defaults to v\$VERSION)"
    echo "  -c CHECKSUMS_FILE   Path to checksums.txt file (downloads if not provided)"
    echo ""
    echo "Example: $0 -v 0.1.0"
    echo "         $0 -v 0.1.0 -t v0.1.0 -c /path/to/checksums.txt"
    exit 1
}

while getopts "v:t:c:h" opt; do
    case $opt in
        v) VERSION="$OPTARG" ;;
        t) RELEASE_TAG="$OPTARG" ;;
        c) CHECKSUMS_FILE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ -z "$VERSION" ]; then
    echo "Error: Version is required"
    usage
fi

if [ -z "$RELEASE_TAG" ]; then
    RELEASE_TAG="v$VERSION"
fi

echo "Updating packaging templates for version $VERSION (tag: $RELEASE_TAG)"

# Download checksums if not provided
if [ -z "$CHECKSUMS_FILE" ]; then
    echo "Downloading checksums.txt from GitHub release..."
    CHECKSUMS_FILE="/tmp/checksums.txt"
    # Remove existing file if present
    rm -f "$CHECKSUMS_FILE"
    gh release download "$RELEASE_TAG" -p "checksums.txt" -D /tmp/
fi

if [ ! -f "$CHECKSUMS_FILE" ]; then
    echo "Error: Checksums file not found: $CHECKSUMS_FILE"
    exit 1
fi

echo "Reading checksums from: $CHECKSUMS_FILE"

# Extract SHA256 values for each platform
SHA256_LINUX_X64=$(grep "mcp-proxy-tool-linux-x64.zip" "$CHECKSUMS_FILE" | cut -d' ' -f1)
SHA256_LINUX_ARM64=$(grep "mcp-proxy-tool-linux-arm64.zip" "$CHECKSUMS_FILE" | cut -d' ' -f1)
SHA256_MACOS_X64=$(grep "mcp-proxy-tool-macos-x64.zip" "$CHECKSUMS_FILE" | cut -d' ' -f1)
SHA256_MACOS_ARM64=$(grep "mcp-proxy-tool-macos-arm64.zip" "$CHECKSUMS_FILE" | cut -d' ' -f1)
SHA256_WINDOWS_X64=$(grep "mcp-proxy-tool-windows-x64.zip" "$CHECKSUMS_FILE" | cut -d' ' -f1)
SHA256_WINDOWS_ARM64=$(grep "mcp-proxy-tool-windows-arm64.zip" "$CHECKSUMS_FILE" | cut -d' ' -f1)

echo "Extracted checksums:"
echo "  Linux x64:     $SHA256_LINUX_X64"
echo "  Linux ARM64:   $SHA256_LINUX_ARM64"
echo "  macOS x64:     $SHA256_MACOS_X64"
echo "  macOS ARM64:   $SHA256_MACOS_ARM64"
echo "  Windows x64:   $SHA256_WINDOWS_X64"
echo "  Windows ARM64: $SHA256_WINDOWS_ARM64"

# Update Homebrew formula
echo "Updating Homebrew formula..."
HOMEBREW_FILE="$(dirname "$0")/homebrew-formula-template.rb"
if [ -f "$HOMEBREW_FILE" ]; then
    cp "$HOMEBREW_FILE" "$HOMEBREW_FILE.bak"
    sed -i.tmp \
        -e "s/version \"[^\"]*\"/version \"$VERSION\"/" \
        -e "s/{SHA256_LINUX_X64}/$SHA256_LINUX_X64/" \
        -e "s/{SHA256_LINUX_ARM64}/$SHA256_LINUX_ARM64/" \
        -e "s/{SHA256_MACOS_X64}/$SHA256_MACOS_X64/" \
        -e "s/{SHA256_MACOS_ARM64}/$SHA256_MACOS_ARM64/" \
        "$HOMEBREW_FILE"
    rm "$HOMEBREW_FILE.tmp"
    echo "  ✓ Updated $HOMEBREW_FILE"
else
    echo "  ✗ Homebrew template not found: $HOMEBREW_FILE"
fi

# Update Winget manifest
echo "Updating Winget manifest..."
WINGET_FILE="$(dirname "$0")/winget-manifest-template.yaml"
if [ -f "$WINGET_FILE" ]; then
    cp "$WINGET_FILE" "$WINGET_FILE.bak"
    RELEASE_DATE=$(date +%Y-%m-%d)
    sed -i.tmp \
        -e "s/PackageVersion: \"[^\"]*\"/PackageVersion: \"$VERSION\"/" \
        -e "s|/v[0-9.]*[0-9]/|/v$VERSION/|g" \
        -e "s/{SHA256_X64}/$SHA256_WINDOWS_X64/" \
        -e "s/{SHA256_ARM64}/$SHA256_WINDOWS_ARM64/" \
        -e "s/{RELEASE_DATE}/$RELEASE_DATE/" \
        "$WINGET_FILE"
    rm "$WINGET_FILE.tmp"
    echo "  ✓ Updated $WINGET_FILE"
else
    echo "  ✗ Winget template not found: $WINGET_FILE"
fi

echo ""
echo "✓ Packaging templates updated successfully!"
echo ""
echo "Next steps:"
echo "1. Review the updated templates"
echo "2. For Homebrew: Create/update your tap repository"
echo "3. For Winget: Submit to microsoft/winget-pkgs repository"
echo ""
echo "Backup files created with .bak extension"
