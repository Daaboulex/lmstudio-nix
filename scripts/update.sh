#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="${GITHUB_OUTPUT:-/tmp/update-outputs.env}"
: >"$OUTPUT_FILE"
output() { echo "$1=$2" >>"$OUTPUT_FILE"; }
log() { echo "==> $*"; }
err() { echo "::error::$*"; }

fail() {
  err "$1"
  output "error_type" "$2"
  exit "${3:-1}"
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sources="$repo_root/sources.json"

readonly SYSTEMS=(x86_64-linux aarch64-linux)
readonly CHANNELS=(stable beta bionic server)
readonly VERSION_SHAPE='^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$'
readonly INSTALLER_SCRIPT_URL="https://lmstudio.ai/install.sh"

upstream_arch() {
  case "$1" in
  x86_64-linux) echo x64 ;;
  aarch64-linux) echo arm64 ;;
  *) fail "no upstream architecture for $1" config-error ;;
  esac
}

package_of() {
  case "$1" in
  stable) echo lmstudio ;;
  beta) echo lmstudio-beta ;;
  bionic) echo lmstudio-bionic ;;
  server) echo lmstudio-server ;;
  *) fail "no package for the $1 channel" config-error ;;
  esac
}

appimage_host() {
  case "$1" in
  stable | beta) echo installers.lmstudio.ai ;;
  bionic) echo bionic-installers.lmstudio.ai ;;
  *) fail "no AppImage host for the $1 channel" config-error ;;
  esac
}

appimage_product() {
  case "$1" in
  stable | beta) echo LM-Studio ;;
  bionic) echo Bionic ;;
  *) fail "no AppImage product name for the $1 channel" config-error ;;
  esac
}

redirect_url() {
  case "$1" in
  stable) echo "https://lmstudio.ai/download/latest/linux/$2" ;;
  beta) echo "https://lmstudio.ai/download/latest/linux/$2?channel=beta" ;;
  bionic) echo "https://lmstudio.ai/download/bionic/latest/linux/$2" ;;
  *) fail "no download redirect for the $1 channel" config-error ;;
  esac
}

artifact_url() {
  local channel="$1" system="$2" version="$3" arch
  arch="$(upstream_arch "$system")"
  case "$channel" in
  stable | beta | bionic) echo "https://$(appimage_host "$channel")/linux/${arch}/${version}/$(appimage_product "$channel")-${version}-${arch}.AppImage" ;;
  server) echo "https://llmster.lmstudio.ai/download/${version}-linux-${arch}.full.tar.gz" ;;
  *) fail "no artifact for the ${channel} channel" config-error ;;
  esac
}

appimage_latest() {
  local channel="$1" system="$2" arch url final version host product
  arch="$(upstream_arch "$system")"
  url="$(redirect_url "$channel" "$arch")"
  if ! final="$(curl -sfIL -o /dev/null -w '%{url_effective}' "$url")"; then
    fail "could not resolve the ${channel} ${arch} download redirect at ${url}" network-error 2
  fi
  host="$(appimage_host "$channel")"
  product="$(appimage_product "$channel")"
  local shape="^https://${host//./\\.}/linux/${arch}/([^/]+)/${product}-([^/]+)-${arch}\.AppImage$"
  if ! [[ "$final" =~ $shape ]]; then
    fail "the ${channel} ${arch} redirect no longer lands on a versioned AppImage: ${final}" url-shape
  fi
  version="${BASH_REMATCH[1]}"
  if [ "$version" != "${BASH_REMATCH[2]}" ] || ! [[ "$version" =~ $VERSION_SHAPE ]]; then
    fail "the ${channel} ${arch} redirect names an unexpected version: ${final}" url-shape
  fi
  echo "$version"
}

