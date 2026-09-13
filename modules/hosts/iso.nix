# Per-host installer media: <host>-iso extends that host's live module list
# via flake.lib.nixosInstallerFromHost (same host-* module as the live
# nixosConfiguration, plus an installer overlay). Live closures unchanged.
{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (config.flake.lib) nixosInstallerFromHost nixosInstallerImage;

  isoConfigs = {
    nuc-iso = nixosInstallerFromHost {
      system = "x86_64-linux";
      hostModule = config.flake.modules.nixos.host-nuc;
      installerModule = config.flake.modules.nixos.iso-x86;
    };
    nuc-cluster-head-iso = nixosInstallerFromHost {
      system = "x86_64-linux";
      hostModule = config.flake.modules.nixos.host-nuc-cluster-head;
      installerModule = config.flake.modules.nixos.iso-x86;
    };
    nuc-cluster-worker-iso = nixosInstallerFromHost {
      system = "x86_64-linux";
      hostModule = config.flake.modules.nixos.host-nuc-cluster-worker;
      installerModule = config.flake.modules.nixos.iso-x86;
    };
    rpi-cluster-head-iso = nixosInstallerFromHost {
      system = "aarch64-linux";
      hostModule = config.flake.modules.nixos.host-rpi-cluster-head;
      installerModule = config.flake.modules.nixos.iso-sd-aarch64;
    };
  };

  isoPackagesBySystem = {
    x86_64-linux = {
      nuc-iso = nixosInstallerImage isoConfigs.nuc-iso;
      nuc-cluster-head-iso = nixosInstallerImage isoConfigs.nuc-cluster-head-iso;
      nuc-cluster-worker-iso = nixosInstallerImage isoConfigs.nuc-cluster-worker-iso;
    };
    aarch64-linux = {
      rpi-cluster-head-iso = nixosInstallerImage isoConfigs.rpi-cluster-head-iso;
    };
  };
in
{
  flake.nixosConfigurations = isoConfigs;

  perSystem = { system, ... }: {
    packages = isoPackagesBySystem.${system} or { };
  };
}
