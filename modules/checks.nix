{ self, inputs, ... }: {
  # Eval-only checks: every configuration's derivations must instantiate
  # (evaluate) cleanly. Each check is a trivial text file embedding one
  # configuration's .drv path — computing the .drv path forces full
  # evaluation of that configuration's entire closure, but builds nothing.
  # unsafeDiscardStringContext is load-bearing: a .drvPath string carries
  # derivation context that would otherwise make the check DEPEND on (build)
  # the entire referenced closure.
  #
  # Check names must not contain `@` (invalid in store paths).
  perSystem = { pkgs, ... }:
    let
      inherit (inputs.nixpkgs) lib;
      evalOnly = name: drvPath:
        pkgs.writeText "eval-${name}" (builtins.unsafeDiscardStringContext drvPath + "\n");
      sys = pkgs.stdenv.hostPlatform.system;
      installerChecks =
        lib.optionalAttrs (sys == "x86_64-linux") {
          eval-iso = evalOnly "iso" self.nixosConfigurations.iso.config.system.build.isoImage.drvPath;
        }
        // lib.optionalAttrs (sys == "aarch64-linux") {
          eval-asahi-iso = evalOnly "asahi-iso" self.packages.aarch64-linux.asahi-iso.drvPath;
          eval-rpi-iso = evalOnly "rpi-iso" self.nixosConfigurations.rpi-iso.config.system.build.sdImage.drvPath;
        };
    in
    {
      checks = installerChecks // {
        eval-nixos-mbp14 = evalOnly "nixos-mbp14" self.nixosConfigurations.mbp14.config.system.build.toplevel.drvPath;
        eval-nixos-nuc = evalOnly "nixos-nuc" self.nixosConfigurations.nuc.config.system.build.toplevel.drvPath;
        eval-nixos-nuc-cluster-head = evalOnly "nixos-nuc-cluster-head" self.nixosConfigurations.nuc-cluster-head.config.system.build.toplevel.drvPath;
        eval-nixos-nuc-cluster-worker = evalOnly "nixos-nuc-cluster-worker" self.nixosConfigurations.nuc-cluster-worker.config.system.build.toplevel.drvPath;
        eval-nixos-rpi-cluster-head = evalOnly "nixos-rpi-cluster-head" self.nixosConfigurations.rpi-cluster-head.config.system.build.toplevel.drvPath;
        eval-darwin-macbook = evalOnly "darwin-macbook" self.darwinConfigurations.macbook.config.system.build.toplevel.drvPath;
        eval-darwin-mac-mini = evalOnly "darwin-mac-mini" self.darwinConfigurations.mac-mini.config.system.build.toplevel.drvPath;
        eval-home-connorfuhrman-mbp14 = evalOnly "home-connorfuhrman-mbp14" self.homeConfigurations."connorfuhrman@mbp14".activationPackage.drvPath;
        eval-home-connorfuhrman-nuc = evalOnly "home-connorfuhrman-nuc" self.homeConfigurations."connorfuhrman@nuc".activationPackage.drvPath;
        eval-home-connorfuhrman-nuc-cluster-head = evalOnly "home-connorfuhrman-nuc-cluster-head" self.homeConfigurations."connorfuhrman@nuc-cluster-head".activationPackage.drvPath;
        eval-home-connorfuhrman-nuc-cluster-worker = evalOnly "home-connorfuhrman-nuc-cluster-worker" self.homeConfigurations."connorfuhrman@nuc-cluster-worker".activationPackage.drvPath;
        eval-home-connorfuhrman-rpi-cluster-head = evalOnly "home-connorfuhrman-rpi-cluster-head" self.homeConfigurations."connorfuhrman@rpi-cluster-head".activationPackage.drvPath;
        eval-home-connorfuhrman-macbook = evalOnly "home-connorfuhrman-macbook" self.homeConfigurations."connorfuhrman@macbook".activationPackage.drvPath;
        eval-home-connorfuhrman-mac-mini = evalOnly "home-connorfuhrman-mac-mini" self.homeConfigurations."connorfuhrman@mac-mini".activationPackage.drvPath;
        eval-home-ubuntu-cursor-cloud = evalOnly "home-ubuntu-cursor-cloud" self.homeConfigurations."ubuntu@cursor-cloud".activationPackage.drvPath;
        eval-obsidian-plugins = evalOnly "obsidian-plugins" self.packages.${sys}.obsidian-plugins.drvPath;
        eval-cursor-cloud-setup = evalOnly "cursor-cloud-setup" self.packages.${sys}.cursor-cloud-setup.drvPath;
        eval-origin = evalOnly "origin" self.packages.${sys}.origin.drvPath;
      };
    };
}
