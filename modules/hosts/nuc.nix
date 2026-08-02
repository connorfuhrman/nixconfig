{ config, inputs, ... }: {
  flake.modules.nixos.host-nuc = {
    imports = [
      config.flake.modules.nixos.system
      config.flake.modules.nixos.server
      config.flake.modules.nixos.onepassword
      config.flake.modules.nixos.obsidian
      config.flake.modules.generic.tailscale
      # Inert on x86_64-linux today (the mini only builds aarch64-linux);
      # kept so a future x86_64-capable builder on the mini is used automatically.
      config.flake.modules.generic.mac-mini-builder
      ./nuc/_hardware-configuration.nix
    ];

    networking.hostName = "nuc";
    system.stateVersion = "25.11";
  };

  flake.nixosConfigurations.nuc = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ config.flake.modules.nixos.host-nuc ];
  };

  flake.homeConfigurations."connorfuhrman@nuc" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    modules = [ config.flake.modules.homeManager.standard ];
  };
}
