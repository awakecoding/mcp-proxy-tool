// MCP CLI Proxy
// Reads MCP tool calls from stdin (via JSON), proxies them to an HTTP-based MCP server
// (e.g. https://learn.microsoft.com/api/mcp), and writes responses to stdout.

use anyhow::{Context, Result};
use argh::FromArgs;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::io::{self, BufRead, BufReader};
use std::process::Stdio;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader as TokioBufReader};
use tokio::process::{Child, Command as TokioCommand};
use tokio::fs::OpenOptions;
use tokio::net::UnixStream;

// ----------------------------
// Structs for request/response
// ----------------------------

/// MCP Proxy Tool - Proxies MCP requests to remote HTTP-based or STDIO-based MCP servers
#[derive(FromArgs)]
struct Args {
    /// URL of the remote HTTP-based MCP server to proxy requests to
    #[argh(option, short = 'u')]
    url: Option<String>,
    
    /// command to execute for STDIO-based MCP server
    #[argh(option, short = 'c')]
    command: Option<String>,
    
    /// arguments for the STDIO-based MCP server command
    #[argh(option, short = 'a')]
    args: Option<String>,
    
    /// path to named pipe for named pipe-based MCP server
    #[argh(option, short = 'p')]
    pipe: Option<String>,
    
    /// timeout in seconds for HTTP requests (ignored for STDIO and named pipe)
    #[argh(option, short = 't', default = "30")]
    timeout: u64,
    
    /// enable verbose logging
    #[argh(switch, short = 'v')]
    verbose: bool,
}

#[derive(Debug, Clone)]
enum TransportMode {
    Http,
    Stdio,
    NamedPipe,
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

struct StdioMcpClient {
    process: Child,
    stdin: tokio::process::ChildStdin,
    stdout: TokioBufReader<tokio::process::ChildStdout>,
}

impl StdioMcpClient {
    async fn new(command: &str, args: &[String]) -> Result<Self> {
        let mut cmd = TokioCommand::new(command);
        cmd.args(args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        
        let mut process = cmd.spawn().context("Failed to spawn MCP server process")?;
        
        let stdin = process.stdin.take().context("Failed to get stdin")?;
        let stdout = process.stdout.take().context("Failed to get stdout")?;
        let stdout = TokioBufReader::new(stdout);
        
        Ok(StdioMcpClient {
            process,
            stdin,
            stdout,
        })
    }
    
    async fn send_request(&mut self, request: &str) -> Result<String> {
        // Send request
        self.stdin.write_all(request.as_bytes()).await?;
        self.stdin.write_all(b"\n").await?;
        self.stdin.flush().await?;
        
        // Read response
        let mut response = String::new();
        self.stdout.read_line(&mut response).await?;
        
        Ok(response.trim().to_string())
    }
}

struct NamedPipeMcpClient {
    pipe_path: String,
}

impl NamedPipeMcpClient {
    fn new(pipe_path: &str) -> Self {
        NamedPipeMcpClient {
            pipe_path: pipe_path.to_string(),
        }
    }
    
