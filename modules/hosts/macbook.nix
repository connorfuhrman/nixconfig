{ config, inputs, ... }: {
  flake.modules.darwin.host-macbook = {
    imports = [
      config.flake.modules.darwin.system
      config.flake.modules.darwin.onepassword
      config.flake.modules.darwin.obsidian
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

  flake.homeConfigurations."connorfuhrman@macbook" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = config.flake.lib.pkgsFor "aarch64-darwin";
    modules = [ config.flake.modules.homeManager.standard ];
  };
}

