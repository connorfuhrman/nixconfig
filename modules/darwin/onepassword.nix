{ ... }: {
  # 1Password CLI + GUI on macOS via nixpkgs (same official 1Password.app as
  # the Homebrew cask). Sign in once interactively; credentials live in 1Password.
  flake.modules.darwin.onepassword = { lib, ... }: {
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
    programs._1password-gui.enable = true;
  };
}
