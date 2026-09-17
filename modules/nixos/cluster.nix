{ config, ... }: {
  # Ray compute cluster — generalized roles (RFC 0001).
  #
  # Topology is data, not code: `flake.cluster.headName` is the SINGLE switch
  # point for the head role. To promote another machine (e.g. rpi-cluster-head)
  # to head, change headName here — every ray-worker repoints on next rebuild.
  # Workers address the head by its Tailscale MagicDNS name, so the control
  # plane is LAN-agnostic (any fast link may still be used for bulk data).
  flake.cluster = {
    headName = "nuc-cluster-head";
    rayPort = 6379;
  };

  # Generalized Ray head role. Any always-on host can import this; pairwise
  # LAN addressing and nix.buildMachines stay in the host module (they are
  # hardware facts, not role logic).
  flake.modules.nixos.ray-head =
    { pkgs, ... }:
    let
      # nixpkgs#ray has no meta.mainProgram; CLI comes from the python env.
      ray = pkgs.python3.withPackages (ps: [ ps.ray ]);
    in
    {
      # Podman for task isolation; dockerCompat gives /var/run/docker.sock so
      # Ray task runtimes can treat it as docker.
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
      };

      # Ray worker/object-store ports are ephemeral — trust the mesh rather
      # than whack-a-mole with ports. Host modules may append pairwise
      # interfaces (e.g. thunderbolt0) to trustedInterfaces.
      networking.firewall.trustedInterfaces = [ "tailscale0" ];

      systemd.services.ray-head = {
        description = "Ray cluster head node";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          # Dashboard binds 0.0.0.0: reachable on tailscale/LAN (trusted nets).
          ExecStart = "${ray}/bin/ray start --head --port=${toString config.flake.cluster.rayPort} --dashboard-host=0.0.0.0 --block";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };
    };

  # Generalized Ray worker role. Any host can import this; it joins the head
  # named by flake.cluster.headName (Tailscale MagicDNS).
  flake.modules.nixos.ray-worker =
    { pkgs, ... }:
    let
      ray = pkgs.python3.withPackages (ps: [ ps.ray ]);
    in
    {
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
      };

      networking.firewall.trustedInterfaces = [ "tailscale0" ];

      systemd.services.ray-worker = {
        description = "Ray cluster worker node";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${ray}/bin/ray start --address=${config.flake.cluster.headName}:${toString config.flake.cluster.rayPort} --block";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };
    };
}
