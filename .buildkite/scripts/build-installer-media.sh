#!/usr/bin/env bash
# Realize generic installer boot media and upload artifacts to Buildkite.
# Usage: build-installer-media.sh <iso|asahi-iso|rpi-iso>
set -euo pipefail

if [[ "${BUILDKITE_AGENT_META_DATA_QUEUE:-}" == "mac-mini-macos" ]]; then
  # shellcheck source=/dev/null
  source "$(dirname "$0")/mac-mini-env.sh"
fi

target="${1:?usage: build-installer-media.sh <iso|asahi-iso|rpi-iso>}"

# mac-mini Buildkite jobs export a minimal PATH; nix profile find is not guaranteed.
find_installer_media() {
  local root="$1"
  local find_bin="/usr/bin/find"
  if [[ ! -x "${find_bin}" ]]; then
    find_bin="$(command -v find || true)"
  fi
  if [[ -z "${find_bin}" ]]; then
    echo "find: command not found (need /usr/bin/find on PATH)" >&2
    return 127
  fi
  "${find_bin}" -L "${root}" -type f \( -name '*.iso' -o -name '*.img.zst' -o -name '*.img' \)
}

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

  # Tier 1: daemon GC via ssh-ng store (works without agent reading builder_ed25519).
  for _ in 1 2 3; do
    nix store gc --store 'ssh-ng://builder@linux-builder' 2>&1 || true
  done

  # Tier 2: direct ssh GC when the agent can read builder@linux-builder keys.
  ssh "${mac_mini_linux_builder_ssh_opts[@]}" builder@linux-builder \
    'nix-collect-garbage -d --delete-older-than 7d' 2>&1 || true
  ssh "${mac_mini_linux_builder_ssh_opts[@]}" builder@linux-builder \
    'nix-collect-garbage -d' 2>&1 || true
  nix store gc --store 'ssh-ng://builder@linux-builder' 2>&1 || true

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

iso_on_mac_mini=false
if [[ "${target}" == "iso" && "${BUILDKITE_AGENT_META_DATA_QUEUE:-}" == "mac-mini-macos" ]]; then
  iso_on_mac_mini=true
fi

if [[ "${target}" != "iso" || "${iso_on_mac_mini}" == "true" ]]; then
  configure_mac_mini_installer_build
  # VM down without sudo kickstart: fail fast (~3m) instead of 30m × parallel steps.
  wait_linux_builder_store 18 0
  gc_linux_builder
fi

echo "--- :nix: build ${attr}"
nix_build_args=(--accept-flake-config -L --no-link --print-out-paths)
if [[ "${BUILDKITE_AGENT_META_DATA_QUEUE:-}" == "mac-mini-macos" ]]; then
  # build #228: --system without ssh-ng store made the darwin client run Linux
  # derivations locally (bash: Undefined error: 0). Match build-packages.sh / turing-pi.
  installer_system=aarch64-linux
  if [[ "${target}" == "iso" ]]; then
    installer_system=x86_64-linux
  fi
  nix_build_args+=(--impure --store 'ssh-ng://builder@linux-builder' --eval-store auto \
    --max-jobs "${INSTALLER_PARALLEL_MAX_JOBS:-1}" --cores "${NIX_BUILD_CORES:-6}" --system "${installer_system}")
elif [[ "${target}" != "iso" ]]; then
  # Mirror configure_mac_mini_installer_build caps on the CLI (build #120/#125).
  nix_build_args+=(--max-jobs "${INSTALLER_PARALLEL_MAX_JOBS:-1}" --cores "${NIX_BUILD_CORES:-6}" --system aarch64-linux)
fi
out_path=$(nix build "${nix_build_args[@]}" "${attr}")
echo "out path: ${out_path}"

# Copy out of the nix store (or linux-builder) so artifact_paths see files on checkout.
out_dir="installer-artifacts/${target}"
rm -rf "${out_dir}"
mkdir -p "${out_dir}"
df -h . /nix/store 2>/dev/null || df -h . >&2 || true

copy_installer_from_linux_builder_ssh() {
  # build #231: nix copy --to auto exited 1 with [0 copied (1.4 GiB)] and no stderr;
  # bytes stay on the VM until we scp them into the checkout.
  configure_linux_builder_ssh_client
  local remote_list
  remote_list=$(
    ssh "${mac_mini_linux_builder_ssh_opts[@]}" builder@linux-builder \
      "set -euo pipefail; p='${out_path}'; if [[ -f \"\${p}\" ]]; then echo \"\${p}\"; elif [[ -d \"\${p}\" ]]; then /usr/bin/find -L \"\${p}\" -type f \\( -name '*.iso' -o -name '*.img.zst' -o -name '*.img' \\) | sort; else exit 2; fi"
  ) || {
    echo "+++ :x: installer path missing on linux-builder: ${out_path}" >&2
    return 1
  }
  local path
  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    local dest="${out_dir}/$(basename "${path}")"
    echo "scp linux-builder:${path} -> ${dest}"
    scp "${mac_mini_linux_builder_ssh_opts[@]}" "builder@linux-builder:${path}" "${dest}"
  done <<< "${remote_list}"
}

artifacts=()
staged_via_ssh=false

# ssh-ng builds live on linux-builder; eval-store auto records the path locally
# but the ISO/img bytes are remote until copied (build #230/#231).
if [[ "${BUILDKITE_AGENT_META_DATA_QUEUE:-}" == "mac-mini-macos" ]]; then
  configure_linux_builder_ssh_client
  echo "--- :arrow_down: copy installer output from linux-builder store to local"
  copy_err=""
  if ! copy_err=$(nix copy --impure \
    --from 'ssh-ng://builder@linux-builder' \
    --to 'auto' \
    "${out_path}^*" 2>&1); then
    echo "nix copy failed: ${copy_err}"
  else
    echo "${copy_err}"
  fi
fi

if [[ -f "${out_path}" ]]; then
  case "${out_path}" in
    *.iso|*.img.zst|*.img) artifacts=("${out_path}") ;;
  esac
elif [[ -d "${out_path}" ]]; then
  mapfile -t artifacts < <(find_installer_media "${out_path}" | sort)
fi

if [[ ${#artifacts[@]} -eq 0 ]]; then
  echo "+++ :warning: no local installer media at ${out_path}; staging over ssh"
  copy_installer_from_linux_builder_ssh
  staged_via_ssh=true
  mapfile -t artifacts < <(find_installer_media "${out_dir}" | sort)
fi

if [[ ${#artifacts[@]} -eq 0 ]]; then
  echo "+++ :x: no installer media at ${out_path}" >&2
  if [[ -d "${out_path}" ]]; then
    find_installer_media "${out_path}" >&2 || true
  fi
  exit 1
fi

echo "+++ :package: artifacts"
printf '  %s\n' "${artifacts[@]}"

if [[ "${staged_via_ssh}" != "true" ]]; then
  for path in "${artifacts[@]}"; do
    dest="${out_dir}/$(basename "${path}")"
    echo "copying ${path} -> ${dest}"
    cp -L "${path}" "${dest}"
  done
fi

if command -v buildkite-agent >/dev/null 2>&1; then
  buildkite-agent artifact upload "${out_dir}/*"
fi

echo "+++ :white_check_mark: ${target} build and artifact upload succeeded"
