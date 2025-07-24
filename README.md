# MCP Proxy Tool

A command-line proxy tool that reads MCP (Model Context Protocol) tool calls from stdin, forwards them to an HTTP-based MCP server, and writes the responses to stdout.

## Overview

This tool acts as a bridge between local MCP clients and remote HTTP-based MCP servers. It accepts JSON-formatted MCP requests via stdin, converts them to JSON-RPC format, sends them to a configured MCP server endpoint, and returns the formatted response.

## Features

- JSON-RPC 2.0 compliant communication
- Server-Sent Events (SSE) response handling
- Unicode escape sequence decoding
- Pretty-printed JSON output
- Error handling and logging

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

### Basic Usage

```bash
# List available documentation tools
echo '{"method": "tools/list", "params": {}}' | ./mcp-proxy-tool

# Search Microsoft Learn documentation
echo '{"method": "tools/call", "params": {"name": "docs_search", "arguments": {"query": "Azure Functions"}}}' | ./mcp-proxy-tool
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
    "jsonrpc": "2.0",
    "id": 1,
    "result": {
      "tools": [
        {
          "name": "docs_search",
          "description": "Search Microsoft Learn documentation",
          "inputSchema": {
            "type": "object",
            "properties": {
              "query": {
                "type": "string",
                "description": "Search query for Microsoft Learn docs"
              },
              "scope": {
                "type": "string",
                "description": "Optional scope to limit search (e.g., 'azure', 'dotnet', 'powershell')"
              }
            },
            "required": ["query"]
          }
        }
      ]
    }
  }
}
```

#### Search Microsoft Learn Documentation

**Input:**
```json
{
  "method": "tools/call",
  "params": {
    "name": "docs_search",
    "arguments": {
      "query": "Azure Functions triggers",
      "scope": "azure"
    }
  }
}
```

**Output:**
```json
{
  "request": {
    "method": "tools/call",
    "params": {
      "name": "docs_search",
      "arguments": {
        "query": "Azure Functions triggers",
        "scope": "azure"
      }
    }
  },
  "response": {
    "jsonrpc": "2.0",
    "id": 1,
    "result": {
      "content": [
        {
          "type": "text",
          "text": "Azure Functions supports various trigger types:\n\n1. **HTTP Trigger**: Responds to HTTP requests\n2. **Timer Trigger**: Runs on a schedule using CRON expressions\n3. **Blob Trigger**: Activates when files are added or modified in Azure Blob Storage\n4. **Queue Trigger**: Processes messages from Azure Storage Queues\n5. **Service Bus Trigger**: Handles messages from Service Bus queues or topics\n\nFor more details, see: https://docs.microsoft.com/azure/azure-functions/functions-triggers-bindings"
        }
      ]
    }
  }
}
```

#### Search .NET Documentation

**Input:**
```json
{
  "method": "tools/call",
  "params": {
    "name": "docs_search",
    "arguments": {
      "query": "async await best practices",
      "scope": "dotnet"
    }
  }
}
```

**Output:**
```json
{
  "request": {
    "method": "tools/call",
    "params": {
      "name": "docs_search",
      "arguments": {
        "query": "async await best practices",
        "scope": "dotnet"
      }
    }
  },
  "response": {
    "jsonrpc": "2.0",
    "id": 1,
    "result": {
      "content": [
        {
          "type": "text",
          "text": "Best practices for async/await in .NET:\n\n1. **Use ConfigureAwait(false)** in library code to avoid deadlocks\n2. **Don't mix blocking and async code** - avoid .Result or .Wait()\n3. **Use async all the way** - don't block on async methods\n4. **Consider using ValueTask** for high-performance scenarios\n5. **Handle exceptions properly** with try-catch blocks\n\nExample:\n```csharp\npublic async Task<string> GetDataAsync()\n{\n    using var client = new HttpClient();\n    var response = await client.GetAsync(url).ConfigureAwait(false);\n    return await response.Content.ReadAsStringAsync().ConfigureAwait(false);\n}\n```"
        }
      ]
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
echo '{"method": "tools/list", "params": {}}' | ./mcp-proxy-tool

echo "Searching Azure documentation..."
echo '{"method": "tools/call", "params": {"name": "docs_search", "arguments": {"query": "Azure App Service deployment", "scope": "azure"}}}' | ./mcp-proxy-tool

echo "Searching PowerShell documentation..."
echo '{"method": "tools/call", "params": {"name": "docs_search", "arguments": {"query": "PowerShell cmdlets", "scope": "powershell"}}}' | ./mcp-proxy-tool
```

### Common Use Cases

#### 1. Quick Documentation Lookup
```bash
# Search for specific Azure service information
echo '{"method": "tools/call", "params": {"name": "docs_search", "arguments": {"query": "Azure Cosmos DB", "scope": "azure"}}}' | ./mcp-proxy-tool
```

#### 2. API Reference Search
```bash
# Find .NET API documentation
echo '{"method": "tools/call", "params": {"name": "docs_search", "arguments": {"query": "HttpClient class", "scope": "dotnet"}}}' | ./mcp-proxy-tool
```

#### 3. Tutorial and Guide Search
```bash
# Search for getting started guides
echo '{"method": "tools/call", "params": {"name": "docs_search", "arguments": {"query": "getting started with Azure Functions"}}}' | ./mcp-proxy-tool
```

#### 4. Troubleshooting and Best Practices
```bash
# Find troubleshooting information
echo '{"method": "tools/call", "params": {"name": "docs_search", "arguments": {"query": "Azure debugging performance", "scope": "azure"}}}' | ./mcp-proxy-tool
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
- `tools/call` - Execute documentation searches with parameters like:
  - `docs_search` - Search Microsoft Learn documentation
    - `query` (required) - Your search terms
    - `scope` (optional) - Limit search to specific areas:
      - `azure` - Azure services and features
      - `dotnet` - .NET framework and C# documentation
      - `powershell` - PowerShell cmdlets and scripting
      - `microsoft-365` - Microsoft 365 and Office documentation
      - `windows` - Windows development and administration
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
4. **Search returns no results**: Try broader search terms or remove the scope parameter
5. **Tool not found errors**: Verify the tool name is `docs_search` (case-sensitive)

### Debug Mode

For verbose logging, you can modify the source to enable debug output or use environment variables like `RUST_LOG=debug`.

## Related Projects

- [Model Context Protocol Specification](https://spec.modelcontextprotocol.io/)
- [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)
- [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)
