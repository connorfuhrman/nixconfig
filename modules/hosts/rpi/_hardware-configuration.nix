# GENERALIZED TEMPLATE — Raspberry Pi (4/5-class) hardware for ANY RPi-based
# host closure (rpi-cluster-head today; future rpi workers import the same
# file). extlinux/u-boot boot, single SD partition labeled NIXOS_SD (standard
# aarch64 SD image layout). Prefer the nixos-hardware raspberry-pi module when
# it becomes a flake input.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = "aarch64-linux";
}
