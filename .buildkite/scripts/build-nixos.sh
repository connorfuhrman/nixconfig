#!/usr/bin/env bash
# Realize a NixOS system closure (not eval-only). rpi-cluster-head is the
# lightest aarch64-linux host here: headless server + Ray head, no desktop or
# Obsidian — still a full closure; first build can take 1–3 h via linux-builder.
set -euo pipefail

TARGET=".#nixosConfigurations.rpi-cluster-head.config.system.build.toplevel"
echo "Building NixOS toplevel: $TARGET"
nix build --accept-flake-config -L "$TARGET"
echo "+++ :white_check_mark: NixOS toplevel build succeeded"
