#!/usr/bin/env python3
"""
Simple MCP echo server for testing STDIO transport.
This server responds to basic MCP methods over STDIO.
"""

import json
import sys

def handle_initialize():
    return {
        "jsonrpc": "2.0",
        "id": 1,
        "result": {
            "protocolVersion": "2024-11-05",
            "capabilities": {
                "tools": {"listChanged": True},
                "logging": {}
            },
            "serverInfo": {
                "name": "echo-mcp-server",
                "version": "1.0.0"
            }
        }
    }

def handle_tools_list():
    return {
        "jsonrpc": "2.0",
        "id": 1,
        "result": {
            "tools": [
                {
                    "name": "echo",
                    "description": "Echo back the input text",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "text": {
                                "type": "string",
                                "description": "Text to echo back"
                            }
                        },
                        "required": ["text"]
                    }
                }
            ]
        }
    }

def handle_tools_call(params):
    tool_name = params.get("name")
    tool_args = params.get("arguments", {})
    
    if tool_name == "echo":
        text = tool_args.get("text", "")
        return {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
                "content": [
                    {
                        "type": "text",
                        "text": f"Echo: {text}"
                    }
                ]
            }
        }
    
    return {
        "jsonrpc": "2.0",
        "id": 1,
        "error": {
            "code": -32601,
            "message": f"Unknown tool: {tool_name}"
        }
    }

def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
            
        try:
            request = json.loads(line)
            method = request.get("method")
            params = request.get("params", {})
            
            if method == "initialize":
                response = handle_initialize()
            elif method == "tools/list":
                response = handle_tools_list()
            elif method == "tools/call":
                response = handle_tools_call(params)
            elif method == "notifications/initialized":
                # No response needed for notifications
                continue
            else:
                response = {
                    "jsonrpc": "2.0",
                    "id": request.get("id", 1),
                    "error": {
                        "code": -32601,
                        "message": f"Method not found: {method}"
                    }
                }
            
            print(json.dumps(response), flush=True)
            
        except json.JSONDecodeError as e:
            error_response = {
                "jsonrpc": "2.0",
                "id": 1,
                "error": {
                    "code": -32700,
                    "message": f"Parse error: {str(e)}"
                }
            }
            print(json.dumps(error_response), flush=True)

if __name__ == "__main__":
    main()
