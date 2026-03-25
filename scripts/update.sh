#!/usr/bin/env bash
set -euo pipefail

# Custom update script for LM Studio (desktop + server)
# Contract: exit 0 = success/no-update, exit 1 = failed, exit 2 = network error

OUTPUT_FILE="${GITHUB_OUTPUT:-/tmp/update-outputs.env}"
: >"$OUTPUT_FILE"

output() { echo "$1=$2" >>"$OUTPUT_FILE"; }
log() { echo "==> $*"; }
warn() { echo "::warning::$*"; }
err() { echo "::error::$*"; }

PACKAGE="lmstudio"
output "package_name" "$PACKAGE"

# --- Fetch latest desktop version ---
log "Checking latest desktop version..."
DESKTOP_URL="https://lmstudio.ai/download/latest/linux/x64"
LATEST_DESKTOP_VERSION=$(curl -sfL -o /dev/null -w '%{url_effective}' "$DESKTOP_URL" 2>/dev/null | grep -oP '\d+\.\d+\.\d+(-\d+)?' || true)

if [ -z "$LATEST_DESKTOP_VERSION" ]; then
  # Fallback: try scraping the download page
  LATEST_DESKTOP_VERSION=$(curl -sfL "https://lmstudio.ai/" 2>/dev/null | grep -oP 'LM-Studio-\K[\d.]+-?\d*(?=-x64\.AppImage)' | head -1 || true)
fi

if [ -z "$LATEST_DESKTOP_VERSION" ]; then
  warn "Failed to detect latest desktop version"
  output "updated" "false"
  exit 2
fi

log "Latest desktop version: $LATEST_DESKTOP_VERSION"

# --- Get current stable version ---
CURRENT_DESKTOP_VERSION=$(grep -oP 'version\s*=\s*"\K[^"]+' stable.nix | head -1)
log "Current stable version: $CURRENT_DESKTOP_VERSION"

# --- Fetch latest beta version ---
log "Checking latest beta version..."
BETA_URL="https://lmstudio.ai/download/latest/linux/x64?channel=beta"
LATEST_BETA_VERSION=$(curl -sfL -o /dev/null -w '%{url_effective}' "$BETA_URL" 2>/dev/null | grep -oP '\d+\.\d+\.\d+(-\d+|-beta\.\d+)?' || true)

if [ -z "$LATEST_BETA_VERSION" ]; then
  LATEST_BETA_VERSION="$LATEST_DESKTOP_VERSION"
  log "No separate beta version found, using stable: $LATEST_BETA_VERSION"
fi

log "Latest beta version: $LATEST_BETA_VERSION"

CURRENT_BETA_VERSION=$(grep -oP 'version\s*=\s*"\K[^"]+' beta.nix | head -1)
log "Current beta version: $CURRENT_BETA_VERSION"

# --- Fetch latest server version ---
log "Checking latest server version..."
LATEST_SERVER_VERSION=$(curl -sfL -o /dev/null -w '%{url_effective}' "https://llmster.lmstudio.ai/download/latest/linux/x64" 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || true)

if [ -z "$LATEST_SERVER_VERSION" ]; then
  LATEST_SERVER_VERSION="${LATEST_DESKTOP_VERSION%%-*}"
  warn "Could not detect server version independently, using desktop base: $LATEST_SERVER_VERSION"
fi

log "Latest server version: $LATEST_SERVER_VERSION"

CURRENT_SERVER_VERSION=$(grep -oP 'version\s*=\s*"\K[^"]+' server.nix | head -1)
log "Current server version: $CURRENT_SERVER_VERSION"

# --- Compare versions ---
DESKTOP_CHANGED=false
BETA_CHANGED=false
SERVER_CHANGED=false

if [ "$CURRENT_DESKTOP_VERSION" != "$LATEST_DESKTOP_VERSION" ]; then
  DESKTOP_CHANGED=true
  log "Stable update found: $CURRENT_DESKTOP_VERSION → $LATEST_DESKTOP_VERSION"
fi

if [ "$CURRENT_BETA_VERSION" != "$LATEST_BETA_VERSION" ]; then
  BETA_CHANGED=true
  log "Beta update found: $CURRENT_BETA_VERSION → $LATEST_BETA_VERSION"
fi

if [ "$CURRENT_SERVER_VERSION" != "$LATEST_SERVER_VERSION" ]; then
  SERVER_CHANGED=true
  log "Server update found: $CURRENT_SERVER_VERSION → $LATEST_SERVER_VERSION"
fi

if [ "$DESKTOP_CHANGED" = false ] && [ "$BETA_CHANGED" = false ] && [ "$SERVER_CHANGED" = false ]; then
  log "Already up to date"
  output "updated" "false"
  exit 0
fi

output "updated" "true"
output "old_version" "$CURRENT_DESKTOP_VERSION"
output "new_version" "$LATEST_DESKTOP_VERSION"
output "upstream_url" "https://lmstudio.ai/"

