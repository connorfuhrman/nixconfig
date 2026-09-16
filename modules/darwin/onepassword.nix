{ ... }: {
  # 1Password CLI + GUI on macOS via nixpkgs (same official 1Password.app as
  # the Homebrew cask). Sign in once interactively; credentials live in 1Password.
  flake.modules.darwin.onepassword = { lib, pkgs, ... }:
    let
      gui = pkgs._1password-gui;
    in
    {
      nixpkgs.config.allowUnfreePredicate = pkg:
        builtins.elem (lib.getName pkg) [
          "1password"
          "1password-cli"
          "1password-gui"
          "_1password"
          "_1password-cli"
          "obsidian"
          "cursor"
        ];

      programs._1password.enable = true;

      # Do not enable programs._1password-gui: nix-darwin's module runs
      # `install -o root -g wheel -m0555 -d /Applications/1Password.app`, which
      # fails with "Operation not permitted" when a notarized 1Password.app
      # already exists (official installer, Homebrew, or a previous copy).
      # macOS App Management TCC blocks chown/chmod of that bundle even as root.
      # 1Password still requires a real bundle at /Applications/1Password.app
      # (not /Applications/Nix Apps), so we rsync without changing ownership.
      system.activationScripts.applications.text = lib.mkAfter ''
        dest="/Applications/1Password.app"
        src="${gui}/Applications/1Password.app"

        echo "setting up $dest..." >&2

        if [[ -L "$dest" ]]; then
          rm "$dest"
        fi
        if [[ ! -d "$dest" ]]; then
          mkdir -p "$dest"
        fi

        rsyncFlags=(
          --checksum
          --copy-unsafe-links
          --archive
          --delete
          --chmod=-w
          --no-group
          --no-owner
        )

        ${lib.getExe pkgs.rsync} "''${rsyncFlags[@]}" "$src/" "$dest"
      '';
    };
}
