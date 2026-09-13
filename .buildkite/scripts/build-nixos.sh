#!/usr/bin/env bash
# Realize a NixOS system closure (not eval-only). rpi-cluster-head is the
# lightest aarch64-linux host here: headless server + Ray head, no desktop or
# Obsidian — still a full closure; first build can take 1–3 h via linux-builder.
set -euo pipefail

if [[ "${BUILDKITE_AGENT_META_DATA_QUEUE:-}" == "mac-mini-macos" ]]; then
  # shellcheck source=/dev/null
  source "$(dirname "$0")/mac-mini-env.sh"
  wait_for_linux_builder
fi

TARGET=".#nixosConfigurations.rpi-cluster-head.config.system.build.toplevel"
echo "Building NixOS toplevel: $TARGET"
nix build --accept-flake-config -L "$TARGET"
echo "+++ :white_check_mark: NixOS toplevel build succeeded"
