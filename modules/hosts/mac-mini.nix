{ config, inputs, ... }: {
  flake.modules.darwin.host-mac-mini = {
    imports = [
      config.flake.modules.darwin.system
      config.flake.modules.darwin.linux-builder
      config.flake.modules.darwin.server
      config.flake.modules.darwin.roon-server
      config.flake.modules.darwin.onepassword
      config.flake.modules.darwin.emacs-plus
      config.flake.modules.generic.tailscale
    ];

    networking.hostName = "mac-mini";

    # nix-darwin state version is an integer (unlike NixOS's string).
    system.stateVersion = 5;
  };

  flake.darwinConfigurations.mac-mini = inputs.nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    modules = [ config.flake.modules.darwin.host-mac-mini ];
  };

  flake.homeConfigurations."connorfuhrman@mac-mini" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
    modules = [
      config.flake.modules.homeManager.base
      config.flake.modules.homeManager.emacs
      config.flake.modules.homeManager.coreutils
      config.flake.modules.homeManager.nono-opencode
    ];
  };
}
