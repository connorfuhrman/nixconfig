# TEMPLATE — overwritten by nixos-generate-config during installation.
# Do NOT hand-edit UUIDs; follow the runbook in PLAN.md Phase C.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partuuid/REPLACE-WITH-ESP-PARTUUID";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" "nofail" ];
  };

  nixpkgs.hostPlatform = "aarch64-linux";
}