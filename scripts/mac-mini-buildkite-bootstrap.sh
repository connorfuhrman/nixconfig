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

install_token_from_1password() {
  if [[ -z "${OP:-}" ]]; then
    if [[ -x /opt/homebrew/bin/op ]]; then
      OP=/opt/homebrew/bin/op
    elif OP=$(command -v op 2>/dev/null); then
      :
    else
      die "1Password CLI (op) not found. Install via Homebrew (brew install 1password-cli) or set OP."
    fi
  fi

  token=$("$OP" read "op://Private/Buildkite/credential" \
    || "$OP" read "op://Private/Buildkite/password") \
    || die "failed to read cluster agent token from 1Password (unlock desktop app or run eval \"\$($OP signin)\")"

  token=$(printf '%s' "$token" | tr -d "[:space:]")
  [[ -n "$token" ]] || die "token from 1Password is empty"
  [[ "$token" == bkct_* ]] \
    || die "token does not look like a Buildkite cluster agent token (expected bkct_ prefix)"

  echo "Installing cluster agent token to $TOKEN_PATH (sudo required)…"
  sudo mkdir -p /etc/buildkite-agent
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  printf '%s' "$token" > "$tmp"
  sudo install -m 600 -o root -g wheel "$tmp" "$TOKEN_PATH"
  echo "Installed $TOKEN_PATH (0600, root:wheel)."
}

if [[ ! -f "$TOKEN_PATH" ]]; then
  echo "Cluster agent token missing — installing from 1Password…"
  install_token_from_1password
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

echo "Buildkite agents (expect buildkite-agent-macos + org.nixos.linux-builder guest agent):"
launchctl list 2>/dev/null | rg buildkite || true

echo "Done. Confirm agents at:"
echo "  https://buildkite.com/organizations/$ORG/clusters/$CLUSTER_ID"
