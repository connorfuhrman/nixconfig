{
  description = "Multi-host Nix monorepo: NixOS, nix-darwin, and home-manager (dendritic flake-parts)";

  nixConfig = {
    extra-substituters = [ "https://nixos-apple-silicon.cachix.org" ];
    extra-trusted-public-keys = [
      "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon/release-2025-11-18";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Dedicated pi coding agent configuration (home-manager module + overlay).
    # Private repo: use git+ssh so authentication flows through the user's
    # SSH agent (1Password SSH agent on macOS; deploy key on CI builders).
    pi-config = {
      url = "git+ssh://git@github.com/connorfuhrman/pi-config.git";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.import-tree.follows = "import-tree";
    };
    # Self-contained flake providing wrapped Emacs packages (pinned own
    # nixpkgs + emacs-overlay); deliberately does NOT follow our nixpkgs.
    emacs.url = "github:connorfuhrman/emacs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.nix-darwin.flakeModules.default
        inputs.flake-parts.flakeModules.modules
        inputs.home-manager.flakeModules.home-manager
        (inputs.import-tree ./modules)
      ];
    };
}
