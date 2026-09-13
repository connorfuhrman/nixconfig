{ writeShellScriptBin, nix }:
writeShellScriptBin "mac-mini-install-nix-store-signing" ''
  set -euo pipefail

  KEY_NAME=mac-mini-1
  SECRET_PATH=/etc/nix/keys/mac-mini-1.secret
  PUBLIC_REL=modules/generic/keys/mac-mini.public
  NIX=${nix}/bin/nix

  die() { echo "error: $*" >&2; exit 1; }

  write_public=true
  sign_system=true
  for arg in "$@"; do
    case "$arg" in
      --no-write-public) write_public=false ;;
      --no-sign) sign_system=false ;;
      -h|--help)
        cat <<EOF
Usage: mac-mini-install-nix-store-signing [--no-write-public] [--no-sign]

One-time mac-mini store-path signing setup:
  - install /etc/nix/keys/mac-mini-1.secret (generate if missing)
  - derive public key and update $PUBLIC_REL when run from flake checkout
  - recursively sign /run/current-system when present

See docs/plans/nix-store-signing.md
EOF
        exit 0
        ;;
      *) die "unknown argument: $arg (try --help)" ;;
    esac
  done

  [[ "$(hostname -s)" == "mac-mini" ]] \
    || die "run on mac-mini only (hostname is $(hostname -s))"

  sudo mkdir -p /etc/nix/keys
  sudo chown root:wheel /etc/nix/keys
  sudo chmod 755 /etc/nix/keys

  if sudo test -f "$SECRET_PATH"; then
    echo "Using existing $SECRET_PATH"
    if ! sudo cat "$SECRET_PATH" | "$NIX" key convert-secret-to-public >/dev/null 2>&1; then
      die "$SECRET_PATH exists but is not a valid Nix signing secret — fix or remove manually"
    fi
  else
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    "$NIX" key generate-secret --key-name "$KEY_NAME" > "$tmp"
    sudo install -m 600 -o root -g wheel "$tmp" "$SECRET_PATH"
    rm -f "$tmp"
    trap - EXIT
    echo "Installed new signing secret at $SECRET_PATH (0600, root:wheel)."
  fi

  public_key=$(sudo cat "$SECRET_PATH" | "$NIX" key convert-secret-to-public)
  public_key=$(printf '%s' "$public_key" | tr -d '[:space:]')

  echo
  echo "Public key (safe to commit):"
  echo "$public_key"
  echo

  wrote_public=false
  flake_root=""
  if $write_public; then
    dir="$PWD"
    while [[ "$dir" != "/" ]]; do
      if [[ -f "$dir/flake.nix" && -f "$dir/$PUBLIC_REL" ]]; then
        flake_root="$dir"
        break
      fi
      dir=$(dirname "$dir")
    done

    if [[ -n "$flake_root" ]]; then
      public_file="$flake_root/$PUBLIC_REL"
      current=$(tr -d '[:space:]' < "$public_file" || true)
      if [[ "$current" == "$public_key" ]]; then
        echo "$PUBLIC_REL already matches the derived public key."
      else
        tmp_pub=$(mktemp)
        printf '%s\n' "$public_key" > "$tmp_pub"
        mv "$tmp_pub" "$public_file"
        wrote_public=true
        echo "Updated $public_file"
      fi
    else
      echo "Not inside a flake checkout — paste the public key above into $PUBLIC_REL"
    fi
  else
    echo "Skipped writing $PUBLIC_REL (--no-write-public)."
  fi

  if $sign_system; then
    if [[ -e /run/current-system ]]; then
      echo "Signing /run/current-system recursively..."
      sudo "$NIX" store sign --recursive --key-file "$SECRET_PATH" /run/current-system
      echo "Signed /run/current-system."
    else
      echo "No /run/current-system — skipped recursive sign."
    fi
  else
    echo "Skipped signing (--no-sign)."
  fi

  echo
  echo "Next steps:"
  if $wrote_public; then
    echo "  1. git add $PUBLIC_REL && git commit"
  fi
  echo "  2. sudo darwin-rebuild switch --flake .#mac-mini"
  echo "  3. Rebuild trusting clients (macbook, mbp14, nuc, …) — see docs/plans/nix-store-signing.md"
  echo "  4. Verify: nix copy --from ssh-ng://mac-mini <path>  (no --no-check-sigs)"
  echo
  echo "Optional: back up $SECRET_PATH in 1Password (never commit the secret)."
''
