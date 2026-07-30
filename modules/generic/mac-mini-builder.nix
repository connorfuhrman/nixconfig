{ ... }: {
  # Use the Mac mini as a remote builder over SSH. The mini's own
  # nix.linux-builder VM provides the aarch64-linux build capability; when a
  # client dispatches an aarch64-linux build to the mini, the mini's Nix
  # daemon forwards it to that VM automatically.
  #
  # The mini is reached by its Tailscale MagicDNS name (`mac-mini`) — see
  # modules/generic/tailscale.nix. If a client is not on the tailnet yet,
  # temporarily substitute the mini's LAN address (mac-mini.local) below.
  #
  # One-time setup per client machine:
  #   sudo ssh-keygen -t ed25519 -f /etc/nix/mac-mini-builder-key -N ''
  #   ssh-copy-id -i /etc/nix/mac-mini-builder-key.pub connor@mac-mini
  #   sudo ssh -i /etc/nix/mac-mini-builder-key connor@mac-mini true   # seed root's known_hosts
  flake.modules.generic.mac-mini-builder = { ... }: {
    nix.buildMachines = [
      {
        hostName = "mac-mini";
        system = "aarch64-linux";
        protocol = "ssh";
        sshUser = "connorfuhrman";
        sshKey = "/etc/nix/mac-mini-builder-key";
        maxJobs = 4;
        speedFactor = 2;
        supportedFeatures = [ "benchmark" "big-parallel" ];
        mandatoryFeatures = [ ];
      }
    ];

    # Let the builder fetch substitutes directly instead of copying via the client.
    nix.settings.builders-use-substitutes = true;
  };
}
