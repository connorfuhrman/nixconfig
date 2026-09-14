#!/usr/bin/env bash
# Shared setup for Buildkite jobs on queue mac-mini-macos.
#
# nix.linux-builder is reached over SSH as builder@linux-builder (127.0.0.1:31022).
# The buildkite-agent-macos user has no interactive shell history, so ssh-ng and
# direct ssh must not block on host-key prompts (see nixconfig build #116).
set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

export NIX_SSHOPTS='-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new'

configure_mac_mini_docker() {
  # Mirror launchd.daemons.buildkite-agent-macos.environment (buildkite.nix) and
  # podman-docker-compat on runtimePackages (podman.nix). The docker buildkite
  # plugin runs in the environment hook before command scripts (build #150).
  export DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"
  export CONTAINER_HOST="${CONTAINER_HOST:-unix:///var/run/docker.sock}"

  if command -v docker >/dev/null 2>&1; then
    return 0
  fi

  local docker_bin
  for docker_bin in \
    /run/current-system/sw/bin/docker \
    /nix/var/nix/profiles/system-profile/bin/docker; do
    if [[ -x "${docker_bin}" ]]; then
      export PATH="$(dirname "${docker_bin}"):${PATH}"
      return 0
    fi
  done

  echo "docker not found on mac-mini-macos (podman-docker-compat missing from PATH)" >&2
  return 1
}

mac_mini_linux_builder_ssh_opts=(
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=accept-new
)

ensure_linux_builder_ssh() {
  local ssh_dir="${HOME}/.ssh"
  mkdir -p "${ssh_dir}"
  chmod 700 "${ssh_dir}"
  touch "${ssh_dir}/known_hosts"
  chmod 600 "${ssh_dir}/known_hosts"
  # nix-darwin publishes linux-builder on localhost:31022.
  ssh-keyscan -p 31022 -H linux-builder 127.0.0.1 2>/dev/null \
    | grep -v '^#' >> "${ssh_dir}/known_hosts" || true
}

kickstart_linux_builder_vm() {
  # build #129: VM stayed down 30+ min after mac-mini package/nixos steps; nix
  # store info never recovered until launchd restarts org.nixos.linux-builder.
  echo "--- :rocket: kickstart linux-builder VM (launchd)"
  if sudo -n launchctl kickstart -k system/org.nixos.linux-builder 2>/dev/null; then
    echo "+++ kickstarted system/org.nixos.linux-builder"
    return 0
  fi
  if sudo -n launchctl kickstart system/org.nixos.linux-builder 2>/dev/null; then
    echo "+++ started system/org.nixos.linux-builder"
    return 0
  fi
  echo "launchctl kickstart skipped (no passwordless sudo for buildkite agent)"
  return 0
}

linux_builder_probe() {
  # build #142: nix store info --store ssh-ng://... stayed false for 30min while
  # mac-mini package builds still used linux-builder via the daemon. Probe with
  # the same routing a real aarch64-linux build uses.
  nix build --accept-flake-config --max-jobs 1 --no-link --system aarch64-linux \
    --expr 'with import <nixpkgs> { system = "aarch64-linux"; }; hello' \
    &>/dev/null
}

wait_linux_builder_store() {
  # build #126: asahi-iso hit platform mismatch when linux-builder VM was down
  # (Connection closed on 127.0.0.1:31022).
  echo "--- :hourglass: wait for linux-builder"
  kickstart_linux_builder_vm
  local attempt
  for attempt in $(seq 1 180); do
    if linux_builder_probe; then
      echo "+++ linux-builder ready (attempt ${attempt})"
      return 0
    fi
    if (( attempt % 6 == 0 )); then
      kickstart_linux_builder_vm
    fi
    echo "linux-builder not ready (${attempt}/180), sleeping 10s..."
    sleep 10
  done
  echo "linux-builder unreachable after 30 minutes" >&2
  return 1
}

configure_mac_mini_installer_build() {
  # linux-asahi kernel compiles are RAM-heavy on the 8GiB linux-builder VM.
  # These caps apply to the macOS nix client only (--max-jobs / --cores).
  # make -j inside the VM follows nix.linux-builder.config.nix.settings.cores
  # (see modules/darwin/linux-builder.nix); darwin-rebuild on mac-mini required.
  # Start with more client parallelism and step down after compile/OOM failures.
  # Override rung via INSTALLER_PARALLEL_RUNG (1-4) on retry builds.
  local rung="${INSTALLER_PARALLEL_RUNG:-1}"
  local max_jobs cores
  case "${rung}" in
    1) max_jobs=2; cores=6 ;;
    2) max_jobs=1; cores=4 ;;
    3) max_jobs=1; cores=2 ;;
    4) max_jobs=1; cores=1 ;;
    *)
      echo "invalid INSTALLER_PARALLEL_RUNG=${rung} (expected 1-4)" >&2
      exit 1
      ;;
  esac

  export INSTALLER_PARALLEL_RUNG="${rung}"
  export INSTALLER_PARALLEL_MAX_JOBS="${max_jobs}"
  export NIX_BUILD_CORES="${NIX_BUILD_CORES:-${cores}}"
  echo "installer parallelism: rung ${rung} (max-jobs=${max_jobs}, cores=${NIX_BUILD_CORES})"

  local additions
  additions=$'builders-use-substitutes = true\nextra-substituters = https://nixos-apple-silicon.cachix.org https://cache.nixos.org\nextra-trusted-public-keys = nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20= cache.nixos.org-1:6NCHdD59X431o0gWyp1MrYtA1W29A03ad25ERVQ9Fb0= cache.nixos.org-1:fj7Fj4A0i1u5w0Wd6T1cxxXZ30KHC4GKn2ax4P4CjY4='
  additions="${additions}"$'\n'"max-jobs = ${max_jobs}"
  if [[ -n "${NIX_CONFIG:-}" ]]; then
    export NIX_CONFIG="${NIX_CONFIG}"$'\n'"${additions}"
  else
    export NIX_CONFIG="${additions}"
  fi
}
