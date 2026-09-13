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
