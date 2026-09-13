#!/usr/bin/env bash
# One-shot bootstrap for mac-mini Buildkite self-hosted agents.
# Run on mac-mini after main includes modules/darwin/buildkite.nix.
#
# Usage:
#   ./scripts/mac-mini-buildkite-bootstrap.sh
#
# Installs the cluster agent token from 1Password (sign in first), then applies
# nix-darwin. Token-only install: nix run .#mac-mini-buildkite-install-token

set -euo pipefail

TOKEN_PATH=/etc/buildkite-agent/cluster.token
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORG=connor-m-fuhrman
CLUSTER_ID=c5462976-578e-4d8c-896f-55b800dee742

die() { echo "error: $*" >&2; exit 1; }

[[ "$(hostname -s)" == "mac-mini" ]] || die "run this on mac-mini (hostname is $(hostname -s))"

if [[ ! -f "$TOKEN_PATH" ]]; then
  echo "Cluster agent token missing — installing from 1Password…"
  cd "$REPO_ROOT"
  nix run .#mac-mini-buildkite-install-token
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
