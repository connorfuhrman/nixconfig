{ ... }: {
  flake.modules.darwin.system = { pkgs, ... }: {
    # Shared nix-darwin baseline for all macOS hosts.

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # nix-darwin manages the Nix daemon. Set to false if macOS Nix was
    # installed with the Determinate Systems installer instead.
    nix.enable = true;

    nix.gc = {
      automatic = true;
      interval = { Weekday = 0; Hour = 3; Minute = 15; };
      options = "--delete-older-than 30d";
    };

    # Required by nix-darwin for user-scoped options; must be the macOS username.
    system.primaryUser = "connorfuhrman";

    users.users.connorfuhrman.home = "/Users/connorfuhrman";

    programs.zsh.enable = true;

    # Apple Silicon Homebrew prefix — not added by homebrew.enable alone.
    environment.systemPath = [ "/opt/homebrew/bin" "/opt/homebrew/sbin" ];

    environment.systemPackages = with pkgs; [
      git
      vim
      htop
      mosh
    ];
  };
}
