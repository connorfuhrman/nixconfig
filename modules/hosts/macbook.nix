{ config, inputs, ... }: {
  flake.modules.darwin.host-macbook = {
    imports = [
      config.flake.modules.darwin.system
      config.flake.modules.darwin.onepassword
      config.flake.modules.darwin.emacs-plus
      config.flake.modules.generic.tailscale
      config.flake.modules.generic.mac-mini-builder
    ];

    networking.hostName = "macbook";

    # nix-darwin state version is an integer (unlike NixOS's string).
    system.stateVersion = 5;
  };

  flake.darwinConfigurations.macbook = inputs.nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    modules = [ config.flake.modules.darwin.host-macbook ];
  };

  flake.homeConfigurations."connor@macbook" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
    modules = [
      config.flake.modules.homeManager.base
      config.flake.modules.homeManager.emacs-plus
      config.flake.modules.homeManager.nono-opencode
    ];
  };
}
