{ config, inputs, ... }: {
  # EXPERIMENTAL — see flake.hostStatus.nuc (not yet validated on hardware).
  flake.modules.nixos.host-nuc = {
    imports = [
      config.flake.modules.nixos.system
      config.flake.modules.nixos.server
      config.flake.modules.nixos.onepassword
      config.flake.modules.nixos.obsidian
      config.flake.modules.nixos.buildkite
      config.flake.modules.generic.tailscale
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
    pkgs = config.flake.lib.pkgsFor "x86_64-linux";
    modules = [ config.flake.modules.homeManager.standard ];
  };
}
