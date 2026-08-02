{ self, ... }: {
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
      evalOnly = name: drvPath:
        pkgs.writeText "eval-${name}" (builtins.unsafeDiscardStringContext drvPath + "\n");
    in
    {
      checks = {
        eval-nixos-mbp14 = evalOnly "nixos-mbp14" self.nixosConfigurations.mbp14.config.system.build.toplevel.drvPath;
        eval-nixos-nuc = evalOnly "nixos-nuc" self.nixosConfigurations.nuc.config.system.build.toplevel.drvPath;
        eval-darwin-macbook = evalOnly "darwin-macbook" self.darwinConfigurations.macbook.config.system.build.toplevel.drvPath;
        eval-darwin-mac-mini = evalOnly "darwin-mac-mini" self.darwinConfigurations.mac-mini.config.system.build.toplevel.drvPath;
        eval-home-connorfuhrman-mbp14 = evalOnly "home-connorfuhrman-mbp14" self.homeConfigurations."connorfuhrman@mbp14".activationPackage.drvPath;
        eval-home-connorfuhrman-nuc = evalOnly "home-connorfuhrman-nuc" self.homeConfigurations."connorfuhrman@nuc".activationPackage.drvPath;
        eval-home-connorfuhrman-macbook = evalOnly "home-connorfuhrman-macbook" self.homeConfigurations."connorfuhrman@macbook".activationPackage.drvPath;
        eval-home-connorfuhrman-mac-mini = evalOnly "home-connorfuhrman-mac-mini" self.homeConfigurations."connorfuhrman@mac-mini".activationPackage.drvPath;
      };
    };
}