DUMMY_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# --- Update stable ---
if [ "$DESKTOP_CHANGED" = true ]; then
  log "Updating stable.nix version..."
  sed -i "s|version = \"$CURRENT_DESKTOP_VERSION\"|version = \"$LATEST_DESKTOP_VERSION\"|" stable.nix

  log "Extracting stable hash..."
  CURRENT_HASH=$(grep -oP 'hash\s*=\s*"sha256-\K[^"]*' stable.nix | head -1)
  sed -i "s|hash = \"sha256-${CURRENT_HASH}\"|hash = \"${DUMMY_HASH}\"|" stable.nix
  BUILD_OUTPUT=$(nix build .#lmstudio 2>&1 || true)
  NEW_HASH=$(echo "$BUILD_OUTPUT" | grep -oP 'got:\s+sha256-\K\S+' | head -1)

  if [ -z "$NEW_HASH" ]; then
    err "Failed to extract stable hash"
    output "error_type" "hash-extraction"
    exit 1
  fi

  sed -i "s|hash = \"${DUMMY_HASH}\"|hash = \"sha256-${NEW_HASH}\"|" stable.nix
  log "Stable hash: sha256-$NEW_HASH"
fi

# --- Update beta ---
if [ "$BETA_CHANGED" = true ]; then
  log "Updating beta.nix version..."
  sed -i "s|version = \"$CURRENT_BETA_VERSION\"|version = \"$LATEST_BETA_VERSION\"|" beta.nix

  log "Extracting beta hash..."
  CURRENT_HASH=$(grep -oP 'hash\s*=\s*"sha256-\K[^"]*' beta.nix | head -1)
  sed -i "s|hash = \"sha256-${CURRENT_HASH}\"|hash = \"${DUMMY_HASH}\"|" beta.nix
  BUILD_OUTPUT=$(nix build .#lmstudio-beta 2>&1 || true)
  NEW_HASH=$(echo "$BUILD_OUTPUT" | grep -oP 'got:\s+sha256-\K\S+' | head -1)

  if [ -z "$NEW_HASH" ]; then
    err "Failed to extract beta hash"
    output "error_type" "hash-extraction"
    exit 1
  fi

  sed -i "s|hash = \"${DUMMY_HASH}\"|hash = \"sha256-${NEW_HASH}\"|" beta.nix
  log "Beta hash: sha256-$NEW_HASH"
fi

# --- Update server ---
if [ "$SERVER_CHANGED" = true ]; then
  log "Updating server.nix version..."
  sed -i "s|version = \"$CURRENT_SERVER_VERSION\"|version = \"$LATEST_SERVER_VERSION\"|" server.nix

  log "Extracting server hash..."
  CURRENT_HASH=$(grep -oP 'hash\s*=\s*"sha256-\K[^"]*' server.nix | head -1)
  sed -i "s|hash = \"sha256-${CURRENT_HASH}\"|hash = \"${DUMMY_HASH}\"|" server.nix
  BUILD_OUTPUT=$(nix build .#lmstudio-server 2>&1 || true)
  NEW_HASH=$(echo "$BUILD_OUTPUT" | grep -oP 'got:\s+sha256-\K\S+' | head -1)

  if [ -z "$NEW_HASH" ]; then
    err "Failed to extract server hash"
    output "error_type" "hash-extraction"
    exit 1
  fi

  sed -i "s|hash = \"${DUMMY_HASH}\"|hash = \"sha256-${NEW_HASH}\"|" server.nix
  log "Server hash: sha256-$NEW_HASH"
fi

# --- Verification chain ---
log "Running verification chain..."

# 1. Eval check
log "Step 1/4: nix flake check --no-build"
if ! nix flake check --no-build 2>&1; then
  err "Eval check failed"
  output "error_type" "eval-error"
  exit 1
fi

# 2. Build desktop
log "Step 2/4: nix build .#lmstudio"
if ! nix build .#lmstudio --no-link --print-build-logs 2>&1; then
  err "Desktop build failed"
  output "error_type" "build-error"
  exit 1
fi

# 3. Desktop file verification
log "Step 3/4: Desktop file verification"
nix build .#lmstudio
find result/share/applications/ -name "*.desktop" 2>/dev/null | head -1 | grep -q . || {
  warn "No desktop file found"
}
rm -f result

# 4. Build + verify server
log "Step 4/4: nix build .#lmstudio-server + ldd check"
if ! nix build .#lmstudio-server --print-build-logs 2>&1; then
  err "Server build failed"
  output "error_type" "build-error"
  exit 1
fi

# ldd check (ignore libcuda — runtime only)
FOUND=$(find result/bin/ \( -type f -o -type l \) -name "lms" 2>/dev/null | head -1)
if [ -n "$FOUND" ] && file "$FOUND" 2>/dev/null | grep -q ELF; then
  MISSING=$(ldd "$FOUND" 2>&1 | grep "not found" | grep -v libcuda || true)
  if [ -n "$MISSING" ]; then
    err "Missing shared libraries:"
    echo "$MISSING"
    output "error_type" "missing-deps"
    exit 1
  fi
fi

# Clean up
rm -f result

log "Update verified: $CURRENT_DESKTOP_VERSION → $LATEST_DESKTOP_VERSION"
exit 0
