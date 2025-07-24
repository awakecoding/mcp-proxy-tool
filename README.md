# MCP Proxy Tool

A high-performance MCP (Model Context Protocol) proxy tool written in Rust that enables connections to HTTP-based, STDIO-based, and named pipe-based MCP servers. This tool acts as a bridge, converting between different MCP transport protocols and making MCP servers accessible through a unified interface.

## Features

- **Triple Transport Support**: Connect to HTTP, STDIO, and named pipe-based MCP servers
- **HTTP Transport**: Proxy requests to remote HTTP-based MCP servers (like Microsoft Learn)
- **STDIO Transport**: Launch and communicate with executable MCP servers over stdin/stdout
- **Named Pipe Transport**: Connect to MCP servers over Unix domain sockets/named pipes
- **JSON-RPC 2.0 Compatible**: Full support for MCP protocol specifications
- **High Performance**: Built in Rust with async/await for optimal performance
- **Configurable Timeouts**: Adjustable timeout settings for HTTP requests
- **Verbose Logging**: Optional detailed logging for debugging and monitoring
- **Lightweight**: Small binary size using argh for CLI parsing (~6MB release build)

## Installation

### Prerequisites

- Rust (latest stable version)
- Cargo

### Build from source

```bash
git clone <repository-url>
cd mcp-proxy-tool
cargo build --release
```

The compiled binary will be available at `target/release/mcp-proxy-tool`.

## Usage

### Command Line Options

```
Usage: mcp-proxy-tool [-u <url>] [-c <command>] [-a <args>] [-p <pipe>] [-t <timeout>] [-v]

Options:
  -u, --url         URL of the remote HTTP-based MCP server to proxy requests to
  -c, --command     command to execute for STDIO-based MCP server
  -a, --args        arguments for the STDIO-based MCP server command
  -p, --pipe        path to named pipe for named pipe-based MCP server
  -t, --timeout     timeout in seconds for HTTP requests (ignored for STDIO and named pipe)
  -v, --verbose     enable verbose logging
  --help, help      display usage information
```

### HTTP Transport (Remote MCP Server)

Connect to a remote HTTP-based MCP server:

```bash
# Connect to Microsoft Learn MCP server
./target/release/mcp-proxy-tool -u https://learn.microsoft.com/api/mcp

# With verbose logging and custom timeout
./target/release/mcp-proxy-tool -u https://learn.microsoft.com/api/mcp -v -t 60
```

### STDIO Transport (Local Executable)

Launch and connect to a local executable MCP server:

```bash
# Connect to a Python MCP server
./target/release/mcp-proxy-tool -c python3 -a mcp_server.py

# Connect to a Node.js MCP server with arguments
./target/release/mcp-proxy-tool -c node -a "server.js --config config.json"

# With verbose logging
./target/release/mcp-proxy-tool -c python3 -a mcp_server.py -v
```

### Named Pipe Transport (Local Socket-based)

Connect to an MCP server over Unix domain sockets/named pipes:

```bash
# Connect to a named pipe MCP server
./target/release/mcp-proxy-tool -p /tmp/mcp_server.sock

# Connect to a Unix domain socket with verbose logging
./target/release/mcp-proxy-tool -p /var/run/mcp/server.socket -v

# Connect to a local socket-based MCP server
./target/release/mcp-proxy-tool -p /home/user/.mcp/server.pipe -v
```

### Basic Usage

```bash
# Use default Microsoft Learn MCP server
echo '{"method": "tools/list", "params": {}}' | ./target/debug/mcp-proxy-tool

# Use custom MCP server with verbose logging
echo '{"method": "tools/list", "params": {}}' | ./target/debug/mcp-proxy-tool --url "https://your-server.com/mcp" --verbose

# Set custom timeout
./target/debug/mcp-proxy-tool --timeout 60 --verbose

# Search Microsoft Learn documentation
echo '{"method": "tools/call", "params": {"name": "microsoft_docs_search", "arguments": {"question": "Azure Functions"}}}' | ./target/debug/mcp-proxy-tool
```

