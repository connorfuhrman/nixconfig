# Custom packages: overlay + flake packages export.
# Package bodies live under ../pkgs/*.nix (callPackage). This module is the
# only flake-parts wiring — not under pkgs/ so import-tree does not treat
# package files as modules.
{ self, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  overlay = import ../pkgs;

  # Shared helper: nixpkgs for a system with both the pi-config overlay and
  # our local overlay applied. pi-config provides pi-side-agents and the pi
  # wrapper; our overlay provides origin, obsidian-plugins, etc.
  pkgsFor =
    system:
    import inputs.nixpkgs {
      inherit system;
      overlays = [
        inputs.pi-config.overlays.default
        overlay
      ];
      config.allowUnfreePredicate =
        pkg:
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
    "origin"
    "pi"
    "pi-plan-mode"
    "pi-subagents"
    "pi-goal"
    "nono"
    "pi-nono"
    "pi-tasks"
    "pi-usage"
    "pi-diff-review"
    "pi-side-agents"
    "pi-worktree"
    "pi-lsp"
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
      formatter = pkgs.nixfmt;
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
    };
}
