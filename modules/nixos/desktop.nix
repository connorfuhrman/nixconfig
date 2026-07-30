{ ... }: {
  flake.modules.nixos.desktop = { pkgs, ... }: {
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    services.desktopManager.plasma6.enable = true;

    networking.networkmanager = {
      enable = true;
      wifi.backend = "iwd";
    };

    hardware.bluetooth.enable = true;

    environment.systemPackages = with pkgs; [
      firefox
      kdePackages.kate
      kdePackages.ark
      git
      vim
      htop
    ];
  };
}