{ ... }: {
  # Obsidian knowledge base (unfree). Predicate lives in nixos.onepassword —
  # only one allowUnfreePredicate per configuration.
  flake.modules.nixos.obsidian = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.obsidian ];
  };
}
