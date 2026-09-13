{ ... }: {
  # Default dev shell: helper to switch nix-darwin + home-manager in one shot.
  perSystem = { pkgs, ... }: {
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
      ];
    };
  };
}
