{ ... }: {
  flake.modules.nixos.system = { ... }: {
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

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
      extraGroups = [ "wheel" "networkmanager" "video" "input" ];
      initialPassword = "changeme";
    };

    services.openssh.enable = true;
  };
}
