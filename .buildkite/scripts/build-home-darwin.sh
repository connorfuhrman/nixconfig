#!/usr/bin/env bash
# Realize the home-manager activation packages for every aarch64-darwin home
# configuration (currently connorfuhrman@macbook and connorfuhrman@mac-mini).
# Discovery is driven by `nix eval` on pkgs.system so this script does not
# hardcode user@host names. Linux homes are NOT built here — they only get
# eval-checked (for now).
set -euo pipefail

echo "--- :nix: discover aarch64-darwin homeConfigurations"
discovered=$(nix eval --accept-flake-config --raw .#homeConfigurations --apply '
  h:
    let
      inherit (builtins) attrNames concatStringsSep filter sort;
      lt = a: b: a < b;
    in
    concatStringsSep "\n"
      (sort lt (filter (n: (h.${n}.pkgs.system or "") == "aarch64-darwin")
        (attrNames h)))
')

if [[ -z "${discovered}" ]]; then
  echo "+++ :x: homeConfigurations discovery returned nothing"
  exit 1
fi

echo "${discovered}"

while IFS= read -r name; do
  [[ -z "${name}" ]] && continue
  echo "--- :house: building homeConfigurations.\"${name}\""
  nix build --accept-flake-config -L \
    ".#homeConfigurations.\"${name}\".activationPackage"
done <<< "${discovered}"

echo "+++ :white_check_mark: home-manager closures built"
