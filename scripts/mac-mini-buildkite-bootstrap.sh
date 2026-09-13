#!/usr/bin/env bash
# One-shot bootstrap for mac-mini Buildkite self-hosted agents.
# Run on mac-mini after main includes modules/darwin/buildkite.nix.
#
# Usage:
#   export BUILDKITE_API_TOKEN='…'   # personal token with write_clusters
#   ./scripts/mac-mini-buildkite-bootstrap.sh
#
# Or create the cluster agent token in the Buildkite UI, then:
#   sudo install -m 600 -o root -g root ./cluster.token /etc/buildkite-agent/cluster.token
#   sudo darwin-rebuild switch --flake .#mac-mini

set -euo pipefail

ORG=connor-m-fuhrman
CLUSTER_ID=c5462976-578e-4d8c-896f-55b800dee742
TOKEN_PATH=/etc/buildkite-agent/cluster.token
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

die() { echo "error: $*" >&2; exit 1; }

[[ "$(hostname -s)" == "mac-mini" ]] || die "run this on mac-mini (hostname is $(hostname -s))"

if [[ ! -f "$TOKEN_PATH" ]]; then
  if [[ -z "${BUILDKITE_API_TOKEN:-}" ]]; then
    cat >&2 <<'EOF'
Cluster agent token missing. Either:

  1. Export BUILDKITE_API_TOKEN (personal API token with write_clusters) and re-run, or
  2. Create a token in Buildkite → Agents → Default cluster → Agent tokens, then:
       sudo mkdir -p /etc/buildkite-agent
       sudo install -m 600 -o root -g root /path/to/token /etc/buildkite-agent/cluster.token
EOF
    exit 1
  fi

  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  curl -sSf -X POST \
    -H "Authorization: Bearer $BUILDKITE_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"description":"mac-mini agents"}' \
    "https://api.buildkite.com/v2/organizations/$ORG/clusters/$CLUSTER_ID/tokens" \
    >"$tmp"

  token=$(jq -er .token "$tmp")
  echo "Creating $TOKEN_PATH (sudo required)…"
  echo -n "$token" | sudo install -m 600 -o root -g root /dev/stdin "$TOKEN_PATH"
  echo "Cluster agent token installed."
else
  echo "Token already present at $TOKEN_PATH"
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