### MCP Protocol Communication Examples

#### HTTP Transport with Microsoft Learn
```bash
# Initialize connection
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | ./target/release/mcp-proxy-tool -u https://learn.microsoft.com/api/mcp

# List available tools
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | ./target/release/mcp-proxy-tool -u https://learn.microsoft.com/api/mcp

# Call a tool
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"microsoft_docs_search","arguments":{"question":"How to use Azure Functions?"}}}' | ./target/release/mcp-proxy-tool -u https://learn.microsoft.com/api/mcp
```

#### STDIO Transport with Custom Server
```bash
# List tools from Python MCP server
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | ./target/release/mcp-proxy-tool -c python3 -a echo_server.py

# Call tool via STDIO transport
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"echo","arguments":{"text":"Hello STDIO!"}}}' | ./target/release/mcp-proxy-tool -c python3 -a echo_server.py
```

#### Named Pipe Transport with Socket Server
```bash
# List tools from named pipe MCP server
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | ./target/release/mcp-proxy-tool -p /tmp/mcp_server.sock

# Call tool via named pipe transport
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"pipe_echo","arguments":{"message":"Hello Named Pipe!"}}}' | ./target/release/mcp-proxy-tool -p /tmp/mcp_server.sock -v
```

### Configuration Examples

#### VS Code MCP Configuration

You can configure multiple proxy instances in your `.vscode/mcp.json`:

```json
{
  "servers": {
    "microsoft-learn-proxy": {
      "type": "stdio",
      "command": "/path/to/mcp-proxy-tool",
      "args": ["--url", "https://learn.microsoft.com/api/mcp", "--verbose"]
    },
    "custom-mcp-proxy": {
      "type": "stdio", 
      "command": "/path/to/mcp-proxy-tool",
      "args": ["--url", "https://your-custom-server.com/mcp", "--timeout", "60"]
    }
  }
}
```

#### MCP Inspector Usage

```bash
# Start MCP Inspector and connect to your proxy
mcp-inspector

# Then in the web interface, add a server:
# - Command: /path/to/mcp-proxy-tool
# - Args: --url https://your-server.com/mcp --verbose
```

### Sample Input/Output

#### List Tools Request (Microsoft Learn Docs MCP Server)

**Input:**
```json
{
  "method": "tools/list",
  "params": {}
}
```

**Output:**
```json
{
  "request": {
    "method": "tools/list",
    "params": {}
  },
  "response": {
    "id": 1,
    "jsonrpc": "2.0",
    "result": {
      "tools": [
        {
          "description": "Search official Microsoft/Azure documentation to find the most relevant and trustworthy content for a user's query. This tool returns up to 10 high-quality content chunks (each max 500 tokens), extracted from Microsoft Learn and other official sources. Each result includes the article title, URL, and a self-contained content excerpt optimized for fast retrieval and reasoning. Always use this tool to quickly ground your answers in accurate, first-party Microsoft/Azure knowledge.",
          "inputSchema": {
            "description": "Search official Microsoft/Azure documentation to find the most relevant and trustworthy content for a user's query. This tool returns up to 10 high-quality content chunks (each max 500 tokens), extracted from Microsoft Learn and other official sources. Each result includes the article title, URL, and a self-contained content excerpt optimized for fast retrieval and reasoning. Always use this tool to quickly ground your answers in accurate, first-party Microsoft/Azure knowledge.",
            "properties": {
              "question": {
                "description": "a question or topic about Microsoft/Azure products, services, platforms, developer tools, frameworks, or APIs",
                "type": "string"
              }
            },
            "required": [
              "question"
            ],
            "title": "microsoft_docs_search",
            "type": "object"
          },
          "name": "microsoft_docs_search"
        }
      ]
    }
  }
}
```

#### Search Azure CLI Container App Creation

