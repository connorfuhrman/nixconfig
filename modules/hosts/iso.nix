# Per-host installer media: <host>-iso extends the live host closure.
{ self, inputs, config, ... }:
let
  lib = inputs.nixpkgs.lib;
  inherit (config.flake.lib) nixosInstallerFromHost nixosInstallerImage;

  x86Hosts = {
    nuc = config.flake.modules.nixos.host-nuc;
    nuc-cluster-head = config.flake.modules.nixos.host-nuc-cluster-head;
    nuc-cluster-worker = config.flake.modules.nixos.host-nuc-cluster-worker;
  };

  isoConfigs =
    lib.mapAttrs (hostName: hostModule:
      nixosInstallerFromHost {
        system = "x86_64-linux";
        inherit hostModule;
        installerModule = config.flake.modules.nixos.iso-x86;
      }
    ) x86Hosts
    |> lib.mapAttrs' (hostName: cfg:
      lib.nameValuePair "${hostName}-iso" cfg
    )
    // {
      mbp14-iso = nixosInstallerFromHost {
        system = "aarch64-linux";
        hostModule = config.flake.modules.nixos.host-mbp14;
        installerModule = config.flake.modules.nixos.iso-asahi;
      };
      rpi-cluster-head-iso = nixosInstallerFromHost {
        system = "aarch64-linux";
        hostModule = config.flake.modules.nixos.host-rpi-cluster-head;
        installerModule = config.flake.modules.nixos.iso-sd-aarch64;
      };
    };

  isoPackagesBySystem = {
    x86_64-linux = lib.mapAttrs (_: nixosInstallerImage) (
      lib.filterAttrs (n: _: lib.hasSuffix "-iso" n) isoConfigs
    );
    aarch64-linux = {
      mbp14-iso = nixosInstallerImage isoConfigs.mbp14-iso;
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
