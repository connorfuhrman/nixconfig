{ config, inputs, ... }: {
  # EXPERIMENTAL — see flake.hostStatus.nuc-cluster-head.
  # Cluster head role closure running on the nuc hardware. Boot this INSTEAD of
  # the plain `nuc` closure when the machine should act as the Ray head node —
  # the two closures are mutually exclusive (different networking.hostName /
  # Tailscale identity).
  flake.modules.nixos.host-nuc-cluster-head = {
    imports = [
      config.flake.modules.nixos.system
      config.flake.modules.nixos.server
      config.flake.modules.nixos.onepassword
      config.flake.modules.nixos.obsidian
      config.flake.modules.generic.tailscale
      config.flake.modules.generic.mac-mini-builder
      config.flake.modules.nixos.ray-head
      ./nuc/_hardware-configuration.nix
    ];

    networking.hostName = "nuc-cluster-head";

    # Point-to-point Thunderbolt LAN to the worker (bulk store/artifact
    # traffic). LAN-agnostic: any fast link works; Ray control plane rides
    # Tailscale. Iface name may be enp* on hardware — verify with `ip link`.
    networking.interfaces.thunderbolt0.ipv4.addresses = [
      {
        address = "10.200.0.1";
        prefixLength = 30;
      }
    ];
    networking.firewall.trustedInterfaces = [ "thunderbolt0" ];

    # Build on the worker: direct LAN preferred, Tailscale fallback.
    nix.distributedBuilds = true;
    nix.buildMachines = [
      {
        hostName = "10.200.0.2";
        protocol = "ssh-ng";
        sshUser = "connorfuhrman";
        maxJobs = 4;
        speedFactor = 2;
        systems = [ "x86_64-linux" ];
        supportedFeatures = [
          "big-parallel"
          "kvm"
          "benchmark"
        ];
      }
      {
        hostName = "nuc-cluster-worker";
        protocol = "ssh-ng";
        sshUser = "connorfuhrman";
        maxJobs = 4;
        speedFactor = 1;
        systems = [ "x86_64-linux" ];
        supportedFeatures = [
          "big-parallel"
          "kvm"
          "benchmark"
        ];
      }
    ];
    nix.settings.builders-use-substitutes = true;

    system.stateVersion = "25.11";
  };

  flake.nixosConfigurations.nuc-cluster-head = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ config.flake.modules.nixos.host-nuc-cluster-head ];
  };

  flake.homeConfigurations."connorfuhrman@nuc-cluster-head" =
    inputs.home-manager.lib.homeManagerConfiguration
      {
        pkgs = config.flake.lib.pkgsFor "x86_64-linux";
        modules = [ config.flake.modules.homeManager.standard ];
      };
}