**Input:**
```json
{
  "method": "tools/call",
  "params": {
    "name": "microsoft_docs_search",
    "arguments": {
      "question": "Azure CLI create container app"
    }
  }
}
```

**Output (truncated for brevity):**
```json
{
  "request": {
    "method": "tools/call",
    "params": {
      "arguments": {
        "question": "Azure CLI create container app"
      },
      "name": "microsoft_docs_search"
    }
  },
  "response": {
    "id": 1,
    "jsonrpc": "2.0",
    "result": {
      "content": [
        {
          "text": "[{\"title\":\"az containerapp create\",\"content\":\"### Command\\naz containerapp create\\n\\n### Summary\\nCreate a container app.\\n\\n### Required Parameters\\n\\n--name -n\\nThe name of the Containerapp. A name must consist of lower case alphanumeric characters or '-', start with a letter, end with an alphanumeric character, cannot have '--', and must be less than 32 characters.\\n\\n--resource-group -g\\nName of resource group. You can configure the default group using `az configure --defaults group=<name>`.\\n\\n### Optional Parameters\\n\\n--allow-insecure\\nAllow insecure connections for ingress traffic...\"},{\"title\":\"Use Azure Functions in Azure Container Apps (azure-cli)\",\"content\":\"# Use Azure Functions in Azure Container Apps (azure-cli)\\n## Create a Functions App\\nTo sign in to Azure from the CLI, run the following command and follow the prompts to complete the authentication process...\"},{\"title\":\"Tutorial: Deploy your first container app\",\"content\":\"# Tutorial: Deploy your first container app\\nThe Azure Container Apps service enables you to run microservices and containerized applications on a serverless platform...\"}]",
          "type": "text"
        }
      ],
      "isError": false
    }
  }
}
```

### Using with Files

You can also pipe input from files:

```bash
cat request.json | ./mcp-proxy-tool > response.json
```

### Integration with Scripts

```bash
#!/bin/bash

# Example script to interact with Microsoft Learn Docs
echo "Listing available tools..."
echo '{"method": "tools/list", "params": {}}' | ./target/debug/mcp-proxy-tool

echo "Searching Azure CLI documentation..."
echo '{"method": "tools/call", "params": {"name": "microsoft_docs_search", "arguments": {"question": "Azure CLI create container app"}}}' | ./target/debug/mcp-proxy-tool

echo "Searching .NET documentation..."
echo '{"method": "tools/call", "params": {"name": "microsoft_docs_search", "arguments": {"question": "C# async await best practices"}}}' | ./target/debug/mcp-proxy-tool
```

### Common Use Cases

#### 1. Azure Service Documentation
```bash
# Search for specific Azure service information
echo '{"method": "tools/call", "params": {"name": "microsoft_docs_search", "arguments": {"question": "Azure Container Apps environment"}}}' | ./target/debug/mcp-proxy-tool
```

#### 2. CLI Command Reference
```bash
# Find Azure CLI command documentation
echo '{"method": "tools/call", "params": {"name": "microsoft_docs_search", "arguments": {"question": "az containerapp create command"}}}' | ./target/debug/mcp-proxy-tool
```

#### 3. Development Best Practices
```bash
# Search for development guidance
echo '{"method": "tools/call", "params": {"name": "microsoft_docs_search", "arguments": {"question": "Azure Functions deployment best practices"}}}' | ./target/debug/mcp-proxy-tool
```

#### 4. API Reference Search
```bash
# Find API documentation
echo '{"method": "tools/call", "params": {"name": "microsoft_docs_search", "arguments": {"question": "Azure REST API container apps"}}}' | ./target/debug/mcp-proxy-tool
```

## Configuration

Currently, the MCP server URL is hardcoded to `https://learn.microsoft.com/api/mcp`. Future versions will support configurable endpoints via:

- Command-line arguments
- Environment variables
- Configuration files

## Error Handling

The tool provides detailed error messages for common issues:

