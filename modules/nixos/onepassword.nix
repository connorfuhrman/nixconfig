{ ... }: {
  # 1Password CLI on every NixOS machine. Sign in once interactively;
  # all credentials live in 1Password.
  flake.modules.nixos.onepassword = { lib, ... }: {
    # 1Password packages are unfree; scope the allowance to just them so
    # evaluation (and `nix flake check`) works without --impure.
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [
        "1password"
        "1password-cli"
        "1password-gui"
        "_1password"
        "_1password-cli"
      ];

    programs._1password.enable = true;
  };

  # 1Password GUI for NixOS desktops; polkit integration lets listed users
  # authenticate system prompts with 1Password.
  flake.modules.nixos.onepassword-gui = { ... }: {
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "connorfuhrman" ];
    };
  };
}
