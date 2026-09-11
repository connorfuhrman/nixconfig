{ ... }: {
  # Obsidian knowledge base (unfree). Predicate lives in darwin.onepassword —
  # only one allowUnfreePredicate per configuration.
  flake.modules.darwin.obsidian = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.obsidian ];
  };
}
