#!/usr/bin/env bash
# Build every installable in flake `packages` for every system the flake
# exports. Discovery is driven by `nix eval .#packages` so this script does
# not hardcode package names or systems. On mac-mini, linux packages offload
# to nix.linux-builder (aarch64-linux native + x86_64-linux via qemu-user).
set -euo pipefail

echo "--- :nix: discover flake packages"
discovered=$(nix eval --accept-flake-config --raw .#packages --apply '
  packages:
    let
      inherit (builtins) attrNames concatMap concatStringsSep sort;
      lt = a: b: a < b;
      systems = sort lt (attrNames packages);
      forSystem = system:
        map (name: "${system} ${name}")
          (sort lt (attrNames packages.${system}));
    in
    concatStringsSep "\n" (concatMap forSystem systems)
')

if [[ -z "${discovered}" ]]; then
  echo "+++ :x: flake packages discovery returned nothing"
  exit 1
fi

echo "${discovered}"

section_emoji() {
  case "$1" in
    *-darwin) printf ':apple:' ;;
    *-linux)  printf ':penguin:' ;;
    *)        printf ':package:' ;;
  esac
}

current_system=""
installables=()

build_group() {
  if [[ -z "${current_system}" ]]; then
    return
  fi
  local emoji
  emoji=$(section_emoji "${current_system}")
  echo "--- ${emoji} ${current_system} packages ---"
  nix build --accept-flake-config -L "${installables[@]}"
}

while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  system=${line%% *}
  name=${line#* }
  if [[ "${system}" != "${current_system}" ]]; then
    build_group
    current_system=${system}
    installables=()
  fi
  installables+=(".#packages.${system}.${name}")
done <<< "${discovered}"

build_group

echo "+++ :white_check_mark: package builds succeeded"
