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
      sys = pkgs.stdenv.hostPlatform.system;
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
        eval-opencode-skill-document-comments = evalOnly "opencode-skill-document-comments" self.packages.${sys}.opencode-skill-document-comments.drvPath;
        eval-opencode-skill-orchestration = evalOnly "opencode-skill-orchestration" self.packages.${sys}.opencode-skill-orchestration.drvPath;
        eval-opencode-skill-document-review = evalOnly "opencode-skill-document-review" self.packages.${sys}.opencode-skill-document-review.drvPath;
        eval-opencode-config = evalOnly "opencode-config" self.packages.${sys}.opencode-config.drvPath;
        eval-obsidian-plugins = evalOnly "obsidian-plugins" self.packages.${sys}.obsidian-plugins.drvPath;
        eval-cm = evalOnly "cm" self.packages.${sys}.cm.drvPath;
      };
    };
}
