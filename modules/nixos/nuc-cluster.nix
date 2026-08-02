{ ... }: {
  # Dual-NUC private LAN (Thunderbolt-as-Ethernet) + mutual Nix distributed
  # builds — RFC 0001 (docs/rfcs/0001-dual-nuc-cluster.md).
  #
  # Each NUC gets a static /30 address on the point-to-point Thunderbolt link
  # and uses the other NUC as a remote builder, preferring the direct LAN and
  # falling back to Tailscale (MagicDNS short name) when the link is down.
  #
  # Assumes passwordless SSH to the peer as connorfuhrman is already
  # configured, including for root / the Nix daemon (the daemon initiates the
  # SSH connection as root). Prefer 1Password SSH agent once rolled out — see
  # docs/plans/1password-ssh-workplan.md.
  flake.modules.nixos.nuc-cluster = { config, lib, ... }:
    let
      hostName = config.networking.hostName;
      isNuc = hostName == "nuc";
      ownIp = if isNuc then "10.200.0.1" else "10.200.0.2";
      peerIp = if isNuc then "10.200.0.2" else "10.200.0.1";
      peerTailscaleName = if isNuc then "nuc2" else "nuc";
    in
    {
      # Lazy guard: assertions are checked after the module fixpoint, so
      # reading hostName here does NOT recurse (unlike a top-level assert).
      assertions = [
        {
          assertion = hostName == "nuc" || hostName == "nuc2";
          message = "nuc-cluster: only valid on hosts \"nuc\" or \"nuc2\", but networking.hostName is \"${hostName}\"";
        }
      ];

      # Point-to-point /30 over the Thunderbolt link. The interface name may
      # be enp* on real hardware — verify with `ip link` after first boot.
      networking.interfaces.thunderbolt0.ipv4.addresses = [
        { address = ownIp; prefixLength = 30; }
      ];

      nix.distributedBuilds = true;

      nix.buildMachines = [
        {
          # Preferred: direct Thunderbolt LAN.
          hostName = peerIp;
          protocol = "ssh-ng";
          sshUser = "connorfuhrman";
          maxJobs = 4;
          speedFactor = 2;
          supportedFeatures = [ "big-parallel" "kvm" "benchmark" ];
          systems = [ "x86_64-linux" ];
        }
        {
          # Fallback: Tailscale when the LAN link is down.
          hostName = peerTailscaleName;
          protocol = "ssh-ng";
          sshUser = "connorfuhrman";
          maxJobs = 4;
          speedFactor = 1;
          supportedFeatures = [ "big-parallel" "kvm" "benchmark" ];
          systems = [ "x86_64-linux" ];
        }
      ];

      nix.settings.builders-use-substitutes = true;
    };
}
