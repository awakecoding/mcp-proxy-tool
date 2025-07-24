// MCP CLI Proxy
// Reads MCP tool calls from stdin (via JSON), proxies them to an HTTP-based MCP server
// (e.g. https://learn.microsoft.com/api/mcp), and writes responses to stdout.

use anyhow::{Context, Result};
use argh::FromArgs;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::io::{self, BufRead, BufReader};

// ----------------------------
// Structs for request/response
// ----------------------------

/// MCP Proxy Tool - Proxies MCP requests to remote HTTP-based MCP servers
#[derive(FromArgs)]
struct Args {
    /// URL of the remote MCP server to proxy requests to
    #[argh(option, short = 'u', default = "String::from(\"https://learn.microsoft.com/api/mcp\")")]
    url: String,
    
    /// timeout in seconds for HTTP requests
    #[argh(option, short = 't', default = "30")]
    timeout: u64,
    
    /// enable verbose logging
    #[argh(switch, short = 'v')]
    verbose: bool,
}

#[derive(Serialize, Deserialize)]
struct MCPRequest {
    method: String,
    params: serde_json::Value,
}

// MCP JSON-RPC structures
#[derive(Serialize, Deserialize)]
struct JsonRpcRequest {
    jsonrpc: String,
    id: Option<i32>,
    method: String,
    params: Option<serde_json::Value>,
}

#[derive(Serialize)]
struct JsonRpcResponse {
    jsonrpc: String,
    id: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    result: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<serde_json::Value>,
}

// ----------------------------
// MCP Client Logic
// ----------------------------

async fn proxy_mcp_request(client: &Client, base_url: &str, req: MCPRequest) -> Result<serde_json::Value> {
    let url = base_url.trim_end_matches('/');
    
    // Create JSON-RPC request
    let rpc_request = JsonRpcRequest {
        jsonrpc: "2.0".to_string(),
        id: Some(1),
        method: req.method.clone(),
        params: Some(req.params.clone()),
    };

    let res = client
        .post(url)
        .json(&rpc_request)
        .header("Content-Type", "application/json")
        .header("Accept", "application/json, text/event-stream")
        .send()
        .await
        .context("Failed to send request to MCP server")?;

    let status = res.status();
    let body_text = res.text().await.context("Failed to read response body")?;

    if body_text.trim().is_empty() {
        return Err(anyhow::anyhow!("Empty response body from MCP server"));
    }

    // Handle Server-Sent Events (SSE) format
    let mut json_response: serde_json::Value = if body_text.starts_with("event:") || body_text.contains("data:") {
        // Parse SSE format
        let mut json_data = String::new();
        for line in body_text.lines() {
            if line.starts_with("data: ") {
                json_data = line.strip_prefix("data: ").unwrap_or("").to_string();
                break;
            }
        }
        
        if json_data.is_empty() {
            return Err(anyhow::anyhow!("No data found in SSE response"));
        }
        
        serde_json::from_str(&json_data)
            .with_context(|| format!("Failed to parse SSE JSON data. Status: {}, Data: {}", status, json_data))?
    } else {
        // Handle regular JSON response
        serde_json::from_str(&body_text)
            .with_context(|| format!("Failed to parse JSON response. Status: {}, Body: {}", status, body_text))?
    };

    // Decode Unicode escapes in the response content
    if let Some(result) = json_response.get_mut("result") {
        if let Some(content) = result.get_mut("content") {
            if let Some(content_array) = content.as_array_mut() {
                for item in content_array.iter_mut() {
                    if let Some(text) = item.get_mut("text") {
                        if let Some(text_str) = text.as_str() {
                            // Decode common Unicode escapes
                            let decoded = text_str
                                .replace("\\u0027", "'")
                                .replace("\\u0060", "`")
                                .replace("\\u0022", "\"")
                                .replace("\\u003C", "<")
                                .replace("\\u003E", ">")
                                .replace("\\n", "\n");
                            *text = serde_json::Value::String(decoded);
                        }
                    }
                }
            }
        }
    }

    if !status.is_success() {
        eprintln!("[!] MCP server returned error: {}", status);
        eprintln!("[!] Response body: {}", body_text);
    }

    Ok(json_response)
}

// ----------------------------
// Main loop (stdin/stdout)
// ----------------------------

