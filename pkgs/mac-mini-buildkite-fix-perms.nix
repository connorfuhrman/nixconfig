{ writeShellScriptBin }:
writeShellScriptBin "mac-mini-buildkite-fix-perms" ''
  set -euo pipefail

  TOKEN_PATH=/etc/buildkite-agent/cluster.token
  AGENT_USER=buildkite-agent-macos
  AGENT_DAEMON=org.nixos.buildkite-agent-macos
  TOKEN_SYNC_DAEMON=org.nixos.buildkite-token-sync

  die() { echo "error: $*" >&2; exit 1; }

  [[ "$(hostname -s)" == "mac-mini" ]] \
    || die "run on mac-mini only (hostname is $(hostname -s))"

  if [[ ! -f "$TOKEN_PATH" ]]; then
    die "cluster token missing at $TOKEN_PATH — run: nix run .#mac-mini-buildkite-install-token"
  fi

  if ! dscl . -read "/Groups/$AGENT_USER" >/dev/null 2>&1; then
    die "$AGENT_USER group missing — run: sudo darwin-rebuild switch --flake .#mac-mini"
  fi

  echo "Fixing token permissions (0640 root:$AGENT_USER)…"
  sudo mkdir -p /etc/buildkite-agent
  sudo chmod 755 /etc/buildkite-agent
  sudo chown root:"$AGENT_USER" "$TOKEN_PATH"
  sudo chmod 640 "$TOKEN_PATH"

  echo -n "Token readable by $AGENT_USER? "
  if sudo -u "$AGENT_USER" test -r "$TOKEN_PATH"; then
    echo "yes"
  else
    die "still not readable — check group membership"
  fi

  echo "Restarting Buildkite launchd daemons…"
  sudo launchctl kickstart -k "system/$AGENT_DAEMON" 2>/dev/null \
    || sudo launchctl bootstrap system "/Library/LaunchDaemons/$AGENT_DAEMON.plist" 2>/dev/null \
    || true
  sudo launchctl kickstart -k "system/$TOKEN_SYNC_DAEMON" 2>/dev/null \
    || sudo launchctl bootstrap system "/Library/LaunchDaemons/$TOKEN_SYNC_DAEMON.plist" 2>/dev/null \
    || true

  sleep 3
  echo
  echo "macOS agent:"
  sudo launchctl print "system/$AGENT_DAEMON" 2>/dev/null \
    | grep -E 'state =|last exit code' || echo "  (daemon not loaded)"
  echo
  echo "Recent macOS agent log:"
  sudo tail -10 /var/lib/buildkite-agent-macos/buildkite-agent.log 2>/dev/null \
    || echo "  (no log yet)"
  echo
  echo "Token sync log:"
  sudo tail -5 /var/log/buildkite-token-sync.log 2>/dev/null \
    || echo "  (no log yet)"
  echo
  echo "Agents should appear at:"
  echo "  https://buildkite.com/organizations/connor-m-fuhrman/clusters/c5462976-578e-4d8c-896f-55b800dee742"
''
