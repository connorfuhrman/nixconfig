#!/usr/bin/env bash
# Enforce repository-wide Nix formatting. `nix fmt` uses the formatter
# exported by the flake (modules/pkgs.nix). `--check` exits non-zero if any
# file would be reformatted, so it must run before expensive builds.
set -euo pipefail

echo "--- :nix: check Nix formatting"
nix fmt . -- --check
echo "+++ :white_check_mark: Nix formatting OK"