    async fn send_request(&self, request: &str) -> Result<String> {
        // For named pipes, we open the pipe, write the request, and read the response
        // This assumes the named pipe server can handle request/response pairs
        
        // Try opening as a Unix socket first (more common for MCP servers)
        if let Ok(mut stream) = UnixStream::connect(&self.pipe_path).await {
            // Send request
            stream.write_all(request.as_bytes()).await?;
            stream.write_all(b"\n").await?;
            
            // Read response
            let mut reader = TokioBufReader::new(stream);
            let mut response = String::new();
            reader.read_line(&mut response).await?;
            
            return Ok(response.trim().to_string());
        }
        
        // Fallback to named pipe (FIFO) approach
        // Open the pipe for writing (send request)
        let mut write_file = OpenOptions::new()
            .write(true)
            .open(&self.pipe_path)
            .await
            .with_context(|| format!("Failed to open named pipe for writing: {}", self.pipe_path))?;
            
        write_file.write_all(request.as_bytes()).await?;
        write_file.write_all(b"\n").await?;
        write_file.flush().await?;
        
        // For FIFO pipes, we typically need a separate read pipe or the same pipe
        // This is a simplified implementation - you might need to adjust based on your server
        let read_file = OpenOptions::new()
            .read(true)
            .open(&self.pipe_path)
            .await
            .with_context(|| format!("Failed to open named pipe for reading: {}", self.pipe_path))?;
            
        let mut reader = TokioBufReader::new(read_file);
        let mut response = String::new();
        reader.read_line(&mut response).await?;
        
        Ok(response.trim().to_string())
    }
}

async fn proxy_mcp_request_http(client: &Client, base_url: &str, req: MCPRequest) -> Result<serde_json::Value> {
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

async fn proxy_mcp_request_stdio(stdio_client: &mut StdioMcpClient, req: MCPRequest) -> Result<serde_json::Value> {
    // Create JSON-RPC request
    let rpc_request = JsonRpcRequest {
        jsonrpc: "2.0".to_string(),
        id: Some(1),
        method: req.method.clone(),
        params: Some(req.params.clone()),
    };
    
    let request_json = serde_json::to_string(&rpc_request)?;
    let response_json = stdio_client.send_request(&request_json).await?;
    
    let json_response: serde_json::Value = serde_json::from_str(&response_json)
        .with_context(|| format!("Failed to parse JSON response: {}", response_json))?;
    
    Ok(json_response)
}

async fn proxy_mcp_request_named_pipe(pipe_client: &NamedPipeMcpClient, req: MCPRequest) -> Result<serde_json::Value> {
    // Create JSON-RPC request
    let rpc_request = JsonRpcRequest {
        jsonrpc: "2.0".to_string(),
        id: Some(1),
        method: req.method.clone(),
        params: Some(req.params.clone()),
    };
    
    let request_json = serde_json::to_string(&rpc_request)?;
    let response_json = pipe_client.send_request(&request_json).await?;
    
    let json_response: serde_json::Value = serde_json::from_str(&response_json)
        .with_context(|| format!("Failed to parse JSON response: {}", response_json))?;
    
    Ok(json_response)
}

// ----------------------------
// Main loop (stdin/stdout)
// ----------------------------

#[tokio::main]
async fn main() -> Result<()> {
    let args: Args = argh::from_env();

    // Determine transport mode
    let transport_mode = if args.url.is_some() {
        TransportMode::Http
    } else if args.command.is_some() {
        TransportMode::Stdio
    } else if args.pipe.is_some() {
        TransportMode::NamedPipe
    } else {
        eprintln!("Error: Must specify either -u/--url for HTTP, -c/--command for STDIO, or -p/--pipe for named pipe transport");
        std::process::exit(1);
    };

    if args.verbose {
        eprintln!("[INFO] Starting MCP proxy tool");
        eprintln!("[INFO] Transport mode: {:?}", transport_mode);
        match &transport_mode {
            TransportMode::Http => {
                eprintln!("[INFO] Target MCP server: {}", args.url.as_ref().unwrap());
            }
            TransportMode::Stdio => {
                let cmd_args = args.args.as_deref().unwrap_or("");
                eprintln!("[INFO] Target MCP command: {} {}", 
                    args.command.as_ref().unwrap(),
                    cmd_args);
            }
            TransportMode::NamedPipe => {
                eprintln!("[INFO] Target MCP named pipe: {}", args.pipe.as_ref().unwrap());
            }
        }
        eprintln!("[INFO] Timeout: {} seconds", args.timeout);
    }
    
    let client = Client::builder()
        .timeout(std::time::Duration::from_secs(args.timeout))
        .build()
        .context("Failed to create HTTP client")?;

    // Initialize STDIO client if needed
    let mut stdio_client = if let TransportMode::Stdio = transport_mode {
        let command = args.command.as_ref().unwrap();
        let cmd_args_str = args.args.as_deref().unwrap_or("");
        let cmd_args: Vec<String> = if cmd_args_str.is_empty() {
            Vec::new()
        } else {
            cmd_args_str.split_whitespace().map(|s| s.to_string()).collect()
        };
        Some(StdioMcpClient::new(command, &cmd_args).await?)
    } else {
        None
    };

    // Initialize named pipe client if needed
    let pipe_client = if let TransportMode::NamedPipe = transport_mode {
        let pipe_path = args.pipe.as_ref().unwrap();
        Some(NamedPipeMcpClient::new(pipe_path))
    } else {
        None
    };
    
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
                    match &transport_mode {
                        TransportMode::Http => {
                            eprintln!("[INFO] Proxying tools/list request to {}", args.url.as_ref().unwrap());
                        }
                        TransportMode::Stdio => {
                            eprintln!("[INFO] Proxying tools/list request to STDIO command");
                        }
                        TransportMode::NamedPipe => {
                            eprintln!("[INFO] Proxying tools/list request to named pipe: {}", args.pipe.as_ref().unwrap());
                        }
                    }
                }
                // Get the tool list from the remote server
                let mcp_req = MCPRequest {
                    method: "tools/list".to_string(),
                    params: serde_json::Value::Object(serde_json::Map::new()),
                };
                
                let proxy_result = match &transport_mode {
                    TransportMode::Http => {
                        proxy_mcp_request_http(&client, args.url.as_ref().unwrap(), mcp_req).await
                    }
                    TransportMode::Stdio => {
                        proxy_mcp_request_stdio(stdio_client.as_mut().unwrap(), mcp_req).await
                    }
                    TransportMode::NamedPipe => {
                        proxy_mcp_request_named_pipe(pipe_client.as_ref().unwrap(), mcp_req).await
                    }
                };
                
                match proxy_result {
                    Ok(result) => {
                        // Extract the inner result from the server response
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
                    match &transport_mode {
                        TransportMode::Http => {
                            eprintln!("[INFO] Proxying tools/call request to {}", args.url.as_ref().unwrap());
                        }
                        TransportMode::Stdio => {
                            eprintln!("[INFO] Proxying tools/call request to STDIO command");
                        }
                        TransportMode::NamedPipe => {
                            eprintln!("[INFO] Proxying tools/call request to named pipe: {}", args.pipe.as_ref().unwrap());
                        }
                    }
                }
                // Proxy the tool call to the remote server
                let mcp_req = MCPRequest {
                    method: "tools/call".to_string(),
                    params: request.params.unwrap_or_default(),
                };
                
                let proxy_result = match &transport_mode {
                    TransportMode::Http => {
                        proxy_mcp_request_http(&client, args.url.as_ref().unwrap(), mcp_req).await
                    }
                    TransportMode::Stdio => {
                        proxy_mcp_request_stdio(stdio_client.as_mut().unwrap(), mcp_req).await
                    }
                    TransportMode::NamedPipe => {
                        proxy_mcp_request_named_pipe(pipe_client.as_ref().unwrap(), mcp_req).await
                    }
                };
                
                match proxy_result {
                    Ok(result) => {
                        // Extract the inner result from the server response
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
