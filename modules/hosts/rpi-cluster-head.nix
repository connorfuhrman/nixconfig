{ config, inputs, ... }: {
  # EXPERIMENTAL — see flake.hostStatus.rpi-cluster-head.
  # PROTOTYPE: Raspberry Pi 4 as an alternate Ray head node.
  #
  # Purpose: prove the generalized cluster roles (modules/nixos/cluster.nix)
  # are platform-independent — this host imports the SAME nixos.ray-head role
  # module as nuc-cluster-head. To actually promote the Pi to head, set
  # flake.cluster.headName = "rpi-cluster-head" in cluster.nix and rebuild;
  # every ray-worker repoints automatically (Tailscale MagicDNS).
  #
  # The Pi has no Thunderbolt; the control plane and builder traffic both ride
  # Tailscale ("the LAN it has"). A future wired link to the worker can get a
  # static lease without touching the role module.
  #
  # Real deployments should evaluate github:NixOS/nixos-hardware
  # (raspberry-pi-4 module) as a flake input instead of the hand template in
  # ./rpi/_hardware-configuration.nix — not vendored yet to keep flake.nix
  # input-stable. The template is generalized: any RPi-based host closure
  # (head or worker) imports the same file.
  #
  # Installer media: nixosConfigurations.rpi-cluster-head-iso is an aarch64
  # SD image (sd-image-aarch64-installer), not a USB ISO.
  flake.modules.nixos.host-rpi-cluster-head = {
    imports = [
      config.flake.modules.nixos.system
      config.flake.modules.nixos.server
      config.flake.modules.nixos.onepassword
      # NOTE: no nixos.obsidian — GUI app, headless prototype, and obsidian's
      # linux package set is x86_64-centric; would risk aarch64 eval breakage.
      config.flake.modules.generic.tailscale
      config.flake.modules.generic.mac-mini-builder
      config.flake.modules.nixos.ray-head
      ./rpi/_hardware-configuration.nix
    ];

    networking.hostName = "rpi-cluster-head";

    # The Pi is weak for local builds: offload aarch64-linux to the mini's
    # linux-builder (already wired by generic.mac-mini-builder above) and
    # x86_64-linux to the NUC worker over Tailscale.
    nix.distributedBuilds = true;
    nix.buildMachines = [
      {
        hostName = "nuc-cluster-worker";
        protocol = "ssh-ng";
        sshUser = "connorfuhrman";
        maxJobs = 4;
        speedFactor = 2;
        systems = [ "x86_64-linux" ];
        supportedFeatures = [ "big-parallel" "kvm" "benchmark" ];
      }
    ];
    nix.settings.builders-use-substitutes = true;

    system.stateVersion = "25.11";
  };

  flake.nixosConfigurations.rpi-cluster-head = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [ config.flake.modules.nixos.host-rpi-cluster-head ];
  };

  flake.homeConfigurations."connorfuhrman@rpi-cluster-head" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = config.flake.lib.pkgsFor "aarch64-linux";
    modules = [ config.flake.modules.homeManager.standard ];
  };
}
