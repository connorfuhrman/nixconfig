#!/usr/bin/env bash
# Build every installable in flake `packages` for every system the flake
# exports. Discovery is driven by `nix eval .#packages` so this script does
# not hardcode package names or systems. On mac-mini, linux packages offload
# to nix.linux-builder (aarch64-linux native + x86_64-linux via qemu-user).
set -euo pipefail

if [[ "${BUILDKITE_AGENT_META_DATA_QUEUE:-}" == "mac-mini-macos" ]]; then
  # shellcheck source=/dev/null
  source "$(dirname "$0")/mac-mini-env.sh"
  ensure_linux_builder_ssh
fi

echo "--- :nix: discover flake packages"
discovered=$(nix eval --accept-flake-config --raw .#packages --apply '
  packages:
    let
      inherit (builtins) attrNames concatMap concatStringsSep sort filter;
      lt = a: b: a < b;
      # Installer boot media are multi-GB images built (and artifact-uploaded) in
      # dedicated CI steps; building them here duplicates work and can exhaust
      # linux-builder disk during the bulk package sweep.
      skipInstallerMedia = name:
        name == "iso" || name == "asahi-iso" || name == "rpi-iso";
      systems = sort lt (attrNames packages);
      forSystem = system:
        map (name: "${system} ${name}")
          (sort lt (filter (n: ! skipInstallerMedia n) (attrNames packages.${system})));
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
  echo "--- ${emoji} ${current_system} packages (${#installables[@]} installables) ---"
  if [[ "${BUILDKITE_AGENT_META_DATA_QUEUE:-}" == "mac-mini-macos" && "${current_system}" == *-linux ]]; then
    wait_linux_builder_store
  fi
  local inst
  for inst in "${installables[@]}"; do
    nix build --accept-flake-config -L "${inst}"
  done
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
