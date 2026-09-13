# Custom packages: overlay + flake packages export.
# Package bodies live under ../pkgs/*.nix (callPackage). This module is the
# only flake-parts wiring — not under pkgs/ so import-tree does not treat
# package files as modules.
{ self, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  overlay = import ../pkgs;

  # Shared helper: nixpkgs for a system with our overlay applied.
  # Origin CLI is unfree (Cursor proprietary binary); scoped here so
  # standalone home configs and `nix build .#origin` evaluate without
  # --impure / NIXPKGS_ALLOW_UNFREE.
  pkgsFor =
    system:
    import inputs.nixpkgs {
      inherit system;
      overlays = [ overlay ];
      config.allowUnfreePredicate = pkg:
        builtins.elem (lib.getName pkg) [
          "origin"
          "_1password-cli"
          "1password-cli"
        ];
    };

  packageNames = [
    "obsidian-plugins"
    "obsidian-nix-sync-plugins"
    "cursor-cloud-setup"
    "mac-mini-buildkite-install-token"
    "mac-mini-buildkite-install-origin-ssh"
    "mac-mini-install-nix-store-signing"
    "origin"
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
      apps.cursor-cloud-setup = {
        type = "app";
        program = "${pkgs.cursor-cloud-setup}/bin/cursor-cloud-setup";
      };
      apps.mac-mini-buildkite-install-token = {
        type = "app";
        program = "${pkgs.mac-mini-buildkite-install-token}/bin/mac-mini-buildkite-install-token";
      };
      apps.mac-mini-buildkite-install-origin-ssh = {
        type = "app";
        program = "${pkgs.mac-mini-buildkite-install-origin-ssh}/bin/mac-mini-buildkite-install-origin-ssh";
      };
      apps.mac-mini-install-nix-store-signing = {
        type = "app";
        program = "${pkgs.mac-mini-install-nix-store-signing}/bin/mac-mini-install-nix-store-signing";
      };
    };
}
