{ ... }: {
  flake.modules.nixos.asahi = { lib, pkgs, config, ... }: {
    hardware.asahi.enable = true;

    hardware.asahi.peripheralFirmwareDirectory = ../../firmware;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = false;

    hardware.graphics.enable = true;

    # Asahi kernel and friends are expensive to compile; pull them from the
    # nixos-apple-silicon binary cache instead.
    nix.settings = {
      extra-substituters = [ "https://nixos-apple-silicon.cachix.org" ];
      extra-trusted-public-keys = [ "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20=" ];
    };

    # boot.kernelParams = [ "appledrm.show_notch=1" ];
    # boot.kernelParams = [ "appledrm.hdmi_audio=1" ];
    # boot.extraModprobeConfig = '' options hid_apple iso_layout=0 '';
  };
}
