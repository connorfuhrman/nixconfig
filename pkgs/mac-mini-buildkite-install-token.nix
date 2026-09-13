{ writeShellScriptBin }:
writeShellScriptBin "mac-mini-buildkite-install-token" ''
  set -euo pipefail

  TOKEN_PATH=/etc/buildkite-agent/cluster.token

  die() { echo "error: $*" >&2; exit 1; }

  [[ "$(hostname -s)" == "mac-mini" ]] \
    || die "run on mac-mini only (hostname is $(hostname -s))"

  op_bin=''${OP:-/opt/homebrew/bin/op}
  [[ -x "$op_bin" ]] || op_bin=$(command -v op) || die "op not found"

  sudo mkdir -p /etc/buildkite-agent
  token=$("$op_bin" read "op://Private/Buildkite/credential" 2>/dev/null) \
    || token=$("$op_bin" read "op://Private/Buildkite/password" 2>/dev/null) \
    || die "op read failed — unlock 1Password app or: eval \$(op signin)"
  token=$(printf '%s' "$token" | tr -d '[:space:]')
  [[ "$token" == bkct_* ]] || die "expected bkct_ token"
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  printf '%s' "$token" > "$tmp"
  if dscl . -read /Groups/buildkite-agent-macos >/dev/null 2>&1; then
    sudo install -m 640 -o root -g buildkite-agent-macos "$tmp" "$TOKEN_PATH"
    echo "Installed $TOKEN_PATH (0640, root:buildkite-agent-macos)."
  else
    sudo install -m 600 -o root -g wheel "$tmp" "$TOKEN_PATH"
    echo "Installed $TOKEN_PATH (0600, root:wheel)."
    echo "Run darwin-rebuild switch to grant buildkite-agent-macos read access."
  fi
  rm -f "$tmp"
  trap - EXIT
''
