#!/usr/bin/env bash
# Cursor Cloud install wrapper: bootstrap Nix if missing, then the setup app.
# Idempotent. Runs from the repository root (Cursor's install cwd).
set -euo pipefail

source_nix_profile() {
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  elif [ -e "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]; then
    # shellcheck disable=SC1091
    . "${HOME}/.nix-profile/etc/profile.d/nix.sh"
  fi
}

# Determinate's installer returns before nix-daemon is accepting connections.
# A following `nix` as ubuntu then hits: opening lock file .../big-lock: Permission denied.
ensure_nix_daemon() {
  local sock="/nix/var/nix/daemon-socket/socket"

  nix_ok() {
    [ -S "$sock" ] && nix-store --version >/dev/null 2>&1
  }

  if nix_ok; then
    return 0
  fi

  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl start nix-daemon.service 2>/dev/null || true
    sudo systemctl start determinate-nixd.service 2>/dev/null || true
  fi

  if ! nix_ok; then
    local daemon=""
    if command -v nix-daemon >/dev/null 2>&1; then
      daemon="$(command -v nix-daemon)"
    elif [ -x /nix/var/nix/profiles/default/bin/nix-daemon ]; then
      daemon=/nix/var/nix/profiles/default/bin/nix-daemon
    fi
    if [ -n "$daemon" ]; then
      sudo "$daemon" --daemon >/tmp/nix-daemon.log 2>&1 &
    fi
  fi

  local i
  for i in $(seq 1 50); do
    if nix_ok; then
      return 0
    fi
    sleep 0.2
  done
  echo "nix-home.sh: nix-daemon is not accepting connections" >&2
  return 1
}

if ! command -v nix >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
fi

source_nix_profile

if ! command -v nix >/dev/null 2>&1; then
  echo "nix-home.sh: nix not on PATH after install" >&2
  exit 1
fi

ensure_nix_daemon

if [ -n "${NIXCONFIG_FLAKE:-}" ]; then
  flake="$NIXCONFIG_FLAKE"
elif [ -f flake.nix ] && [ -d modules/home ]; then
  flake="."
else
  flake="github:connorfuhrman/nixconfig/develop"
fi

exec nix run "${flake}#cursor-cloud-setup"
