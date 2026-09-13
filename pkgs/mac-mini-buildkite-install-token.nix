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

  op_hint() {
    cat >&2 <<'EOF'
hint: discover your 1Password layout (no secrets printed):
  op account list
  eval "$(op signin --account <shorthand>)"   # omit --account if only one account
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

  op_account=''${OP_ACCOUNT:-}
  if [[ -z "$op_account" && "$account_count" -eq 1 ]]; then
    op_account=$("$OP" account list 2>/dev/null | awk 'NR==2 { print $1 }')
  fi

  op_account_args=()
  if [[ -n "$op_account" ]]; then
    op_account_args=(--account "$op_account")
  fi

  if ! "$OP" whoami "''${op_account_args[@]}" &>/dev/null; then
    if [[ -n "$op_account" ]]; then
      echo "error: 1Password CLI is not signed in (account: $op_account)." >&2
      echo "  Run: eval \"\$($OP signin --account $op_account)\"" >&2
    else
      echo "error: 1Password CLI is not signed in." >&2
      echo "  Run: eval \"\$($OP signin)\"" >&2
    fi
    op_hint
    exit 1
  fi

  read_field() {
    local field=$1
    "$OP" read "''${op_account_args[@]}" "op://$OP_VAULT/$OP_ITEM/$field" 2>/dev/null \
      || return 1
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
    if [[ -n "$op_account" ]]; then
      echo "  account: $op_account" >&2
    fi
    op_hint
    exit 1
  fi

  token=$(printf '%s' "$token" | tr -d "[:space:]")

  [[ -n "$token" ]] || die "token from 1Password is empty"
  [[ "$token" == bkct_* ]] \
    || die "token does not look like a Buildkite cluster agent token (expected bkct_ prefix, got ''${token:0:8}…). Personal API tokens belong in a separate field — use the cluster agent token from Buildkite → Agents → Default cluster → Agent tokens."

  echo "Installing cluster agent token to $TOKEN_PATH (sudo required)…"
  sudo mkdir -p /etc/buildkite-agent
  printf '%s' "$token" | sudo install -m 600 -o root -g root /dev/stdin "$TOKEN_PATH"
  echo "Installed $TOKEN_PATH (0600, root-owned)."
''
