#!/usr/bin/env bash
# One-shot bootstrap for nuc Buildkite self-hosted agent.
# Run on nuc after main includes modules/nixos/buildkite.nix.
#
# Usage:
#   ./scripts/nuc-buildkite-bootstrap.sh
#
# Installs the cluster agent token from 1Password
# (eval "$(op signin --account aztec_fuhrmans)" in this shell), then applies NixOS.
# Token-only reinstall: nix run .#nuc-buildkite-install-token

set -euo pipefail

TOKEN_PATH=/etc/buildkite-agent/cluster.token
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORG=connor-m-fuhrman
CLUSTER_ID=c5462976-578e-4d8c-896f-55b800dee742

die() { echo "error: $*" >&2; exit 1; }

[[ "$(hostname -s)" == "nuc" ]] || die "run this on nuc (hostname is $(hostname -s))"

install_cluster_token() {
  local op_bin token tmp
  op_bin=${OP:-}
  if [[ -z "$op_bin" || ! -x "$op_bin" ]]; then
    op_bin=$(command -v op) || die "op not found"
  fi
  sudo mkdir -p /etc/buildkite-agent
  token=$("$op_bin" read "op://Private/Buildkite/credential" 2>/dev/null) \
    || token=$("$op_bin" read "op://Private/Buildkite/password" 2>/dev/null) \
    || die "op read failed — eval \$(op signin --account aztec_fuhrmans)"
  token=$(printf '%s' "$token" | tr -d '[:space:]')
  [[ "$token" == bkct_* ]] || die "expected bkct_ token"
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  printf '%s' "$token" > "$tmp"
  if getent group buildkite-agent-linux >/dev/null 2>&1; then
    sudo install -m 640 -o root -g buildkite-agent-linux "$tmp" "$TOKEN_PATH"
    echo "Installed $TOKEN_PATH (0640, root:buildkite-agent-linux)."
  else
    sudo install -m 600 -o root -g root "$tmp" "$TOKEN_PATH"
    echo "Installed $TOKEN_PATH (0600, root:root)."
    echo "nixos-rebuild below will fix group/mode for buildkite-agent-linux."
  fi
  rm -f "$tmp"
  trap - EXIT
}

if [[ ! -f "$TOKEN_PATH" ]]; then
  echo "Cluster agent token missing — installing from 1Password…"
  install_cluster_token
else
  echo "Token already present at $TOKEN_PATH (re-install: nix run .#nuc-buildkite-install-token)"
fi

echo "Applying NixOS config (sudo required)…"
cd "$REPO_ROOT"
sudo nixos-rebuild switch --flake .#nuc

echo "Buildkite systemd unit:"
systemctl status buildkite-agent-linux.service --no-pager || true
echo "Token readable by buildkite-agent-linux?"
sudo -u buildkite-agent-linux test -r "$TOKEN_PATH" \
  && echo "  yes" || echo "  NO — re-run: sudo nixos-rebuild switch --flake .#nuc"

echo "Done. Confirm agent at:"
echo "  https://buildkite.com/organizations/$ORG/clusters/$CLUSTER_ID"
