#!/usr/bin/env bash
# Shared setup for Buildkite jobs on queue mac-mini-macos.
#
# nix.linux-builder is reached over SSH as builder@linux-builder (127.0.0.1:31022).
# The buildkite-agent-macos user has no interactive shell history, so ssh-ng and
# direct ssh must not block on host-key prompts (see nixconfig build #116).
set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

export NIX_SSHOPTS='-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new'

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

configure_mac_mini_installer_build() {
  # build #120: linux-asahi link steps (amdgpu.o, ubifs.o) failed under
  # linux-builder maxJobs=8 on an 8GiB VM; keep installer media builds gentle.
  export NIX_BUILD_CORES="${NIX_BUILD_CORES:-2}"
  local additions=$'max-jobs = 2\nbuilders-use-substitutes = true\nextra-substituters = https://nixos-apple-silicon.cachix.org https://cache.nixos.org\nextra-trusted-public-keys = nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20= cache.nixos.org-1:6NCHdD59X431o0gWyp1MrYtA1W29A03ad25ERVQ9Fb0= cache.nixos.org-1:fj7Fj4A0i1u5w0Wd6T1cxxXZ30KHC4GKn2ax4P4CjY4='
  if [[ -n "${NIX_CONFIG:-}" ]]; then
    export NIX_CONFIG="${NIX_CONFIG}"$'\n'"${additions}"
  else
    export NIX_CONFIG="${additions}"
  fi
}
