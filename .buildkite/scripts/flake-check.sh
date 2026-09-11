#!/usr/bin/env bash
set -euo pipefail
nix flake check --accept-flake-config --show-trace -L
