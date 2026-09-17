#!/usr/bin/env bash
# Realize the full nix-darwin system closures for every aarch64-darwin host
# (currently macbook and mac-mini). Discovery is driven by `nix eval` on
# pkgs.system so this script does not hardcode host names. NixOS and Linux
# closures are NOT built here — they only get eval-checked (for now).
#
# Runs natively on the mac-mini, which makes its own closure cheap (the
# store is mostly warm). First builds of the other host can take a while.
set -euo pipefail

echo "--- :nix: discover aarch64-darwin darwinConfigurations"
discovered=$(nix eval --accept-flake-config --raw .#darwinConfigurations --apply '
  c:
    let
      inherit (builtins) attrNames concatStringsSep filter sort;
      lt = a: b: a < b;
    in
    concatStringsSep "\n"
      (sort lt (filter (n: (c.${n}.pkgs.system or "") == "aarch64-darwin")
        (attrNames c)))
')

if [[ -z "${discovered}" ]]; then
  echo "+++ :x: darwinConfigurations discovery returned nothing"
  exit 1
fi

echo "${discovered}"

while IFS= read -r name; do
  [[ -z "${name}" ]] && continue
  echo "--- :apple: building darwinConfigurations.${name}"
  nix build --accept-flake-config -L \
    ".#darwinConfigurations.${name}.config.system.build.toplevel"
done <<< "${discovered}"

echo "+++ :white_check_mark: darwin closures built"
