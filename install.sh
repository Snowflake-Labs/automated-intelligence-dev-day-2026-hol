#!/usr/bin/env bash
#
# Automated Intelligence HOL — Installer
#
# Installs Snowflake CLI (snow) and Snowflake CoCo CLI (cortex)
# if not already present, then verifies your Snowflake connection.
#
# Usage:
#   bash install.sh
#

set -e

G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' B='\033[1m' N='\033[0m'

msg()  { echo -e "  $*"; }
ok()   { echo -e "  ${G}✓${N} $*"; }
warn() { echo -e "  ${Y}!${N} $*"; }
die()  { echo -e "  ${R}✗${N} $*" >&2; exit 1; }
step() { echo -e "\n${B}$*${N}"; }

check_cmd() {
  command -v "$1" &>/dev/null
}

install_snowflake_cli() {
  if check_cmd snow; then
    ok "Snowflake CLI (snow) already installed — $(snow --version 2>/dev/null || echo 'unknown version')"
    return 0
  fi

  msg "Installing Snowflake CLI..."
  if check_cmd pipx; then
    pipx install snowflake-cli && ok "Snowflake CLI installed via pipx" && return 0
  elif check_cmd pip3; then
    pip3 install snowflake-cli && ok "Snowflake CLI installed via pip3" && return 0
  elif check_cmd pip; then
    pip install snowflake-cli && ok "Snowflake CLI installed via pip" && return 0
  elif check_cmd brew; then
    brew tap snowflakedb/snowflake-cli && brew install snowflake-cli && ok "Snowflake CLI installed via brew" && return 0
  fi
  die "Could not install Snowflake CLI. Install manually: https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation"
}

install_cortex_code_cli() {
  if check_cmd cortex; then
    ok "Snowflake CoCo CLI (cortex) already installed — $(cortex --version 2>/dev/null || echo 'unknown version')"
    return 0
  fi

  msg "Installing Snowflake CoCo CLI..."
  if curl -LsS https://ai.snowflake.com/static/cc-scripts/install.sh | sh; then
    ok "Snowflake CoCo CLI installed"
    return 0
  fi
  die "Could not install Snowflake CoCo CLI. See: https://docs.snowflake.com/en/user-guide/cortex-code"
}

check_snowflake_auth() {
  if [[ -f "$HOME/.snowflake/connections.toml" ]]; then
    ok "Snowflake config found (~/.snowflake/connections.toml)"
    return 0
  elif [[ -f "$HOME/.snowflake/config.toml" ]]; then
    ok "Snowflake config found (~/.snowflake/config.toml)"
    return 0
  elif [[ -n "$SNOWFLAKE_HOST" ]] || [[ -n "$SNOWFLAKE_ACCOUNT" ]]; then
    ok "Snowflake config found (environment variables)"
    return 0
  else
    warn "No Snowflake connection configured."
    msg "  Set one up (shared by both snow and cortex CLIs):"
    msg "    snow connection add"
    msg "  Docs: https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/specify-credentials"
    return 1
  fi
}

echo ""
echo -e "${B}Automated Intelligence HOL — Installer${N}"
echo "────────────────────────────────────────"
echo ""

step "Installing CLIs..."
install_snowflake_cli
install_cortex_code_cli

step "Checking Snowflake connection..."
check_snowflake_auth || true

echo ""
echo -e "${G}All done!${N}"
echo ""
echo "Next steps:"
echo "  snow --version       # Verify Snowflake CLI"
echo "  cortex --version     # Verify Snowflake CoCo CLI"
echo "  snow connection add  # Configure Snowflake connection (if not done)"
echo "  cortex               # Start Snowflake CoCo"
echo ""
