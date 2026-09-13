{ config, inputs, self, ... }: {
  # EXPERIMENTAL — see flake.hostStatus.mbp14 (Asahi install not yet validated).
  flake.modules.nixos.host-mbp14 = {
    imports = [
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
      config.flake.modules.nixos.system
      config.flake.modules.nixos.desktop
      config.flake.modules.nixos.asahi
      config.flake.modules.nixos.onepassword
      config.flake.modules.nixos.onepassword-gui
      config.flake.modules.nixos.obsidian
      config.flake.modules.generic.tailscale
      config.flake.modules.generic.mac-mini-builder
      ./mbp14/_hardware-configuration.nix
    ];

    networking.hostName = "mbp14";
    system.stateVersion = "25.11";
  };

  # apple-silicon-support (main) references pkgs.avd-fw, which exists in
  # nixos-apple-silicon's pinned nixpkgs but not our monorepo nixpkgs yet.
  flake.nixosConfigurations.mbp14 =
    inputs.nixos-apple-silicon.inputs.nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        { nixpkgs.overlays = [ self.overlays.default ]; }
        config.flake.modules.nixos.host-mbp14
      ];
    };

  flake.homeConfigurations."connorfuhrman@mbp14" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = config.flake.lib.pkgsFor "aarch64-linux";
    modules = [ config.flake.modules.homeManager.standard ];
  };
}

