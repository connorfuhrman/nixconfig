# Generic installer boot media: iso (x86_64), asahi-iso (aarch64), rpi-iso
# (aarch64 SD). Not per-host variants — install with
# `nixos-install --flake /etc/nixconfig#<host>` after partitioning.
{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (config.flake.lib) mkGenericInstaller nixosInstallerImage;

  isoConfig = mkGenericInstaller {
    system = "x86_64-linux";
    installerModule = config.flake.modules.nixos.iso-x86;
  };

  rpiIsoConfig = mkGenericInstaller {
    system = "aarch64-linux";
    installerModule = config.flake.modules.nixos.iso-sd-aarch64;
  };

  installerPackages = {
    x86_64-linux = {
      iso = nixosInstallerImage isoConfig;
    };
    aarch64-linux = {
      asahi-iso = inputs.nixos-apple-silicon.packages.aarch64-linux.installer-bootstrap;
      rpi-iso = nixosInstallerImage rpiIsoConfig;
    };
  };
in
{
  flake.nixosConfigurations = {
    iso = isoConfig;
    rpi-iso = rpiIsoConfig;
  };

  perSystem = { system, ... }: {
    packages = installerPackages.${system} or { };
  };
}
