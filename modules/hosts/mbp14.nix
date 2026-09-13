{ config, inputs, ... }: {
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

    # apple-silicon-support (main) expects pkgs.avd-fw from the upstream overlay.
    nixpkgs.overlays = [ inputs.nixos-apple-silicon.overlays.default ];

    networking.hostName = "mbp14";
    system.stateVersion = "25.11";
  };

  flake.nixosConfigurations.mbp14 = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [ config.flake.modules.nixos.host-mbp14 ];
  };

  flake.homeConfigurations."connorfuhrman@mbp14" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = config.flake.lib.pkgsFor "aarch64-linux";
    modules = [ config.flake.modules.homeManager.standard ];
  };
}