#[tokio::main]
async fn main() -> Result<()> {
    let args: Args = argh::from_env();
    
    if args.verbose {
        eprintln!("[INFO] Starting MCP proxy tool");
        eprintln!("[INFO] Target MCP server: {}", args.url);
        eprintln!("[INFO] Timeout: {} seconds", args.timeout);
    }
    
    let client = Client::builder()
        .timeout(std::time::Duration::from_secs(args.timeout))
        .build()
        .context("Failed to create HTTP client")?;
    
    let stdin = io::stdin();
    let reader = BufReader::new(stdin);
    
    for line in reader.lines() {
        let line = line.context("Failed to read line from stdin")?;
        let line = line.trim();
        
        if line.is_empty() {
            continue;
        }
        
        if args.verbose {
            eprintln!("[DEBUG] Received request: {}", line);
        }
        
        // Parse the JSON-RPC request
        let request: JsonRpcRequest = match serde_json::from_str(&line) {
            Ok(req) => req,
            Err(e) => {
                eprintln!("[!] Failed to parse JSON-RPC request: {}", e);
                continue;
            }
        };
        
        // Handle different MCP methods
        match request.method.as_str() {
            "initialize" => {
                if args.verbose {
                    eprintln!("[INFO] Handling initialize request");
                }
                // Handle MCP initialization
                let response = JsonRpcResponse {
                    jsonrpc: "2.0".to_string(),
                    id: request.id,
                    result: Some(serde_json::json!({
                        "protocolVersion": "2024-11-05",
                        "capabilities": {
                            "tools": {
                                "listChanged": true
                            },
                            "logging": {}
                        },
                        "serverInfo": {
                            "name": "mcp-proxy-tool",
                            "version": "1.0.0"
                        }
                    })),
                    error: None,
                };
                println!("{}", serde_json::to_string(&response)?);
            }
            "notifications/initialized" => {
                if args.verbose {
                    eprintln!("[INFO] Received initialized notification");
                }
                // This is a notification, no response needed
                continue;
            }
            "tools/list" => {
                if args.verbose {
                    eprintln!("[INFO] Proxying tools/list request to {}", args.url);
                }
                // Get the tool list from the remote server
                let mcp_req = MCPRequest {
                    method: "tools/list".to_string(),
                    params: serde_json::Value::Object(serde_json::Map::new()),
                };
                
                match proxy_mcp_request(&client, &args.url, mcp_req).await {
                    Ok(result) => {
                        // Extract the inner result from the Microsoft Learn server response
                        let tools_result = if let Some(inner_result) = result.get("result") {
                            inner_result.clone()
                        } else {
                            result
                        };
                        
                        let response = JsonRpcResponse {
                            jsonrpc: "2.0".to_string(),
                            id: request.id,
                            result: Some(tools_result),
                            error: None,
                        };
                        println!("{}", serde_json::to_string(&response)?);
                    }
                    Err(e) => {
                        if args.verbose {
                            eprintln!("[ERROR] tools/list request failed: {}", e);
                        }
                        let response = JsonRpcResponse {
                            jsonrpc: "2.0".to_string(),
                            id: request.id,
                            result: None,
                            error: Some(serde_json::json!({
                                "code": -32603,
                                "message": format!("Internal error: {}", e)
                            })),
                        };
                        println!("{}", serde_json::to_string(&response)?);
                    }
                }
            }
            "tools/call" => {
                if args.verbose {
                    eprintln!("[INFO] Proxying tools/call request to {}", args.url);
                }
                // Proxy the tool call to the remote server
                let mcp_req = MCPRequest {
                    method: "tools/call".to_string(),
                    params: request.params.unwrap_or_default(),
                };
                
                match proxy_mcp_request(&client, &args.url, mcp_req).await {
                    Ok(result) => {
                        // Extract the inner result from the Microsoft Learn server response
                        let call_result = if let Some(inner_result) = result.get("result") {
                            inner_result.clone()
                        } else {
                            result
                        };
                        
                        let response = JsonRpcResponse {
                            jsonrpc: "2.0".to_string(),
                            id: request.id,
                            result: Some(call_result),
                            error: None,
                        };
                        println!("{}", serde_json::to_string(&response)?);
                    }
                    Err(e) => {
                        if args.verbose {
                            eprintln!("[ERROR] tools/call request failed: {}", e);
                        }
                        let response = JsonRpcResponse {
                            jsonrpc: "2.0".to_string(),
                            id: request.id,
                            result: None,
                            error: Some(serde_json::json!({
                                "code": -32603,
                                "message": format!("Internal error: {}", e)
                            })),
                        };
                        println!("{}", serde_json::to_string(&response)?);
                    }
                }
            }
            _ => {
                if args.verbose {
                    eprintln!("[WARN] Unknown method: {}", request.method);
                }
                // Unknown method
                let response = JsonRpcResponse {
                    jsonrpc: "2.0".to_string(),
                    id: request.id,
                    result: None,
                    error: Some(serde_json::json!({
                        "code": -32601,
                        "message": format!("Method not found: {}", request.method)
                    })),
                };
                println!("{}", serde_json::to_string(&response)?);
            }
        }
    }
    
    Ok(())
}
