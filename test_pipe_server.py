#!/usr/bin/env python3
"""
Simple MCP server that listens on a Unix domain socket (named pipe).
This server demonstrates named pipe-based MCP communication.
"""

import json
import os
import socket
import sys
import threading

def handle_client(conn):
    """Handle a client connection"""
    try:
        while True:
            # Receive data from client
            data = conn.recv(1024)
            if not data:
                break
                
            # Parse the JSON-RPC request
            try:
                request = json.loads(data.decode('utf-8').strip())
                method = request.get("method")
                params = request.get("params", {})
                request_id = request.get("id", 1)
                
                if method == "initialize":
                    response = {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "result": {
                            "protocolVersion": "2024-11-05",
                            "capabilities": {
                                "tools": {"listChanged": True},
                                "logging": {}
                            },
                            "serverInfo": {
                                "name": "named-pipe-mcp-server",
                                "version": "1.0.0"
                            }
                        }
                    }
                elif method == "tools/list":
                    response = {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "result": {
                            "tools": [
                                {
                                    "name": "pipe_echo",
                                    "description": "Echo text through named pipe",
                                    "inputSchema": {
                                        "type": "object",
                                        "properties": {
                                            "message": {
                                                "type": "string",
                                                "description": "Message to echo back"
                                            }
                                        },
                                        "required": ["message"]
                                    }
                                }
                            ]
                        }
                    }
                elif method == "tools/call":
                    tool_name = params.get("name")
                    tool_args = params.get("arguments", {})
                    
                    if tool_name == "pipe_echo":
                        message = tool_args.get("message", "")
                        response = {
                            "jsonrpc": "2.0",
                            "id": request_id,
                            "result": {
                                "content": [
                                    {
                                        "type": "text",
                                        "text": f"Named Pipe Echo: {message}"
                                    }
                                ]
                            }
                        }
                    else:
                        response = {
                            "jsonrpc": "2.0",
                            "id": request_id,
                            "error": {
                                "code": -32601,
                                "message": f"Unknown tool: {tool_name}"
                            }
                        }
                elif method == "notifications/initialized":
                    # No response needed for notifications
                    continue
                else:
                    response = {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "error": {
                            "code": -32601,
                            "message": f"Method not found: {method}"
                        }
                    }
                
                # Send response
                response_data = json.dumps(response) + "\n"
                conn.send(response_data.encode('utf-8'))
                
            except json.JSONDecodeError as e:
                error_response = {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "error": {
                        "code": -32700,
                        "message": f"Parse error: {str(e)}"
                    }
                }
                response_data = json.dumps(error_response) + "\n"
                conn.send(response_data.encode('utf-8'))
                
    except Exception as e:
        print(f"Error handling client: {e}", file=sys.stderr)
    finally:
        conn.close()

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 test_pipe_server.py <socket_path>")
        sys.exit(1)
    
    socket_path = sys.argv[1]
    
    # Remove socket file if it exists
    if os.path.exists(socket_path):
        os.unlink(socket_path)
    
    # Create Unix domain socket
    server_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server_socket.bind(socket_path)
    server_socket.listen(5)
    
    print(f"Named pipe MCP server listening on: {socket_path}", file=sys.stderr)
    
    try:
        while True:
            conn, addr = server_socket.accept()
            # Handle each client in a separate thread
            client_thread = threading.Thread(target=handle_client, args=(conn,))
            client_thread.daemon = True
            client_thread.start()
    except KeyboardInterrupt:
        print("\nShutting down server...", file=sys.stderr)
    finally:
        server_socket.close()
        if os.path.exists(socket_path):
            os.unlink(socket_path)

if __name__ == "__main__":
    main()
