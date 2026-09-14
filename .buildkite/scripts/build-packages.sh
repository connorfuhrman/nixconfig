#!/usr/bin/env bash
# Build every installable in flake `packages` for every system the flake
# exports. Discovery is driven by `nix eval .#packages` so this script does
# not hardcode package names or systems. On mac-mini, linux packages offload
# to nix.linux-builder (aarch64-linux native + x86_64-linux via qemu-user).
set -euo pipefail

if [[ "${BUILDKITE_AGENT_META_DATA_QUEUE:-}" == "mac-mini-macos" ]]; then
  # shellcheck source=/dev/null
  source "$(dirname "$0")/mac-mini-env.sh"
  configure_linux_builder_ssh_client
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

is_linux_system() {
  case "$1" in
    *-linux) return 0 ;;
    *) return 1 ;;
  esac
}

section_emoji() {
  case "$1" in
    *-linux)  printf ':penguin:' ;;
    *-darwin) printf ':apple:' ;;
    *)        printf ':package:' ;;
  esac
}

current_system=""
installables=()

nix_build_installable() {
  local inst="$1"
  local system="$2"
  local -a args=(--accept-flake-config -L)

  if [[ "${BUILDKITE_AGENT_META_DATA_QUEUE:-}" == "mac-mini-macos" ]]; then
    if is_linux_system "${system}"; then
      # build #211/#212: URL-only --builders is ignored; Nix needs platform(s) after
      # the store URI (see nix manual distributed builds). Remote-only + --system.
      args+=(--builders "ssh-ng://builder@linux-builder aarch64-linux,x86_64-linux 1" --max-jobs 0 --system "${system}")
    else
      args+=(--builders '')
    fi
  fi

  if [[ "${BUILDKITE_AGENT_META_DATA_QUEUE:-}" == "mac-mini-macos" ]] \
    && is_linux_system "${system}"; then
    local attempt
    for attempt in $(seq 1 36); do
      if nix build "${args[@]}" "${inst}"; then
        return 0
      fi
      echo "linux-builder busy or unreachable (${attempt}/36), retrying in 10s..."
      sleep 10
    done
    return 1
  fi

  nix build "${args[@]}" "${inst}"
}

build_group() {
  if [[ -z "${current_system}" ]]; then
    return
  fi
  local emoji
  emoji=$(section_emoji "${current_system}")
  echo "--- ${emoji} ${current_system} packages (${#installables[@]} installables) ---"
  if [[ "${BUILDKITE_AGENT_META_DATA_QUEUE:-}" == "mac-mini-macos" ]] \
    && is_linux_system "${current_system}"; then
    # Match installer-media: ~3m wait, single kickstart (not 30m × parallel steps).
    wait_linux_builder_store 18 0
  fi
  local inst
  for inst in "${installables[@]}"; do
    nix_build_installable "${inst}" "${current_system}"
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
