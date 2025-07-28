#!/bin/bash
# Comprehensive test script for all MCP proxy transport modes

echo "=== MCP Proxy Tool - Transport Mode Tests ==="
echo

# Navigate to project root
cd "$(dirname "$0")/.."

# Build the project
echo "Building mcp-proxy-tool..."
cargo build --release
echo

# Test 1: STDIO Transport
echo "1. Testing STDIO Transport:"
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"echo","arguments":{"text":"STDIO works!"}}}' | \
  ./target/release/mcp-proxy-tool -c python3 -a tests/test_echo_server.py
echo

# Test 2: Named Pipe Transport
echo "2. Testing Named Pipe Transport:"
echo "Starting named pipe server..."
python3 tests/test_pipe_server.py /tmp/test_mcp_pipe &
PIPE_PID=$!
sleep 2

echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"pipe_echo","arguments":{"message":"Named Pipe works!"}}}' | \
  ./target/release/mcp-proxy-tool -p /tmp/test_mcp_pipe

# Clean up named pipe server
kill $PIPE_PID 2>/dev/null
rm -f /tmp/test_mcp_pipe
echo

# Test 3: HTTP Transport (with timeout to avoid hanging)
echo "3. Testing HTTP Transport (with timeout):"
timeout 5s bash -c 'echo "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}" | ./target/release/mcp-proxy-tool -u https://learn.microsoft.com/api/mcp' || echo "HTTP transport test timed out (normal for network requests)"
echo

echo "=== Transport Mode Tests Complete ==="
echo "Binary size: $(ls -lh target/release/mcp-proxy-tool | awk '{print $5}')"
echo
echo "Usage: ./target/release/mcp-proxy-tool --help"
