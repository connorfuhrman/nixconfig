{ self, ... }: {
  flake.modules.nixos.system = { pkgs, ... }: {
    # Custom monorepo packages (pkgs/ via flake.overlays.default).
    nixpkgs.overlays = [ self.overlays.default ];

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    zramSwap.enable = true;

    time.timeZone = "America/New_York";
    i18n.defaultLocale = "en_US.UTF-8";

    users.users.connorfuhrman = {
      isNormalUser = true;
      description = "Connor Fuhrman";
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "input"
      ];
      # Bootstrap only — run `passwd` on first login, then prefer SSH keys.
      # Long-term: 1Password SSH agent (docs/plans/1password-ssh-workplan.md).
      initialPassword = "changeme";
    };

    # Enabled on all NixOS hosts for rescue/admin. Server module tightens settings.
    services.openssh.enable = true;

    environment.systemPackages = [ pkgs.mosh ];
  };
}
