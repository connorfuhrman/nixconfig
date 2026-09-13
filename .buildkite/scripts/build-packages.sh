#!/usr/bin/env bash
# Build overlay packages natively on aarch64-darwin and offload aarch64-linux
# to the mac-mini linux-builder VM (same agent — no separate Linux queue).
set -euo pipefail

echo "--- :apple: aarch64-darwin packages (native) ---"
nix build --accept-flake-config -L \
  .#packages.aarch64-darwin.origin \
  .#packages.aarch64-darwin.cursor-cloud-setup \
  .#packages.aarch64-darwin.mac-mini-buildkite-install-token

echo "--- :penguin: aarch64-linux packages (linux-builder) ---"
nix build --accept-flake-config -L \
  .#packages.aarch64-linux.origin

echo "+++ :white_check_mark: package builds succeeded"
