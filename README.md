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
echo '{"method": "tools/list", "params": {}}' | ./target/debug/mcp-proxy-tool

# Search Microsoft Learn documentation
echo '{"method": "tools/call", "params": {"name": "microsoft_docs_search", "arguments": {"question": "Azure Functions"}}}' | ./target/debug/mcp-proxy-tool
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
