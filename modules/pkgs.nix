# Custom packages: overlay + flake packages export.
# Package bodies live under ../pkgs/*.nix (callPackage). This module is the
# only flake-parts wiring — not under pkgs/ so import-tree does not treat
# package files as modules.
{ self, inputs, ... }:
let
  overlay = import ../pkgs;

  # Shared helper: nixpkgs for a system with our overlay applied.
  pkgsFor =
    system:
    import inputs.nixpkgs {
      inherit system;
      overlays = [ overlay ];
    };

  packageNames = [
    "nono"
    "opencode-bin"
    "cm"
    "opencode"
    "opencode-config"
    "opencode-nix-profile"
    "opencode-orchestration-models"
    "opencode-orchestration-test"
    "opencode-skill-document-comments"
    "opencode-skill-document-review"
    "opencode-skill-orchestration"
    "opencode-skill-nono-sandbox"
    "obsidian-plugins"
    "obsidian-nix-sync-plugins"
    "agent-tools"
  ];
in
{
  flake = {
    overlays.default = overlay;
    # Convenience for host modules: config.flake.lib.pkgsFor "aarch64-darwin"
    lib.pkgsFor = pkgsFor;
  };

  perSystem =
    { system, ... }:
    let
      pkgs = pkgsFor system;
    in
    {
      packages = pkgs.lib.genAttrs packageNames (name: pkgs.${name});
    };
}
