{ writeShellScriptBin, _1password-cli }:
writeShellScriptBin "mac-mini-buildkite-install-token" ''
  set -euo pipefail

  OP=${_1password-cli}/bin/op
  TOKEN_PATH=/etc/buildkite-agent/cluster.token
  OP_ACCOUNT=Fuhrmans
  OP_URI="op://Private/Buildkite/credential"

  die() {
    echo "error: $*" >&2
    exit 1
  }

  [[ "$(hostname -s)" == "mac-mini" ]] \
    || die "run on mac-mini only (hostname is $(hostname -s))"

  if ! "$OP" account list 2>/dev/null | grep -q .; then
    die "1Password CLI is not signed in. Run: eval \"\$($OP signin --account $OP_ACCOUNT)\""
  fi

  if ! "$OP" account list --account "$OP_ACCOUNT" 2>/dev/null | grep -q .; then
    die "1Password account '$OP_ACCOUNT' is not signed in. Run: eval \"\$($OP signin --account $OP_ACCOUNT)\""
  fi

  token=$("$OP" read --account "$OP_ACCOUNT" "$OP_URI" 2>&1) \
    || die "failed to read cluster agent token from 1Password ($OP_URI). Ensure vault Private, item Buildkite, field credential holds the bkct_ token."

  token=$(printf '%s' "$token" | tr -d "[:space:]")

  [[ -n "$token" ]] || die "token from 1Password is empty"
  [[ "$token" == bkct_* ]] \
    || die "token does not look like a Buildkite cluster agent token (expected bkct_ prefix, got ${token:0:8}…). Personal API tokens belong in a separate field — use the cluster agent token from Buildkite → Agents → Default cluster → Agent tokens."

  echo "Installing cluster agent token to $TOKEN_PATH (sudo required)…"
  sudo mkdir -p /etc/buildkite-agent
  printf '%s' "$token" | sudo install -m 600 -o root -g root /dev/stdin "$TOKEN_PATH"
  echo "Installed $TOKEN_PATH (0600, root-owned)."
''
