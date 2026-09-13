#!/usr/bin/env bash
# Realize generic installer boot media and upload artifacts to Buildkite.
# Usage: build-installer-media.sh <iso|asahi-iso|rpi-iso>
set -euo pipefail

if [[ "${BUILDKITE_AGENT_META_DATA_QUEUE:-}" == "mac-mini-macos" ]]; then
  # shellcheck source=/dev/null
  source "$(dirname "$0")/mac-mini-env.sh"
fi

target="${1:?usage: build-installer-media.sh <iso|asahi-iso|rpi-iso>}"

gc_linux_builder() {
  echo "--- :broom: gc linux-builder (free disk before large installer image)"
  # Best-effort; installer images are multi-GB and the persistent linux-builder
  # VM disk can fill (build #95 / #101 / #120: `0 store paths deleted`).
  ensure_linux_builder_ssh

  log_linux_builder_disk() {
    ssh "${mac_mini_linux_builder_ssh_opts[@]}" builder@linux-builder \
      'df -h /nix/store /tmp 2>/dev/null || df -h' 2>/dev/null || true
  }

  echo "+++ linux-builder disk before gc"
  log_linux_builder_disk

  # Tier 1: daemon GC via ssh-ng store (respects active builds).
  nix store gc --store 'ssh-ng://builder@linux-builder' 2>&1 || true

  # Tier 2: drop old generations then unreachable store paths on the VM.
  ssh "${mac_mini_linux_builder_ssh_opts[@]}" builder@linux-builder \
    'nix-collect-garbage -d --delete-older-than 7d' 2>&1 || true
  ssh "${mac_mini_linux_builder_ssh_opts[@]}" builder@linux-builder \
    'nix-collect-garbage -d' 2>&1 || true

  echo "+++ linux-builder disk after gc"
  log_linux_builder_disk
}

case "${target}" in
  iso)
    # Hosted linux-medium Docker agent is x86_64-linux; explicit system keeps
    # behavior stable if the evaluating system ever changes.
    attr=".#packages.x86_64-linux.iso"
    ;;
  asahi-iso)
    # mac-mini-macos evaluates as aarch64-darwin; installer media lives under
    # aarch64-linux and builds via nix.linux-builder (see build-packages.sh).
    attr=".#packages.aarch64-linux.asahi-iso"
    ;;
  rpi-iso)
    attr=".#packages.aarch64-linux.rpi-iso"
    ;;
  *)
    echo "unknown installer target: ${target}" >&2
    exit 1
    ;;
esac

if [[ "${target}" != "iso" ]]; then
  configure_mac_mini_installer_build
  gc_linux_builder
fi

echo "--- :nix: build ${attr}"
out_path=$(nix build --accept-flake-config -L --no-link --print-out-paths "${attr}")
echo "out path: ${out_path}"

artifacts=()
if [[ -f "${out_path}" ]]; then
  case "${out_path}" in
    *.iso|*.img.zst|*.img) artifacts=("${out_path}") ;;
  esac
elif [[ -d "${out_path}" ]]; then
  mapfile -t artifacts < <(
    find -L "${out_path}" -type f \( -name '*.iso' -o -name '*.img.zst' -o -name '*.img' \) | sort
  )
fi

if [[ ${#artifacts[@]} -eq 0 ]]; then
  echo "+++ :x: no installer media at ${out_path}" >&2
  if [[ -d "${out_path}" ]]; then
    find -L "${out_path}" -type f >&2 || true
  fi
  exit 1
fi

echo "+++ :package: artifacts"
printf '  %s\n' "${artifacts[@]}"

# Copy out of the nix store so hosted Docker steps and artifact_paths can
# see files on the mounted checkout after the container exits.
out_dir="installer-artifacts/${target}"
rm -rf "${out_dir}"
mkdir -p "${out_dir}"
df -h . >&2 || true
for path in "${artifacts[@]}"; do
  dest="${out_dir}/$(basename "${path}")"
  echo "copying ${path} -> ${dest}"
  cp -L "${path}" "${dest}"
done

if command -v buildkite-agent >/dev/null 2>&1; then
  buildkite-agent artifact upload "${out_dir}/*"
fi

echo "+++ :white_check_mark: ${target} build and artifact upload succeeded"
