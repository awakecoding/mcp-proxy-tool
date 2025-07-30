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
  version "0.1.0" # Updated to current version from Cargo.toml
  license "MIT"
  
  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/awakecoding/mcp-proxy-tool/releases/download/v#{version}/mcp-proxy-tool-macos-arm64.zip"
      sha256 "29BCDA93DFE7462C021AEF1A1CE8853E9FC67858E970750B5677C00390BFFD92" # Replace with actual SHA256 from checksums.txt
    else
      url "https://github.com/awakecoding/mcp-proxy-tool/releases/download/v#{version}/mcp-proxy-tool-macos-x64.zip"
      sha256 "AEF7650E6FCBC6B8916E3386E4633E11EEA8B477190D09806824C98C789D0E14" # Replace with actual SHA256 from checksums.txt
    end
  elsif OS.linux?
    if Hardware::CPU.arm?
      url "https://github.com/awakecoding/mcp-proxy-tool/releases/download/v#{version}/mcp-proxy-tool-linux-arm64.zip"
      sha256 "C62339A639F1AD66F2D080796D3E802153AEC4E5FB8D5396CCFE1894D1AE6A3C" # Replace with actual SHA256 from checksums.txt
    else
      url "https://github.com/awakecoding/mcp-proxy-tool/releases/download/v#{version}/mcp-proxy-tool-linux-x64.zip"
      sha256 "1DBAD90AE2CE931AE075A6E30BC9A13E7267B64EB7AD766B0EA5210C5533A083" # Replace with actual SHA256 from checksums.txt
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
