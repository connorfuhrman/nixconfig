#!/usr/bin/env bash
# Realize a NixOS system closure (not eval-only). Default is rpi-cluster-head,
# the lightest aarch64-linux host (mac-mini linux-builder). Override with
# NIXOS_TOPLEVEL, e.g. nuc's native x86_64-linux toplevel.
set -euo pipefail

TARGET="${NIXOS_TOPLEVEL:-.#nixosConfigurations.rpi-cluster-head.config.system.build.toplevel}"
echo "Building NixOS toplevel: $TARGET"
nix build --accept-flake-config -L "$TARGET"
echo "+++ :white_check_mark: NixOS toplevel build succeeded"
