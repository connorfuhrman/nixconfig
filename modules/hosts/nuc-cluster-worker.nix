{ config, inputs, ... }: {
  # Cluster worker role closure running on the nuc2 hardware. Boot this INSTEAD
  # of the plain `nuc2` closure when the machine should act as a Ray worker —
  # mutually exclusive with `nuc2` (different networking.hostName / Tailscale
  # identity). The head it joins is flake.cluster.headName (single switch
  # point, see modules/nixos/cluster.nix).
  flake.modules.nixos.host-nuc-cluster-worker = {
    imports = [
      config.flake.modules.nixos.system
      config.flake.modules.nixos.server
      config.flake.modules.nixos.onepassword
      config.flake.modules.nixos.obsidian
      config.flake.modules.generic.tailscale
      config.flake.modules.generic.mac-mini-builder
      config.flake.modules.nixos.ray-worker
      ./nuc2/_hardware-configuration.nix
    ];

    networking.hostName = "nuc-cluster-worker";

    # Point-to-point Thunderbolt LAN to the head. Iface name may be enp* on
    # hardware — verify with `ip link`.
    networking.interfaces.thunderbolt0.ipv4.addresses = [
      { address = "10.200.0.2"; prefixLength = 30; }
    ];
    networking.firewall.trustedInterfaces = [ "thunderbolt0" ];

    # Build on the head: direct LAN preferred, Tailscale fallback.
    nix.distributedBuilds = true;
    nix.buildMachines = [
      {
        hostName = "10.200.0.1";
        protocol = "ssh-ng";
        sshUser = "connorfuhrman";
        maxJobs = 4;
        speedFactor = 2;
        systems = [ "x86_64-linux" ];
        supportedFeatures = [ "big-parallel" "kvm" "benchmark" ];
      }
      {
        hostName = "nuc-cluster-head";
        protocol = "ssh-ng";
        sshUser = "connorfuhrman";
        maxJobs = 4;
        speedFactor = 1;
        systems = [ "x86_64-linux" ];
        supportedFeatures = [ "big-parallel" "kvm" "benchmark" ];
      }
    ];
    nix.settings.builders-use-substitutes = true;

    system.stateVersion = "25.11";
  };

  flake.nixosConfigurations.nuc-cluster-worker = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ config.flake.modules.nixos.host-nuc-cluster-worker ];
  };

  flake.homeConfigurations."connorfuhrman@nuc-cluster-worker" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = config.flake.lib.pkgsFor "x86_64-linux";
    modules = [ config.flake.modules.homeManager.standard ];
  };
}
