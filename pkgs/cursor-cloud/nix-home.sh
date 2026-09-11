#!/usr/bin/env bash
# Cursor Cloud install wrapper: bootstrap Nix if missing, then the setup app.
# Idempotent. Runs from the repository root (Cursor's install cwd).
set -euo pipefail

if ! command -v nix >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  elif [ -e "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]; then
    # shellcheck disable=SC1091
    . "${HOME}/.nix-profile/etc/profile.d/nix.sh"
  fi
fi

if [ -n "${NIXCONFIG_FLAKE:-}" ]; then
  flake="$NIXCONFIG_FLAKE"
elif [ -f flake.nix ] && [ -d modules/home ]; then
  flake="."
else
  flake="github:connorfuhrman/nixconfig/develop"
fi

exec nix run "${flake}#cursor-cloud-setup"
