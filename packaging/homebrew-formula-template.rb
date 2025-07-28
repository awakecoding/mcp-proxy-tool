# Homebrew Formula Template
#
# This can be used to create a homebrew formula for mcp-proxy-tool
# Options:
# 1. Create your own tap: https://github.com/awakecoding/homebrew-tap
# 2. Submit to homebrew-core (requires significant usage/popularity)
#
# For a custom tap, create a repository named homebrew-tap and add this formula

class McpProxyTool < Formula
  desc "Cross-platform MCP (Model Context Protocol) proxy tool"
  homepage "https://github.com/awakecoding/mcp-proxy-tool"
  version "{VERSION}" # Replace with actual version
  
  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/awakecoding/mcp-proxy-tool/releases/download/v#{version}/mcp-proxy-tool-macos-arm64.tar.gz"
      sha256 "{SHA256_MACOS_ARM64}" # Replace with actual SHA256
    else
      url "https://github.com/awakecoding/mcp-proxy-tool/releases/download/v#{version}/mcp-proxy-tool-macos-x64.tar.gz"
      sha256 "{SHA256_MACOS_X64}" # Replace with actual SHA256
    end
  elsif OS.linux?
    if Hardware::CPU.arm?
      url "https://github.com/awakecoding/mcp-proxy-tool/releases/download/v#{version}/mcp-proxy-tool-linux-arm64.tar.gz"
      sha256 "{SHA256_LINUX_ARM64}" # Replace with actual SHA256
    else
      url "https://github.com/awakecoding/mcp-proxy-tool/releases/download/v#{version}/mcp-proxy-tool-linux-x64.tar.gz"
      sha256 "{SHA256_LINUX_X64}" # Replace with actual SHA256
    end
  end

  def install
    bin.install "mcp-proxy-tool"
  end

  test do
    system "#{bin}/mcp-proxy-tool", "--help"
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
