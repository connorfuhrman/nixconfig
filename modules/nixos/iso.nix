# Installer media helpers. Live host closures stay untouched; installer
# modules are applied only via extendModules / nixosInstallerFromHost.
#
# Stock installer flavored with that host's modules (hostname, users, tools,
# this flake at /etc/nixconfig) — not a preinstalled disk image. After boot:
# partition (or flash the SD), nixos-generate-config, then
# `nixos-install --flake /etc/nixconfig#<host>`.
#
# Build:
#   nix build .#nuc-iso
#   nix build .#packages.x86_64-linux.nuc-iso
#   nix build .#nixosConfigurations.nuc-iso.config.system.build.isoImage
#   nix build .#packages.aarch64-linux.mbp14-iso             # Asahi ISO
#   nix build .#packages.aarch64-linux.rpi-cluster-head-iso  # SD image
#
# Media:
#   x86_64 hosts — installation-cd-minimal
#   mbp14        — nixos-apple-silicon iso-configuration (not generic CD)
#   rpi-cluster-head — sd-image-aarch64-installer (SD, not USB ISO)
{ self, inputs, config, ... }:
let
  nixosModules = "${inputs.nixpkgs}/nixos/modules";

  # Shared bits for every installer variant (ISO or SD). Do not set
  # isoImage.* here — SD images have no such option.
  installerMedia = { lib, pkgs, ... }: {
    systemd.services.ray-head.enable = lib.mkForce false;
    systemd.services.ray-worker.enable = lib.mkForce false;
    environment.etc.nixconfig.source = self.outPath;
    environment.systemPackages = with pkgs; [ git vim ];
  };

  isoX86 = { lib, config, ... }: {
    imports = [
      "${nixosModules}/installer/cd-dvd/installation-cd-minimal.nix"
      installerMedia
    ];

    # Host hardware templates enable systemd-boot for the *installed* disk.
    # The ISO builds its own El Torito + EFI image. installation-cd-base
    # already mkImageMediaOverrides fileSystems/swap/luks.
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    isoImage.appendToMenuLabel = " (${config.networking.hostName} installer)";
  };

  isoAsahi = { lib, ... }: {
    imports = [
      "${inputs.nixos-apple-silicon}/iso-configuration"
      installerMedia
    ];

    # Same family as INSTALL.md option B (installer-bootstrap), extended
    # from this host so the live USB carries /etc/nixconfig + host flavor.
    hardware.asahi.pkgsSystem = "aarch64-linux";
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  };

  isoSdAarch64 = { modulesPath, ... }: {
    imports = [
      (modulesPath + "/installer/sd-card/sd-image-aarch64-installer.nix")
      installerMedia
    ];
    # sd-image-aarch64 enables generic-extlinux; the rpi hardware template
    # already matches. Do not force extlinux off.
  };

  extendInstaller = nixosConfig: installerModule:
    nixosConfig.extendModules { modules = [ installerModule ]; };
in
{
  flake.modules.nixos.installer-media = installerMedia;
  flake.modules.nixos.iso-x86 = isoX86;
  flake.modules.nixos.iso-asahi = isoAsahi;
  flake.modules.nixos.iso-sd-aarch64 = isoSdAarch64;

  # Extend an evaluated nixosConfiguration (does not mutate it).
  flake.lib.extendInstaller = extendInstaller;
  flake.lib.extendNixosInstaller = extendInstaller;

  # x86 minimal ISO from a live config.
  flake.lib.mkInstallerIso = nixosConfig:
    extendInstaller nixosConfig config.flake.modules.nixos.iso-x86;

  # Rebuild from the host *module* then extend — same module list as the
  # live nixosConfigurations.<name> (those are a single host-* module),
  # without reading flake.nixosConfigurations (avoids a fixpoint cycle).
  flake.lib.nixosInstallerFromHost = { system, hostModule, installerModule }:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ hostModule ];
    }).extendModules {
      modules = [ installerModule ];
    };

  flake.lib.nixosInstallerImage = cfg:
    cfg.config.system.build.isoImage or cfg.config.system.build.sdImage
      or throw "configuration has no system.build.isoImage or system.build.sdImage";
}
