{ config, ... }: {
  # Default dev shell: helper to switch nix-darwin + home-manager in one shot,
  # plus Buildkite mac-mini provisioning commands that rely on the user's
  # normal shell session (1Password CLI, SSH key files, etc.).
  perSystem = { system, pkgs, ... }:
    let
      myPkgs = config.flake.lib.pkgsFor system;
    in
    {
      devShells.default = pkgs.mkShellNoCC {
        packages = [
          pkgs.home-manager
          (pkgs.writeShellApplication {
            name = "switch-darwin";
            text = ''
            set -euo pipefail

            flake="''${FLAKE:-.}"
            user="''${USER:-connorfuhrman}"

            if [[ $# -ge 1 && "$1" != -* ]]; then
              host="$1"
              shift
            else
              host="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
              host="''${host%%.*}"
            fi

            echo "==> darwin-rebuild switch --flake ''${flake}#''${host} $*"
            sudo darwin-rebuild switch --flake "''${flake}#''${host}" "$@"

            echo "==> home-manager switch --flake ''${flake}#''${user}@''${host} $*"
            # -b backup sets HOME_MANAGER_BACKUP_EXT so existing files
            # (e.g. Nix-installer ~/.zprofile) are renamed, not clobbered.
            home-manager switch -b backup --flake "''${flake}#''${user}@''${host}" "$@"

            echo "==> done (''${user}@''${host})"
          '';
        })
        (pkgs.writeShellApplication {
          name = "mac-mini-buildkite-install-token";
          runtimeInputs = [ pkgs.coreutils ];
          text = ''
            set -euo pipefail

            TOKEN_PATH=/etc/buildkite-agent/cluster.token
            AGENT_GROUP=buildkite-agent-macos

            die() { echo "error: $*" >&2; exit 1; }

            [[ "$(hostname -s)" == "mac-mini" ]] \
              || die "run on mac-mini only (hostname is $(hostname -s))"

            op_bin="''${OP:-$(command -v op 2>/dev/null || true)}"
            [[ -n "$op_bin" && -x "$op_bin" ]] || op_bin=/opt/homebrew/bin/op
            [[ -x "$op_bin" ]] || die "op not found (install 1Password CLI or set \$OP)"

            sudo mkdir -p /etc/buildkite-agent
            if token=$("$op_bin" read "op://Private/Buildkite/credential" 2>/dev/null); then
              :
            elif token=$("$op_bin" read "op://Private/Buildkite/password" 2>/dev/null); then
              :
            else
              die "op read failed — unlock 1Password app or: eval \$(op signin --account aztec_fuhrmans)"
            fi

            token=$(printf '%s' "$token" | tr -d '[:space:]')
            [[ "$token" == bkct_* ]] || die "expected bkct_ token"

            tmp=$(mktemp)
            trap 'rm -f "$tmp"' EXIT
            printf '%s' "$token" > "$tmp"

            if dscl . -read /Groups/"$AGENT_GROUP" >/dev/null 2>&1; then
              sudo install -m 640 -o root -g "$AGENT_GROUP" "$tmp" "$TOKEN_PATH"
              echo "Installed $TOKEN_PATH (0640, root:$AGENT_GROUP)."
            else
              sudo install -m 600 -o root -g wheel "$tmp" "$TOKEN_PATH"
              echo "Installed $TOKEN_PATH (0600, root:wheel)."
              echo "Run darwin-rebuild switch to fix group/mode for $AGENT_GROUP."
            fi
          '';
        })
          (pkgs.writeShellApplication {
            name = "mac-mini-buildkite-install-ssh";
            text = ''
              exec "${myPkgs.mac-mini-buildkite-install-ssh}/bin/mac-mini-buildkite-install-ssh" "$@"
            '';
          })
        ];
      };
    };
}
