{ writeShellScriptBin }:
writeShellScriptBin "nuc-buildkite-install-origin-ssh" ''
  set -euo pipefail

  AGENT_USER=buildkite-agent-linux
  AGENT_HOME=/var/lib/$AGENT_USER
  KEY_PATH=$AGENT_HOME/.ssh/origin_cursor
  PUB_PATH=$KEY_PATH.pub
  ORIGIN_KEY_TITLE=nuc-buildkite-agent
  ORIGIN_HOST_KEY='origin.cursor.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFaMKo6HCtmngBwlSH2ATs8+A6eTr+cCON5RKZX/3/MO'

  die() { echo "error: $*" >&2; exit 1; }

  [[ "$(hostname -s)" == "nuc" ]] \
    || die "run on nuc only (hostname is $(hostname -s))"

  getent passwd "$AGENT_USER" >/dev/null 2>&1 \
    || die "user $AGENT_USER does not exist — nixos-rebuild switch --flake .#nuc first"

  origin_bin=$(command -v origin || true)
  if [[ -z "$origin_bin" && -x "''${HOME:-}/.local/bin/origin" ]]; then
    origin_bin=$HOME/.local/bin/origin
  fi
  [[ -n "$origin_bin" && -x "$origin_bin" ]] \
    || die "origin CLI not found (needed to register the agent public key)"

  op_bin=''${OP:-}
  if [[ -z "$op_bin" || ! -x "$op_bin" ]]; then
    op_bin=$(command -v op || true)
  fi

  sudo mkdir -p "$AGENT_HOME/.ssh"
  sudo chmod 700 "$AGENT_HOME/.ssh"
  sudo chown "$AGENT_USER:$AGENT_USER" "$AGENT_HOME/.ssh"

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  staged=$tmp/origin_cursor

  if sudo test -f "$KEY_PATH"; then
    echo "Using existing $KEY_PATH"
    sudo cat "$KEY_PATH" > "$staged"
  else
    key=""
    if [[ -n "$op_bin" ]]; then
      key=$("$op_bin" read "op://Private/Buildkite Origin SSH/private key" 2>/dev/null) \
        || key=$("$op_bin" read "op://Private/Buildkite Origin SSH/password" 2>/dev/null) \
        || key=""
    fi
    bootstrap=''${HOME}/.ssh/buildkite-agent-origin
    if [[ -n "$key" ]]; then
      printf '%s\n' "$key" > "$staged"
      echo "Loaded private key from 1Password (Buildkite Origin SSH)."
    elif [[ -f "$bootstrap" ]]; then
      cp "$bootstrap" "$staged"
      echo "Using bootstrap key $bootstrap (already registered with Origin)."
    else
      ssh-keygen -t ed25519 -f "$staged" -N "" -C "$AGENT_USER@nuc" >/dev/null
      echo "Generated a new ed25519 key for $AGENT_USER (not in the Nix store or git)."
    fi
    sudo install -m 600 -o "$AGENT_USER" -g "$AGENT_USER" "$staged" "$KEY_PATH"
  fi

  chmod 600 "$staged"
  ssh-keygen -y -f "$staged" > "$staged.pub"
  sudo install -m 644 -o "$AGENT_USER" -g "$AGENT_USER" "$staged.pub" "$PUB_PATH"

  gitconfig=$tmp/gitconfig
  cat > "$gitconfig" <<'EOF'
[url "git@origin.cursor.com:"]
	insteadOf = https://origin.cursor.com/git/
EOF
  sudo install -m 644 -o "$AGENT_USER" -g "$AGENT_USER" "$gitconfig" "$AGENT_HOME/.gitconfig"

  sshconfig=$tmp/config
  cat > "$sshconfig" <<EOF
Host origin.cursor.com
  User git
  IdentityFile $KEY_PATH
  IdentitiesOnly yes
  StrictHostKeyChecking yes
  UserKnownHostsFile $AGENT_HOME/.ssh/known_hosts
EOF
  sudo install -m 644 -o "$AGENT_USER" -g "$AGENT_USER" "$sshconfig" "$AGENT_HOME/.ssh/config"

  known=$tmp/known_hosts
  printf '%s\n' "$ORIGIN_HOST_KEY" > "$known"
  sudo install -m 644 -o "$AGENT_USER" -g "$AGENT_USER" "$known" "$AGENT_HOME/.ssh/known_hosts"

  fp=$(ssh-keygen -lf "$staged.pub" | awk '{print $2}')
  if "$origin_bin" ssh-key list 2>/dev/null | grep -F -q "$fp"; then
    echo "Origin already has this public key ($ORIGIN_KEY_TITLE / $fp)."
  else
    "$origin_bin" ssh-key add --key-file "$staged.pub" -t "$ORIGIN_KEY_TITLE"
    echo "Registered public key with Origin as '$ORIGIN_KEY_TITLE'."
  fi

  echo
  echo "Public key (safe to print):"
  cat "$staged.pub"
  echo
  echo "Installed:"
  echo "  $KEY_PATH"
  echo "  $PUB_PATH"
  echo "  $AGENT_HOME/.gitconfig   (insteadOf https://origin.cursor.com/git/ -> git@origin.cursor.com:)"
  echo "  $AGENT_HOME/.ssh/config"
  echo "Verify as the agent:"
  echo "  sudo -u $AGENT_USER -H ssh -o BatchMode=yes -T git@origin.cursor.com"
  echo "  sudo -u $AGENT_USER -H git ls-remote git@origin.cursor.com:connor-fuhrman/t-hex.git HEAD"
  echo "  sudo -u $AGENT_USER -H git ls-remote https://origin.cursor.com/git/connor-fuhrman/t-hex.git HEAD"
  echo "Optional: store the private key in 1Password item 'Buildkite Origin SSH' (never in git / Nix)."
''
