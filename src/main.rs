// MCP CLI Proxy
// Reads MCP tool calls from stdin (via JSON), proxies them to an HTTP-based MCP server
// (e.g. https://learn.microsoft.com/api/mcp), and writes responses to stdout.

use anyhow::{Context, Result};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::io::{self, Read};

// ----------------------------
// Structs for request/response
// ----------------------------

#[derive(Serialize, Deserialize)]
struct MCPRequest {
    method: String,
    params: serde_json::Value,
}

#[derive(Serialize)]
struct MCPLog {
    request: MCPRequest,
    response: serde_json::Value,
}

// MCP JSON-RPC structures
#[derive(Serialize)]
struct JsonRpcRequest {
    jsonrpc: String,
    id: i32,
    method: String,
    params: serde_json::Value,
}

// ----------------------------
// MCP Client Logic
// ----------------------------

async fn proxy_mcp_request(client: &Client, base_url: &str, req: MCPRequest) -> Result<MCPLog> {
    let url = base_url.trim_end_matches('/');
    
    // Create JSON-RPC request
    let rpc_request = JsonRpcRequest {
        jsonrpc: "2.0".to_string(),
        id: 1,
        method: req.method.clone(),
        params: req.params.clone(),
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

    Ok(MCPLog {
        request: req,
        response: json_response,
    })
}

// ----------------------------
// Main loop (stdin/stdout)
// ----------------------------

#[tokio::main]
async fn main() -> Result<()> {
    let base_url = "https://learn.microsoft.com/api/mcp"; // configurable later
    let client = Client::new();

    let mut buffer = String::new();
    io::stdin()
        .read_to_string(&mut buffer)
        .context("Failed to read from stdin")?;

    let req: MCPRequest = match serde_json::from_str(&buffer) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("[!] Failed to parse input JSON: {}", e);
            std::process::exit(1);
        }
    };

    match proxy_mcp_request(&client, base_url, req).await {
        Ok(log) => {
            println!("{}", serde_json::to_string_pretty(&log)?);
        }
        Err(e) => {
            eprintln!("[!] Error proxying request: {:?}", e);
        }
    }

    Ok(())
}
