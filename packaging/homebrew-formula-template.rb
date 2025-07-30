# Homebrew Formula Template
#
# This can be used to create a homebrew formula for mcp-proxy-tool
# Options:
# 1. Create your own tap: https://github.com/awakecoding/homebrew-tap
# 2. Submit to homebrew-core (requires significant usage/popularity)
#
# For a custom tap, create a repository named homebrew-tap and add this formula
# Note: Homebrew supports macOS and Linux only. For Windows, use Winget.

class McpProxyTool < Formula
  desc "Cross-platform MCP (Model Context Protocol) proxy tool"
  homepage "https://github.com/awakecoding/mcp-proxy-tool"
  version "{VERSION}" # Will be replaced by Update-Packages.ps1
  license "MIT"
  
  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/awakecoding/mcp-proxy-tool/releases/download/v#{version}/mcp-proxy-tool-macos-arm64.zip"
      sha256 "{SHA256_MACOS_ARM64}" # Will be replaced by Update-Packages.ps1
    else
      url "https://github.com/awakecoding/mcp-proxy-tool/releases/download/v#{version}/mcp-proxy-tool-macos-x64.zip"
      sha256 "{SHA256_MACOS_X64}" # Will be replaced by Update-Packages.ps1
    end
  elsif OS.linux?
    if Hardware::CPU.arm?
      url "https://github.com/awakecoding/mcp-proxy-tool/releases/download/v#{version}/mcp-proxy-tool-linux-arm64.zip"
      sha256 "{SHA256_LINUX_ARM64}" # Will be replaced by Update-Packages.ps1
    else
      url "https://github.com/awakecoding/mcp-proxy-tool/releases/download/v#{version}/mcp-proxy-tool-linux-x64.zip"
      sha256 "{SHA256_LINUX_X64}" # Will be replaced by Update-Packages.ps1
    end
  else
    odie "Unsupported platform. For Windows, please use Winget: winget install awakecoding.mcp-proxy-tool"
  end

  def install
    # Extract binary from zip (our fixed release process puts binary at root level)
    bin.install "mcp-proxy-tool"
  end

  test do
    # Test that the binary is functional
    assert_match "Usage:", shell_output("#{bin}/mcp-proxy-tool --help")
    
    # Verify binary architecture matches the platform
    if OS.mac?
      if Hardware::CPU.arm?
        assert_match "arm64", shell_output("file #{bin}/mcp-proxy-tool")
      else
        assert_match "x86_64", shell_output("file #{bin}/mcp-proxy-tool")
      end
    end
  end
end

# Installation instructions for users:
# 
# For a custom tap:
# brew tap awakecoding/tap
# brew install mcp-proxy-tool
#
# Or install directly from URL:
# brew install https://raw.githubusercontent.com/awakecoding/homebrew-tap/master/Formula/mcp-proxy-tool.rb
#
# Note: For Windows users, use Winget instead:
# winget install awakecoding.mcp-proxy-tool
#
# To update the formula with new release:
# 1. Download checksums.txt from the GitHub release
# 2. Replace the SHA256 placeholders with actual values
# 3. Update the version number if needed
