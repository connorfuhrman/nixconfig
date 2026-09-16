#!/usr/bin/env bash
# Realize the ubuntu@cursor-cloud home closure and cursor-cloud-setup app.
set -euo pipefail

nix build --accept-flake-config -L \
  .#homeConfigurations.\"ubuntu@cursor-cloud\".activationPackage \
  .#cursor-cloud-setup

echo "cursor-closure: ubuntu@cursor-cloud activationPackage and cursor-cloud-setup built"
