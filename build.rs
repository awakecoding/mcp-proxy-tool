fn main() {
    // Only embed version info on Windows
    #[cfg(windows)]
    {
        let mut res = winres::WindowsResource::new();
        let version = std::env::var("MCP_VERSION").unwrap_or_else(|_| "0.0.0".to_string());
        res.set("FileVersion", &version)
            .set("ProductVersion", &version)
            .set("CompanyName", "AwakeCoding")
            .set("ProductName", "mcp-proxy-tool")
            .set("FileDescription", "mcp-proxy-tool - Model Context Protocol Proxy Tool")
            .set("LegalCopyright", "Copyright © 2025 AwakeCoding");
        res.compile().expect("Failed to compile Windows resources");
    }
}
