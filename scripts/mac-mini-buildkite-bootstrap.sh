#!/usr/bin/env bash
# One-shot bootstrap for mac-mini Buildkite self-hosted agents.
# Run on mac-mini after main includes modules/darwin/buildkite.nix.
#
# Usage:
#   ./scripts/mac-mini-buildkite-bootstrap.sh
#
# Installs the cluster agent token from 1Password (desktop integration or
# eval "$(op signin)" in this shell), then applies nix-darwin.
# Token-only reinstall: nix run .#mac-mini-buildkite-install-token

set -euo pipefail

TOKEN_PATH=/etc/buildkite-agent/cluster.token
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORG=connor-m-fuhrman
CLUSTER_ID=c5462976-578e-4d8c-896f-55b800dee742

die() { echo "error: $*" >&2; exit 1; }

[[ "$(hostname -s)" == "mac-mini" ]] || die "run this on mac-mini (hostname is $(hostname -s))"

install_cluster_token() {
  local op_bin token tmp
  op_bin=${OP:-/opt/homebrew/bin/op}
  [[ -x "$op_bin" ]] || op_bin=$(command -v op) || die "op not found"
  sudo mkdir -p /etc/buildkite-agent
  token=$("$op_bin" read "op://Private/Buildkite/credential" 2>/dev/null) \
    || token=$("$op_bin" read "op://Private/Buildkite/password" 2>/dev/null) \
    || die "op read failed — unlock 1Password app or: eval \$(op signin)"
  token=$(printf '%s' "$token" | tr -d '[:space:]')
  [[ "$token" == bkct_* ]] || die "expected bkct_ token"
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  printf '%s' "$token" > "$tmp"
  if dscl . -read /Groups/buildkite-agent-macos >/dev/null 2>&1; then
    sudo install -m 640 -o root -g buildkite-agent-macos "$tmp" "$TOKEN_PATH"
    echo "Installed $TOKEN_PATH (0640, root:buildkite-agent-macos)."
  else
    sudo install -m 600 -o root -g wheel "$tmp" "$TOKEN_PATH"
    echo "Installed $TOKEN_PATH (0600, root:wheel)."
    echo "darwin-rebuild below will fix group/mode for buildkite-agent-macos."
  fi
  rm -f "$tmp"
  trap - EXIT
}

if [[ ! -f "$TOKEN_PATH" ]]; then
  echo "Cluster agent token missing — installing from 1Password…"
  install_cluster_token
else
  echo "Token already present at $TOKEN_PATH (re-install: nix run .#mac-mini-buildkite-install-token)"
fi

echo "Applying nix-darwin config (sudo required)…"
cd "$REPO_ROOT"
sudo darwin-rebuild switch --flake .#mac-mini

echo "Waiting for linux-builder…"
for _ in $(seq 1 60); do
  if sudo ssh -o BatchMode=yes -o ConnectTimeout=5 linux-builder true 2>/dev/null; then
    break
  fi
  sleep 5
done
sudo ssh linux-builder uname -m

echo "Buildkite launchd jobs (system domain — use sudo):"
sudo launchctl list 2>/dev/null | grep buildkite || true
echo "macOS agent daemon status:"
sudo launchctl print system/org.nixos.buildkite-agent-macos 2>/dev/null | head -25 \
  || echo "  (org.nixos.buildkite-agent-macos not loaded yet)"
echo "Token readable by buildkite-agent-macos?"
sudo -u buildkite-agent-macos test -r "$TOKEN_PATH" \
  && echo "  yes" || echo "  NO — run: sudo chgrp buildkite-agent-macos $TOKEN_PATH && sudo chmod 640 $TOKEN_PATH"
echo "Recent agent log:"
sudo tail -20 /var/lib/buildkite-agent-macos/buildkite-agent.log 2>/dev/null \
  || echo "  (no log yet)"

echo "Done. Confirm agents at:"
echo "  https://buildkite.com/organizations/$ORG/clusters/$CLUSTER_ID"
