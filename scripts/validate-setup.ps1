# Validation script for mcp-proxy-tool distribution setup
# Checks that all necessary files and configurations are in place

param(
    [switch]$Detailed
)

$ErrorActionPreference = "Stop"

Write-Host "🔍 Validating MCP Proxy Tool Distribution Setup" -ForegroundColor Blue
Write-Host ""

# Check required files
$RequiredFiles = @(
    "Cargo.toml",
    "LICENSE", 
    "README.md",
    "src/main.rs",
    ".github/workflows/ci.yml",
    ".github/workflows/release.yml",
    ".cargo/config.toml",
    "packaging/winget-manifest-template.yaml",
    "packaging/homebrew-formula-template.rb",
    "scripts/prepare-release.ps1",
    "DISTRIBUTION.md"
)

Write-Host "📁 Checking required files..." -ForegroundColor Yellow
$missingFiles = 0

foreach ($file in $RequiredFiles) {
    if (Test-Path $file) {
        Write-Host "✓ $file" -ForegroundColor Green
    } else {
        Write-Host "✗ $file (missing)" -ForegroundColor Red
        $missingFiles++
    }
}

Write-Host ""

# Check Cargo.toml metadata
Write-Host "📦 Checking Cargo.toml metadata..." -ForegroundColor Yellow

if (Test-Path "Cargo.toml") {
    $cargoContent = Get-Content "Cargo.toml" -Raw
    
    $requiredFields = @(
        'name\s*=\s*"mcp-proxy-tool"',
        'version\s*=',
        'authors\s*=',
        'description\s*=',
        'license\s*=\s*"MIT"',
        'repository\s*=',
        'keywords\s*=',
        'categories\s*=',
        '\[profile\.release\]'
    )
    
    foreach ($field in $requiredFields) {
        if ($cargoContent -match $field) {
            $fieldName = $field -replace '\\s.*', '' -replace '\[', '' -replace '\]', ''
            Write-Host "✓ $fieldName" -ForegroundColor Green
        } else {
            $fieldName = $field -replace '\\s.*', '' -replace '\[', '' -replace '\]', ''
            Write-Host "✗ $fieldName (missing or incorrect)" -ForegroundColor Red
            $missingFiles++
        }
    }
} else {
    Write-Host "✗ Cannot validate Cargo.toml - file missing" -ForegroundColor Red
    $missingFiles++
}

Write-Host ""

# Check GitHub Actions workflows
Write-Host "🚀 Checking GitHub Actions workflows..." -ForegroundColor Yellow

$workflows = @("ci.yml", "release.yml")
foreach ($workflow in $workflows) {
    $workflowPath = ".github/workflows/$workflow"
    if (Test-Path $workflowPath) {
        Write-Host "✓ $workflow" -ForegroundColor Green
        
        if ($Detailed) {
            $content = Get-Content $workflowPath -Raw
            if ($content -match 'shell:\s*pwsh') {
                Write-Host "  ✓ Uses PowerShell (pwsh)" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ May not be using PowerShell consistently" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "✗ $workflow (missing)" -ForegroundColor Red
        $missingFiles++
    }
}

Write-Host ""

# Check packaging templates
Write-Host "📋 Checking packaging templates..." -ForegroundColor Yellow

$templates = @(
    @{ Path = "packaging/winget-manifest-template.yaml"; Name = "Winget template" },
    @{ Path = "packaging/homebrew-formula-template.rb"; Name = "Homebrew template" }
)

foreach ($template in $templates) {
    if (Test-Path $template.Path) {
        Write-Host "✓ $($template.Name)" -ForegroundColor Green
        
        if ($Detailed) {
            $content = Get-Content $template.Path -Raw
            $placeholders = @("{VERSION}", "{SHA256", "{RELEASE_DATE}")
            $foundPlaceholders = $placeholders | Where-Object { $content -match [regex]::Escape($_) }
            
            if ($foundPlaceholders.Count -gt 0) {
                Write-Host "  ✓ Contains placeholders: $($foundPlaceholders -join ', ')" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ No placeholders found" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "✗ $($template.Name) (missing)" -ForegroundColor Red
        $missingFiles++
    }
}

Write-Host ""

# Check cross-compilation configuration
Write-Host "🔧 Checking cross-compilation configuration..." -ForegroundColor Yellow

if (Test-Path ".cargo/config.toml") {
    Write-Host "✓ .cargo/config.toml exists" -ForegroundColor Green
    
    if ($Detailed) {
        $cargoConfig = Get-Content ".cargo/config.toml" -Raw
        $targets = @("aarch64-unknown-linux-gnu", "aarch64-pc-windows-msvc", "aarch64-apple-darwin")
        
        foreach ($target in $targets) {
            if ($cargoConfig -match [regex]::Escape("[$target]") -or $cargoConfig -match [regex]::Escape("[target.$target]")) {
                Write-Host "  ✓ Configuration for $target" -ForegroundColor Green
            }
        }
    }
} else {
    Write-Host "✗ .cargo/config.toml (missing)" -ForegroundColor Red
    $missingFiles++
}

Write-Host ""

# Check documentation
Write-Host "📚 Checking documentation..." -ForegroundColor Yellow

$docs = @("README.md", "DISTRIBUTION.md", "LICENSE")
foreach ($doc in $docs) {
    if (Test-Path $doc) {
        Write-Host "✓ $doc" -ForegroundColor Green
        
        if ($Detailed -and $doc -eq "README.md") {
            $readmeContent = Get-Content $doc -Raw
            $sections = @("Installation", "Usage", "Build", "License")
            
            foreach ($section in $sections) {
                if ($readmeContent -match "(?i)#+\s*$section") {
                    Write-Host "  ✓ Contains $section section" -ForegroundColor Green
                } else {
                    Write-Host "  ⚠ Missing $section section" -ForegroundColor Yellow
                }
            }
        }
    } else {
        Write-Host "✗ $doc (missing)" -ForegroundColor Red
        $missingFiles++
    }
}

Write-Host ""

# Check if PowerShell tools are available
Write-Host "🛠 Checking PowerShell environment..." -ForegroundColor Yellow

$tools = @(
    @{ Name = "PowerShell"; Command = "Get-Host" },
    @{ Name = "Invoke-WebRequest"; Command = "Get-Command Invoke-WebRequest" },
    @{ Name = "Get-FileHash"; Command = "Get-Command Get-FileHash" }
)

foreach ($tool in $tools) {
    try {
        Invoke-Expression $tool.Command | Out-Null
        Write-Host "✓ $($tool.Name) available" -ForegroundColor Green
    } catch {
        Write-Host "✗ $($tool.Name) not available" -ForegroundColor Red
        $missingFiles++
    }
}

Write-Host ""

# Summary
if ($missingFiles -eq 0) {
    Write-Host "🎉 All checks passed! Your distribution setup is ready." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Create a git tag: git tag v0.1.0" -ForegroundColor White
    Write-Host "2. Push the tag: git push origin v0.1.0" -ForegroundColor White
    Write-Host "3. GitHub Actions will automatically create the release" -ForegroundColor White
    Write-Host "4. Run prepare-release.ps1 to generate package manager manifests" -ForegroundColor White
    
    exit 0
} else {
    Write-Host "❌ $missingFiles issues found. Please fix them before proceeding." -ForegroundColor Red
    Write-Host ""
    Write-Host "Run with -Detailed flag for more information:" -ForegroundColor Yellow
    Write-Host "  ./scripts/validate-setup.ps1 -Detailed" -ForegroundColor Gray
    
    exit 1
}
