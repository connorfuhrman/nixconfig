{ ... }: {
  flake.modules.nixos.system = { ... }: {
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    zramSwap.enable = true;

    time.timeZone = "America/New_York";
    i18n.defaultLocale = "en_US.UTF-8";

    users.users.connor = {
      isNormalUser = true;
      description = "Connor";
      extraGroups = [ "wheel" "networkmanager" "video" "input" ];
      initialPassword = "changeme";
    };

    services.openssh.enable = true;
  };
}