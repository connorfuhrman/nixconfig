{ ... }: {
  # Two-node Ray cluster (RFC 0001, docs/rfcs/0001-dual-nuc-cluster.md):
  #   nuc  — Ray head (GCS + dashboard)
  #   nuc2 — Ray worker
  # Both nodes run Podman for task isolation.
  #
  # nixpkgs#ray has no meta.mainProgram (verified by probe), so the CLI comes
  # from the python3 environment: ${ray}/bin/ray.
  flake.modules.nixos.ray-cluster = { config, lib, pkgs, ... }:
    let
      hostName = config.networking.hostName;
      isHead = hostName == "nuc";
      isWorker = hostName == "nuc2";
      ray = pkgs.python3.withPackages (ps: [ ps.ray ]);
    in
    {
      # Lazy guard: assertions are checked after the module fixpoint, so
      # reading hostName here does NOT recurse (unlike a top-level assert).
      assertions = [
        {
          assertion = isHead || isWorker;
          message = "modules/nixos/ray-cluster.nix: only supported on nuc (head) or nuc2 (worker), not ${hostName}";
        }
      ];

      # Podman container runtime for Ray task isolation (both nodes).
      # dockerCompat gives /var/run/docker.sock so Ray task runtimes can
      # treat it as docker.
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
      };

      # Ray GCS (6379), dashboard (8265), client server (10001).
      # Ray worker object-store ports are ephemeral; LAN/Tailscale ACLs are
      # the real boundary (Tailscale handles trust).
      networking.firewall.allowedTCPPorts = [ 6379 8265 10001 ];

      systemd.services.ray-head = lib.mkIf isHead {
        description = "Ray cluster head node";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          # Dashboard binds 0.0.0.0: reachable on LAN/Tailscale (trusted
          # nets only).
          ExecStart = "${ray}/bin/ray start --head --port=6379 --dashboard-host=0.0.0.0 --block";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      systemd.services.ray-worker = lib.mkIf isWorker {
        description = "Ray cluster worker node";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${ray}/bin/ray start --address=10.200.0.1:6379 --block";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };
    };
}