server_latest() {
  local script versions
  if ! script="$(curl -fsSL "$INSTALLER_SCRIPT_URL")"; then
    fail "could not fetch the llmster installer script at ${INSTALLER_SCRIPT_URL}" network-error 2
  fi
  versions="$(sed -nE 's/^APP_VERSION="([^"]+)"$/\1/p' <<<"$script")"
  if [ "$(wc -l <<<"$versions")" -ne 1 ] || ! [[ "$versions" =~ $VERSION_SHAPE ]]; then
    fail "the llmster installer script no longer states one APP_VERSION: '${versions}'" url-shape
  fi
  echo "$versions"
}

verify_upstream_sha512() {
  local url="$1" store_path="$2" expected actual
  if ! expected="$(curl -fsSL "${url}.sha512")"; then
    fail "could not fetch the upstream checksum at ${url}.sha512" network-error 2
  fi
  expected="${expected//[[:space:]]/}"
  if ! [[ "$expected" =~ ^[0-9a-f]{128}$ ]]; then
    fail "the upstream checksum at ${url}.sha512 is not one sha512 digest: '${expected}'" url-shape
  fi
  actual="$(sha512sum "$store_path")"
  actual="${actual%% *}"
  if [ "$actual" != "$expected" ]; then
    fail "${url} does not match its upstream sha512 (${expected}); the download hashed to ${actual}" checksum-mismatch
  fi
}

pin() {
  local channel="$1" system="$2" version="$3" hash="$4" tmp
  tmp="$(mktemp)"
  jq --arg c "$channel" --arg s "$system" --arg v "$version" --arg h "$hash" \
    '.[$c][$s] = {version: $v, hash: $h}' "$sources" >"$tmp"
  mv "$tmp" "$sources"
}

log "Resolving the latest upstream versions"
server_version="$(server_latest)"
declare -a changed=()
for channel in "${CHANNELS[@]}"; do
  for system in "${SYSTEMS[@]}"; do
    current="$(jq -r --arg c "$channel" --arg s "$system" '.[$c][$s].version // empty' "$sources")"
    if [ -z "$current" ]; then
      fail "sources.json holds no ${channel}/${system} pin" config-error
    fi
    if [ "$channel" = server ]; then
      latest="$server_version"
    else
      latest="$(appimage_latest "$channel" "$system")"
    fi
    if [ "$latest" = "$current" ]; then
      log "${channel}/${system}: ${current} is current"
    else
      log "${channel}/${system}: ${current} -> ${latest}"
      changed+=("${channel} ${system} ${current} ${latest}")
    fi
  done
done

if [ "${#changed[@]}" -eq 0 ]; then
  log "Already up to date"
  output "package_name" "lmstudio"
  output "updated" "false"
  exit 0
fi

read -r head_channel _ head_old head_new <<<"${changed[0]}"
output "package_name" "$(package_of "$head_channel")"
output "updated" "true"
output "old_version" "$head_old"
output "new_version" "$head_new"
output "upstream_url" "https://lmstudio.ai/"

for entry in "${changed[@]}"; do
  read -r channel system _ version <<<"$entry"
  url="$(artifact_url "$channel" "$system" "$version")"
  log "Prefetching ${channel}/${system} ${version} from ${url}"
  if ! prefetched="$(nix store prefetch-file --json "$url")"; then
    fail "could not prefetch ${url}" hash-extraction
  fi
  hash="$(jq -re '.hash' <<<"$prefetched")" || fail "the prefetch of ${url} reported no hash" hash-extraction
  store_path="$(jq -re '.storePath' <<<"$prefetched")" || fail "the prefetch of ${url} reported no store path" hash-extraction
  if [ "$channel" = server ]; then
    verify_upstream_sha512 "$url" "$store_path"
  fi
  pin "$channel" "$system" "$version" "$hash"
  log "${channel}/${system}: pinned ${version} ${hash}"
done

system_here="$(nix eval --impure --raw --expr builtins.currentSystem)"

log "Step 1/3: evaluate every system"
if ! nix flake check --no-build --all-systems; then
  fail "the flake no longer evaluates" eval-error
fi

log "Step 2/3: build every package for ${system_here}"
for package in lmstudio lmstudio-beta lmstudio-bionic lmstudio-server; do
  if ! nix build ".#${package}" --no-link --print-build-logs; then
    fail "${package} failed to build on ${system_here}" build-error
  fi
done

log "Step 3/3: shape of the built outputs"
for package in lmstudio lmstudio-bionic; do
  desktop_out="$(nix build ".#${package}" --no-link --print-out-paths)"
  mapfile -t desktop_files < <(find "${desktop_out}/share/applications" -type f -name '*.desktop')
  if [ "${#desktop_files[@]}" -ne 1 ]; then
    fail "expected one desktop file under ${desktop_out}/share/applications, found ${#desktop_files[@]}" desktop-file
  fi
done
server_out="$(nix build .#lmstudio-server --no-link --print-out-paths)"
if ! lms_report="$("${server_out}/bin/lms" version 2>&1)"; then
  err "${server_out}/bin/lms version failed:"
  echo "$lms_report"
  fail "the built lms does not run" smoke-test
fi
if ! grep -qF -- "CLI commit:" <<<"$lms_report"; then
  err "lms version reported:"
  echo "$lms_report"
  fail "the built lms printed no CLI commit line" smoke-test
fi
if ! llmster_report="$("${server_out}/bin/llmster" version 2>&1)"; then
  err "${server_out}/bin/llmster version failed:"
  echo "$llmster_report"
  fail "the built llmster does not run" smoke-test
fi
server_version_here="$(jq -r --arg s "$system_here" '.server[$s].version' "$sources" | tr '-' '+')"
if ! grep -qF -- "$server_version_here" <<<"$llmster_report"; then
  err "llmster version reported:"
  echo "$llmster_report"
  fail "the built llmster does not report the pinned server version ${server_version_here}" smoke-test
fi

log "Update verified for ${system_here}: $(printf '%s; ' "${changed[@]}")"
exit 0
