{ config, inputs, ... }: {
  flake.modules.nixos.host-nuc2 = {
    imports = [
      config.flake.modules.nixos.system
      config.flake.modules.nixos.server
      config.flake.modules.nixos.onepassword
      config.flake.modules.nixos.obsidian
      config.flake.modules.generic.tailscale
      # Inert on x86_64-linux today (the mini only builds aarch64-linux);
      # kept so a future x86_64-capable builder on the mini is used automatically.
      config.flake.modules.generic.mac-mini-builder
      config.flake.modules.nixos.nuc-cluster
      config.flake.modules.nixos.ray-cluster
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
