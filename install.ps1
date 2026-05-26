#
# Automated Intelligence HOL — Installer (Windows)
#
# Installs Snowflake CLI (snow) and Snowflake CoCo CLI (cortex)
# if not already present, then verifies your Snowflake connection.
#
# Usage:
#   .\install.ps1
#

$ErrorActionPreference = "Stop"

function Write-Msg  { param([string]$Text) Write-Host "  $Text" }
function Write-Ok   { param([string]$Text) Write-Host "  " -NoNewline; Write-Host "v" -ForegroundColor Green -NoNewline; Write-Host " $Text" }
function Write-Warn { param([string]$Text) Write-Host "  " -NoNewline; Write-Host "!" -ForegroundColor Yellow -NoNewline; Write-Host " $Text" }
function Write-Err  { param([string]$Text) Write-Host "  " -NoNewline; Write-Host "x" -ForegroundColor Red -NoNewline; Write-Host " $Text"; exit 1 }
function Write-Step { param([string]$Text) Write-Host ""; Write-Host "$Text" -ForegroundColor White }

function Test-Command { param([string]$Name) return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Install-SnowflakeCLI {
    if (Test-Command "snow") {
        Write-Ok "Snowflake CLI (snow) already installed"
        return $true
    }

    Write-Msg "Installing Snowflake CLI..."
    if (Test-Command "pipx") {
        & pipx install snowflake-cli 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Ok "Snowflake CLI installed via pipx"; return $true }
    }
    if (Test-Command "python") {
        & python -m pip install snowflake-cli 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Ok "Snowflake CLI installed via pip"; return $true }
    }
    if (Test-Command "pip") {
        & pip install snowflake-cli 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Ok "Snowflake CLI installed via pip"; return $true }
    }
    if (Test-Command "pip3") {
        & pip3 install snowflake-cli 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Ok "Snowflake CLI installed via pip3"; return $true }
    }
    Write-Err "Could not install Snowflake CLI. See: https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation"
}

function Install-CortexCodeCLI {
    if (Test-Command "cortex") {
        Write-Ok "Snowflake CoCo CLI (cortex) already installed"
        return $true
    }

    Write-Msg "Installing Snowflake CoCo CLI..."
    try {
        $tempScript = Join-Path $env:TEMP "cc_install.ps1"
        Invoke-WebRequest -Uri "https://ai.snowflake.com/static/cc-scripts/install.ps1" -OutFile $tempScript -UseBasicParsing
        & $tempScript
        Remove-Item $tempScript -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -eq 0) { Write-Ok "Snowflake CoCo CLI installed"; return $true }
    }
    catch { }
    Write-Err "Could not install Snowflake CoCo CLI. See: https://docs.snowflake.com/en/user-guide/cortex-code"
}

function Test-SnowflakeAuth {
    $connToml = Join-Path $env:USERPROFILE ".snowflake\connections.toml"
    $cfgToml  = Join-Path $env:USERPROFILE ".snowflake\config.toml"
    if (Test-Path $connToml) {
        Write-Ok "Snowflake config found (~/.snowflake/connections.toml)"
        return $true
    }
    elseif (Test-Path $cfgToml) {
        Write-Ok "Snowflake config found (~/.snowflake/config.toml)"
        return $true
    }
    elseif ($env:SNOWFLAKE_HOST -or $env:SNOWFLAKE_ACCOUNT) {
        Write-Ok "Snowflake config found (environment variables)"
        return $true
    }
    else {
        Write-Warn "No Snowflake connection configured."
        Write-Msg "  Set one up (shared by both snow and cortex CLIs):"
        Write-Msg "    snow connection add"
        Write-Msg "  Docs: https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/specify-credentials"
        return $false
    }
}

Write-Host ""
Write-Host "Automated Intelligence HOL -- Installer" -ForegroundColor White
Write-Host "========================================"
Write-Host ""

Write-Step "Installing CLIs..."
Install-SnowflakeCLI | Out-Null
Install-CortexCodeCLI | Out-Null

Write-Step "Checking Snowflake connection..."
Test-SnowflakeAuth | Out-Null

Write-Host ""
Write-Host "All done!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  snow --version       # Verify Snowflake CLI"
Write-Host "  cortex --version     # Verify Snowflake CoCo CLI"
Write-Host "  snow connection add  # Configure Snowflake connection (if not done)"
Write-Host "  cortex               # Start Snowflake CoCo"
Write-Host ""
