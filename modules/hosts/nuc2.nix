{ config, inputs, ... }: {
  flake.modules.nixos.host-nuc2 = {
    imports = [
      config.flake.modules.nixos.system
      config.flake.modules.nixos.server
      config.flake.modules.nixos.onepassword
      config.flake.modules.nixos.obsidian
      config.flake.modules.generic.tailscale
      config.flake.modules.generic.mac-mini-builder
      ./nuc2/_hardware-configuration.nix
    ];

    networking.hostName = "nuc2";
    system.stateVersion = "25.11";
  };

  flake.nixosConfigurations.nuc2 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ config.flake.modules.nixos.host-nuc2 ];
  };

  flake.homeConfigurations."connorfuhrman@nuc2" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = config.flake.lib.pkgsFor "x86_64-linux";
    modules = [ config.flake.modules.homeManager.standard ];
  };
}
