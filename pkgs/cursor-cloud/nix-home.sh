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

systemd_is_usable() {
  command -v systemctl >/dev/null 2>&1 \
    && systemctl is-system-running --quiet 2>/dev/null
}

run_determinate_install() {
  local args
  if systemd_is_usable; then
    args=(install linux --no-confirm)
  else
    # Cursor Cloud Agent VMs ship systemctl but systemd is offline; no units.
    args=(install linux --init none --no-confirm)
  fi
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- "${args[@]}"
}

# Determinate's installer returns before nix-daemon is accepting connections.
# A following `nix` as ubuntu then hits: opening lock file .../big-lock: Permission denied.
# Snapshot restores also leave a stale socket with no live daemon process.
ensure_nix_daemon() {
  local sock="/nix/var/nix/daemon-socket/socket"

  nix_ping_ok() {
    nix store ping >/dev/null 2>&1
  }

  clear_stale_socket() {
    if [ -e "$sock" ] && ! nix_ping_ok; then
      sudo rm -f "$sock"
    fi
  }

  if nix_ping_ok; then
    return 0
  fi

  clear_stale_socket

  if systemd_is_usable; then
    sudo systemctl start nix-daemon.service 2>/dev/null || true
    sudo systemctl start determinate-nixd.service 2>/dev/null || true
    if nix_ping_ok; then
      return 0
    fi
    clear_stale_socket
  fi

  if ! nix_ping_ok; then
    local daemon=""
    if command -v nix-daemon >/dev/null 2>&1; then
      daemon="$(command -v nix-daemon)"
    elif [ -x /nix/var/nix/profiles/default/bin/nix-daemon ]; then
      daemon=/nix/var/nix/profiles/default/bin/nix-daemon
    fi
    if [ -n "$daemon" ]; then
      clear_stale_socket
      sudo "$daemon" --daemon >/tmp/nix-daemon.log 2>&1 &
    fi
  fi

  local i
  for i in $(seq 1 50); do
    if nix_ping_ok; then
      return 0
    fi
    sleep 0.2
  done
  echo "nix-home.sh: nix-daemon is not accepting connections (see /tmp/nix-daemon.log)" >&2
  return 1
}

case "${1:-}" in
  start-daemon)
    source_nix_profile
    if ! command -v nix >/dev/null 2>&1; then
      echo "nix-home.sh: nix not on PATH (run install first)" >&2
      exit 1
    fi
    ensure_nix_daemon
    exit 0
    ;;
esac

if ! command -v nix >/dev/null 2>&1; then
  run_determinate_install
fi

source_nix_profile

if ! command -v nix >/dev/null 2>&1; then
  echo "nix-home.sh: nix not on PATH after install" >&2
  exit 1
fi

ensure_nix_daemon

# Determinate ships a CA bundle; Cloud egress/redirects otherwise fail flake fetches
# with: HTTP error 302 (curl error: SSL connect error).
for cert in \
  /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt \
  /etc/ssl/certs/ca-certificates.crt
do
  if [ -f "$cert" ]; then
    export SSL_CERT_FILE="$cert"
    export NIX_SSL_CERT_FILE="$cert"
    break
  fi
done

if [ -n "${NIXCONFIG_FLAKE:-}" ]; then
  flake="$NIXCONFIG_FLAKE"
elif [ -f flake.nix ] && [ -d modules/home ]; then
  flake="."
else
  flake="github:connorfuhrman/nixconfig/develop"
fi

# Flake input downloads can 302 (github.com → codeload) and flake on first try.
attempt=1
while true; do
  if nix run "${flake}#cursor-cloud-setup"; then
    exit 0
  fi
  if [ "$attempt" -ge 5 ]; then
    echo "nix-home.sh: nix run failed after ${attempt} attempts" >&2
    exit 1
  fi
  sleep $((attempt * 2))
  attempt=$((attempt + 1))
done