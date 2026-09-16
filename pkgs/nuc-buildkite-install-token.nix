{ writeShellScriptBin }:
writeShellScriptBin "nuc-buildkite-install-token" ''
  set -euo pipefail

  TOKEN_PATH=/etc/buildkite-agent/cluster.token

  die() { echo "error: $*" >&2; exit 1; }

  [[ "$(hostname -s)" == "nuc" ]] \
    || die "run on nuc only (hostname is $(hostname -s))"

  op_bin=''${OP:-}
  if [[ -z "$op_bin" || ! -x "$op_bin" ]]; then
    op_bin=$(command -v op) || die "op not found"
  fi

  sudo mkdir -p /etc/buildkite-agent
  token=$("$op_bin" read "op://Private/Buildkite/credential" 2>/dev/null) \
    || token=$("$op_bin" read "op://Private/Buildkite/password" 2>/dev/null) \
    || die "op read failed — eval \$(op signin --account aztec_fuhrmans)"
  token=$(printf '%s' "$token" | tr -d '[:space:]')
  [[ "$token" == bkct_* ]] || die "expected bkct_ token"
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  printf '%s' "$token" > "$tmp"
  if getent group buildkite-agent-linux >/dev/null 2>&1; then
    sudo install -m 640 -o root -g buildkite-agent-linux "$tmp" "$TOKEN_PATH"
    echo "Installed $TOKEN_PATH (0640, root:buildkite-agent-linux)."
  else
    sudo install -m 600 -o root -g root "$tmp" "$TOKEN_PATH"
    echo "Installed $TOKEN_PATH (0600, root:root)."
    echo "Run nixos-rebuild switch to grant buildkite-agent-linux read access."
  fi
  rm -f "$tmp"
  trap - EXIT
  if systemctl list-unit-files buildkite-agent-linux.service >/dev/null 2>&1; then
    sudo systemctl try-restart buildkite-agent-linux.service || true
  fi
''
