{ ... }: {
  flake.modules.darwin.system = { pkgs, ... }: {
    # Shared nix-darwin baseline for all macOS hosts.

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # nix-darwin manages the Nix daemon. Set to false if macOS Nix was
    # installed with the Determinate Systems installer instead.
    nix.enable = true;

    # Required by nix-darwin for user-scoped options; must be the macOS username.
    system.primaryUser = "connorfuhrman";

    users.users.connorfuhrman.home = "/Users/connorfuhrman";

    programs.zsh.enable = true;

    environment.systemPackages = with pkgs; [
      git
      vim
      htop
    ];
  };
}
