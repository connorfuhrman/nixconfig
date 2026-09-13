# Generic installer media helpers. Three boot-media types — no per-host
# ISO variants. Live host closures stay untouched.
#
# Build:
#   nix build .#iso
#   nix build .#packages.x86_64-linux.iso
#   nix build .#asahi-iso
#   nix build .#packages.aarch64-linux.asahi-iso
#   nix build .#rpi-iso
#   nix build .#packages.aarch64-linux.rpi-iso
#
# Media:
#   iso      — x86_64 installation-cd-minimal (generic USB installer)
#   asahi-iso — aarch64 installer-bootstrap (Apple Silicon / mbp14 path)
#   rpi-iso  — aarch64 sd-image-aarch64-installer (SD card, not USB ISO)
{ self, inputs, config, ... }:
let
  nixosModules = "${inputs.nixpkgs}/nixos/modules";

  # Shared bits for every generic installer (ISO or SD).
  installerMedia = { pkgs, ... }: {
    environment.etc.nixconfig.source = self.outPath;
    environment.systemPackages = with pkgs; [ git vim ];
  };

  isoX86 = { lib, ... }: {
    imports = [
      "${nixosModules}/installer/cd-dvd/installation-cd-minimal.nix"
      installerMedia
    ];

    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    isoImage.appendToMenuLabel = " (NixOS installer)";
  };

  isoSdAarch64 = { modulesPath, ... }: {
    imports = [
      (modulesPath + "/installer/sd-card/sd-image-aarch64-installer.nix")
      installerMedia
    ];
  };
in
{
  flake.modules.nixos.installer-media = installerMedia;
  flake.modules.nixos.iso-x86 = isoX86;
  flake.modules.nixos.iso-sd-aarch64 = isoSdAarch64;

  flake.lib.mkGenericInstaller = { system, installerModule }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ installerModule ];
    };

  flake.lib.nixosInstallerImage = cfg:
    if cfg.config.system.build ? isoImage then cfg.config.system.build.isoImage
    else if cfg.config.system.build ? sdImage then cfg.config.system.build.sdImage
    else throw "configuration has no system.build.isoImage or system.build.sdImage";
}