- Invalid JSON input
- Network connectivity problems
- MCP server errors
- Empty responses

Error messages are written to stderr, while successful responses go to stdout.

## Response Format

All responses follow this structure:

```json
{
  "request": {
    "method": "string",
    "params": "object"
  },
  "response": {
    "jsonrpc": "2.0",
    "id": 1,
    "result": "object"
  }
}
```

## Supported MCP Methods

When connecting to the Microsoft Learn Docs MCP server:

- `tools/list` - List available documentation search tools
- `tools/call` - Execute documentation searches with the `microsoft_docs_search` tool:
  - `question` (required) - Your question or topic about Microsoft/Azure products, services, platforms, developer tools, frameworks, or APIs
  - Returns up to 10 high-quality content chunks from Microsoft Learn and official sources
  - Each result includes article title, URL, and content excerpt (max 500 tokens each)
- `resources/list` - List available documentation resources (if supported)
- `resources/read` - Read specific documentation content (if supported)

## Development

### Running Tests

```bash
cargo test
```

### Development Build

```bash
cargo build
```

### Release Build

```bash
cargo build --release
```

## Transport Modes

The MCP proxy tool supports three different transport mechanisms:

### HTTP Transport (`-u` option)
- Connects to remote HTTP-based MCP servers
- Uses reqwest for efficient HTTP communication
- Supports SSE (Server-Sent Events) responses
- Configurable timeouts
- Automatic JSON-RPC request/response handling
- Best for: Public MCP services, cloud-based servers

### STDIO Transport (`-c` and `-a` options)
- Launches local executable MCP servers
- Communicates over stdin/stdout
- Supports any executable that implements MCP over STDIO
- Automatic process lifecycle management
- No timeout limitations (process-based communication)
- Best for: Local development, packaged MCP servers

### Named Pipe Transport (`-p` option)
- Connects to MCP servers over Unix domain sockets/named pipes
- Efficient local inter-process communication
- Supports both Unix domain sockets and traditional named pipes
- Low latency for local communication
- Automatic connection handling
- Best for: High-performance local servers, system services

## MCP Protocol Support

- **JSON-RPC 2.0**: Full compliance with JSON-RPC specification
- **MCP Methods**: 
  - `initialize` - Handled locally by proxy
  - `notifications/initialized` - Handled locally  
  - `tools/list` - Forwarded to target server
  - `tools/call` - Forwarded to target server
- **Error Handling**: Proper error responses for unknown methods
- **Unicode Support**: Automatic decoding of Unicode escapes in responses

## Performance

- **Binary Size**: ~6MB release build (using argh for lightweight CLI parsing)
- **Memory Efficient**: Async/await patterns for minimal resource usage
- **Fast Startup**: Near-instantaneous startup time
- **Concurrent**: Handles multiple requests efficiently across all transport modes

## Dependencies

- `tokio` - Async runtime
- `reqwest` - HTTP client (for HTTP transport)
- `serde_json` - JSON serialization
- `anyhow` - Error handling
- `argh` - Lightweight CLI parsing

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

[Add your license information here]

## Troubleshooting

### Common Issues

1. **Empty response body**: Check if the Microsoft Learn MCP server is accessible at `https://learn.microsoft.com/api/mcp`
2. **JSON parse errors**: Ensure input is valid JSON format matching MCP request structure
3. **Network timeouts**: Verify internet connectivity and Microsoft Learn server availability
4. **Search returns no results**: Try rephrasing your question or making it more specific
5. **Tool not found errors**: Verify the tool name is `microsoft_docs_search` (case-sensitive)
6. **Parameter errors**: Ensure you're using `question` parameter, not `query` or other parameter names

### Debug Mode

For verbose logging, you can modify the source to enable debug output or use environment variables like `RUST_LOG=debug`.

## Related Projects

- [Model Context Protocol Specification](https://spec.modelcontextprotocol.io/)
- [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)
- [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)
