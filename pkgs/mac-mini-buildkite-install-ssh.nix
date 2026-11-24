{ writeShellScriptBin }:
writeShellScriptBin "mac-mini-buildkite-install-ssh" ''
  set -euo pipefail

  AGENT_USER=buildkite-agent-macos
  AGENT_HOME=/private/var/lib/$AGENT_USER
  GITHUB_KEY=$AGENT_HOME/.ssh/github_buildkite
  ORIGIN_KEY=$AGENT_HOME/.ssh/origin_cursor
  ORIGIN_KEY_TITLE=mac-mini-buildkite-agent

  die() { echo "error: $*" >&2; exit 1; }

  [[ "$(hostname -s)" == "mac-mini" ]] \
    || die "run on mac-mini only (hostname is $(hostname -s))"

  dscl . -read /Users/$AGENT_USER >/dev/null 2>&1 \
    || die "user $AGENT_USER does not exist — run: darwin-rebuild switch --flake .#mac-mini"

  op_bin=''${OP:-/opt/homebrew/bin/op}
  [[ -x "$op_bin" ]] || op_bin=$(command -v op || true)

  sudo mkdir -p "$AGENT_HOME/.ssh"
  sudo chmod 700 "$AGENT_HOME/.ssh"
  sudo chown "$AGENT_USER:$AGENT_USER" "$AGENT_HOME/.ssh"

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  read_op_secret() {
    local primary=$1
    local password_ref=$2
    [[ -n "$op_bin" ]] || return 1
    "$op_bin" read "$primary" 2>/dev/null \
      || "$op_bin" read "$password_ref" 2>/dev/null \
      || return 1
  }

  install_agent_key() {
    local dest=$1
    local bootstrap=$2
    local op_primary=$3
    local op_password=$4
    local label=$5

    local staged=$tmp/$(basename "$dest")
    local staged_pub="$staged.pub"

    ensure_agent_pubkey() {
      sudo cat "$dest" > "$staged"
      chmod 600 "$staged"
      ssh-keygen -y -f "$staged" > "$staged_pub"
      sudo install -m 644 -o "$AGENT_USER" -g "$AGENT_USER" "$staged_pub" "$dest.pub"
    }

    if sudo test -f "$dest"; then
      echo "Using existing $dest (refreshing .pub only)"
      ensure_agent_pubkey
      return 0
    fi

    local key=""
    if [[ -n "$op_primary" ]]; then
      key=$(read_op_secret "$op_primary" "$op_password" 2>/dev/null) || key=""
    fi
    if [[ -n "$key" ]]; then
      printf '%s\n' "$key" > "$staged"
      echo "Loaded $label private key from 1Password."
    elif [[ -f "$bootstrap" ]]; then
      cp "$bootstrap" "$staged"
      echo "Copied $label bootstrap key from $bootstrap."
    else
      ssh-keygen -t ed25519 -f "$staged" -N "" -C "$AGENT_USER@mac-mini-$label" >/dev/null
      echo "Generated new ed25519 key for $label (not in the Nix store or git)."
    fi
    chmod 600 "$staged"
    ssh-keygen -y -f "$staged" > "$staged_pub"
    sudo install -m 600 -o "$AGENT_USER" -g "$AGENT_USER" "$staged" "$dest"
    sudo install -m 644 -o "$AGENT_USER" -g "$AGENT_USER" "$staged_pub" "$dest.pub"
  }

  # GitHub deploy key for private repos (cv, pi-config, …).
  install_agent_key "$GITHUB_KEY" \
    "''${GITHUB_BOOTSTRAP_KEY:-$HOME/.ssh/github_buildkite}" \
    "op://Private/Buildkite GitHub SSH/private key" \
    "op://Private/Buildkite GitHub SSH/password" \
    github

  # Origin deploy key (optional 1Password item; bootstrap ~/.ssh/buildkite-agent-origin).
  install_agent_key "$ORIGIN_KEY" \
    "''${ORIGIN_BOOTSTRAP_KEY:-$HOME/.ssh/buildkite-agent-origin}" \
    "op://Private/Buildkite Origin SSH/private key" \
    "op://Private/Buildkite Origin SSH/password" \
    origin

  origin_bin=$(command -v origin || true)
  if [[ -z "$origin_bin" && -x "''${HOME:-}/.local/bin/origin" ]]; then
    origin_bin=$HOME/.local/bin/origin
  fi
  if [[ -n "$origin_bin" && -x "$origin_bin" ]]; then
    fp=$(sudo ssh-keygen -lf "$ORIGIN_KEY.pub" | awk '{print $2}')
    if "$origin_bin" ssh-key list 2>/dev/null | grep -F -q "$fp"; then
      echo "Origin already has this public key ($ORIGIN_KEY_TITLE / $fp)."
    else
      sudo cat "$ORIGIN_KEY.pub" > "$tmp/origin_cursor.pub"
      "$origin_bin" ssh-key add --key-file "$tmp/origin_cursor.pub" -t "$ORIGIN_KEY_TITLE"
      echo "Registered Origin public key as '$ORIGIN_KEY_TITLE'."
    fi
  else
    echo "warning: origin CLI not found — register $ORIGIN_KEY.pub with Origin manually." >&2
  fi

  echo
  echo "GitHub deploy key (read-only on connorfuhrman/cv and connorfuhrman/pi-config):"
  sudo cat "$GITHUB_KEY.pub"
  echo
  echo "Origin deploy key:"
  sudo cat "$ORIGIN_KEY.pub"
  echo
  echo "SSH config and known_hosts are managed by darwin-rebuild (modules/darwin/buildkite.nix)."
  echo "Apply after pulling this flake:"
  echo "  sudo darwin-rebuild switch --flake .#mac-mini"
  echo
  echo "Verify as the agent (agent shell is /usr/bin/false — exec ssh/git directly):"
  echo "  sudo -u $AGENT_USER -H ssh -o BatchMode=yes -T git@github.com"
  echo "  sudo -u $AGENT_USER -H ssh -o BatchMode=yes -T git@origin.cursor.com"
  echo "  sudo -u $AGENT_USER -H git ls-remote git@github.com:connorfuhrman/cv.git HEAD"
  echo "  sudo -u $AGENT_USER -H git ls-remote git@github.com:connorfuhrman/pi-config.git HEAD"
  echo "  sudo -u $AGENT_USER -H git ls-remote https://origin.cursor.com/git/connor-fuhrman/t-hex.git HEAD"
''