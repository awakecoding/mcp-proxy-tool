# Test Scripts

This directory contains test scripts for the MCP Proxy Tool to help verify functionality across different transport modes.

## Test Scripts

### `test_echo_server.py`
A simple Python-based MCP server that echoes requests for testing the STDIO transport mode.

**Usage:**
```bash
# Terminal 1: Start the echo server via proxy
cd ../
cargo run -- -c python -a "tests/test_echo_server.py" -v

# Terminal 2: Send test requests
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | cargo run -- -c python -a "tests/test_echo_server.py"
```

### `test_pipe_server.py`
A Python-based MCP server that communicates over named pipes for testing the named pipe transport mode.

**Usage:**
```bash
# Start the pipe server (creates a named pipe)
python tests/test_pipe_server.py

# In another terminal, test the proxy
cargo run -- -p /tmp/mcp-test-pipe -v  # Unix
cargo run -- -p mcp-test-pipe -v       # Windows
```

### `test_all_transports.sh`
A comprehensive test script that validates all transport modes (HTTP, STDIO, and named pipes).

**Usage:**
```bash
# Make executable (Unix only)
chmod +x tests/test_all_transports.sh

# Run all tests
./tests/test_all_transports.sh
```

## Running Tests

### Prerequisites
- Python 3.6+ (for Python test servers)
- Rust/Cargo (for building the proxy tool)
- Bash (for shell scripts on Unix systems)

### Manual Testing

1. **HTTP Transport Test** (requires an actual HTTP MCP server):
   ```bash
   cargo run -- -u https://your-mcp-server.com/endpoint -v
   ```

2. **STDIO Transport Test**:
   ```bash
   cargo run -- -c python -a "tests/test_echo_server.py" -v
   ```

3. **Named Pipe Transport Test**:
   ```bash
   # Start pipe server first
   python tests/test_pipe_server.py &
   
   # Test the proxy
   cargo run -- -p /tmp/mcp-test-pipe -v
   ```

### Integration Testing

The test scripts can be used with the GitHub Actions CI pipeline to ensure the proxy tool works correctly across different platforms and transport modes.

## Contributing

When adding new test scripts:
1. Place them in this `tests/` directory
2. Use descriptive names starting with `test_`
3. Include usage instructions in this README
4. Consider adding them to the CI pipeline if they don't require external dependencies
