# Installer media helpers: extend a live NixOS host closure with ISO or SD-image
# modules without baking installer bits into the bootable system closure.
{ inputs, ... }:
let
  nixpkgs = inputs.nixpkgs;
  nixosModules = nixpkgs + "/nixos/modules";
in
{
  flake.modules.nixos.iso-x86 = { lib, ... }: {
    imports = [
      "${nixosModules}/installer/cd-dvd/installation-cd-minimal.nix"
    ];

    # Host _hardware-configuration.nix templates set a disk layout and systemd-boot;
    # installation media must own boot + filesystems instead.
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  };

  flake.modules.nixos.iso-asahi = { lib, ... }: {
    imports = [
      "${inputs.nixos-apple-silicon}/iso-configuration"
    ];

    # Match nixos-apple-silicon installer-bootstrap (INSTALL.md option B).
    hardware.asahi.pkgsSystem = "aarch64-linux";
    nixpkgs.hostPlatform.system = "aarch64-linux";
  };

  flake.modules.nixos.iso-sd-aarch64 = { lib, modulesPath, ... }: {
    imports = [
      (modulesPath + "/installer/sd-card/sd-image-aarch64-installer.nix")
    ];

    boot.loader.grub.enable = lib.mkForce false;
    boot.loader.generic-extlinux-compatible.enable = lib.mkForce false;
  };

  flake.lib = {
    # Extend an evaluated nixosConfiguration with installer-only modules.
    extendNixosInstaller = baseConfig: installerModule:
      baseConfig.extendModules {
        modules = [ installerModule ];
      };

    # Build a host module, then extend it — avoids relying on self ordering.
    nixosInstallerFromHost = { system, hostModule, installerModule }:
      (nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ hostModule ];
      }).extendModules {
        modules = [ installerModule ];
      };

    # isoImage for x86/Asahi CDs; sdImage for aarch64 SD-card installers.
    nixosInstallerImage = cfg:
      cfg.config.system.build.isoImage or cfg.config.system.build.sdImage
        or throw "configuration has no system.build.isoImage or system.build.sdImage";
  };
}
