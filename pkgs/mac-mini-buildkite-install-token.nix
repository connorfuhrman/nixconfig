{ writeShellScriptBin }:
writeShellScriptBin "mac-mini-buildkite-install-token" ''
  set -euo pipefail

  TOKEN_PATH=/etc/buildkite-agent/cluster.token
  OP_VAULT=Private
  OP_ITEM=Buildkite

  die() {
    echo "error: $*" >&2
    exit 1
  }

  # Nix-pinned op lacks the Homebrew CLI sign-in session; use system op until integrated.
  if [[ -z "''${OP:-}" ]]; then
    if [[ -x /opt/homebrew/bin/op ]]; then
      OP=/opt/homebrew/bin/op
    elif OP=$(command -v op 2>/dev/null); then
      :
    else
      die "1Password CLI (op) not found. Install via Homebrew (brew install 1password-cli) or set OP to the op binary path."
    fi
  fi

  op_signin_hint() {
    echo "  With 1Password desktop app unlocked, op read often works without op whoami." >&2
    echo "  Otherwise run: eval \"\$($OP signin)\"" >&2
    echo "  Or:           eval \"\$($OP signin --account <shorthand>)\"" >&2
  }

  op_hint() {
    cat >&2 <<'EOF'
hint: discover your 1Password layout (no secrets printed):
  op account list
  eval "$(op signin)"                        # unscoped (desktop integration / default)
  eval "$(op signin --account <shorthand>)"  # account-scoped session
  op vault list
  op item list --vault Private | rg -i buildkite
  op item get Buildkite --vault Private --format json \
    | jq '{title, vault, fields: [.fields[] | {id, label, purpose, type}]}'
EOF
  }

  [[ "$(hostname -s)" == "mac-mini" ]] \
    || die "run on mac-mini only (hostname is $(hostname -s))"

  account_count=$("$OP" account list 2>/dev/null | awk 'NR>1 { n++ } END { print n + 0 }')
  [[ "$account_count" -gt 0 ]] \
    || die "1Password CLI has no accounts. Run: $OP account add"

  # 1Password sessions may be unscoped (desktop app integration or `op signin`
  # without --account) or account-scoped (`op signin --account <shorthand>`).
  # Prefer unscoped op commands; pass --account only when explicitly requested
  # or as a fallback after an unscoped call fails.
  op_account=''${OP_ACCOUNT:-}

  resolve_op_account() {
    if [[ -n "$op_account" ]]; then
      printf '%s' "$op_account"
    elif [[ "$account_count" -eq 1 ]]; then
      "$OP" account list 2>/dev/null | awk 'NR==2 { print $1 }'
    fi
  }

  read_field() {
    local field=$1
    local uri="op://$OP_VAULT/$OP_ITEM/$field"
    if "$OP" read "$uri" 2>/dev/null; then
      return 0
    fi
    local acct
    acct=$(resolve_op_account || true)
    if [[ -n "$acct" ]]; then
      "$OP" read --account "$acct" "$uri" 2>/dev/null || return 1
    fi
    return 1
  }

  token=
  for field in credential password; do
    if token=$(read_field "$field"); then
      break
    fi
  done

  if [[ -z "$token" ]]; then
    echo "error: failed to read cluster agent token from 1Password." >&2
    echo "  tried: op://$OP_VAULT/$OP_ITEM/credential and op://$OP_VAULT/$OP_ITEM/password" >&2
    acct=$(resolve_op_account || true)
    if [[ -n "$acct" ]]; then
      echo "  account fallback: $acct" >&2
    fi
    echo "  op whoami is not required when desktop integration unlocks op read." >&2
    op_signin_hint
    op_hint
    exit 1
  fi

  token=$(printf '%s' "$token" | tr -d "[:space:]")

  [[ -n "$token" ]] || die "token from 1Password is empty"
  [[ "$token" == bkct_* ]] \
    || die "token does not look like a Buildkite cluster agent token (expected bkct_ prefix, got ''${token:0:8}…). Personal API tokens belong in a separate field — use the cluster agent token from Buildkite → Agents → Default cluster → Agent tokens."

  echo "Installing cluster agent token to $TOKEN_PATH (sudo required)…"
  sudo mkdir -p /etc/buildkite-agent
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  printf '%s' "$token" > "$tmp"
  sudo install -m 600 -o root -g wheel "$tmp" "$TOKEN_PATH"
  echo "Installed $TOKEN_PATH (0600, root:wheel)."
''
