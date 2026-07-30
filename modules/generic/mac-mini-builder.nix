{ ... }: {
  # Use the Mac mini as a remote builder over SSH. The mini's own
  # nix.linux-builder VM provides the aarch64-linux build capability; when a
  # client dispatches an aarch64-linux build to the mini, the mini's Nix
  # daemon forwards it to that VM automatically.
  #
  # Assumes passwordless SSH to Host `mac-mini` as connorfuhrman is already
  # configured (user SSH config / keys). The Nix daemon runs as root, so that
  # access must work for root as well (system ssh_config IdentityFile, or a
  # key root can read).
  flake.modules.generic.mac-mini-builder = { ... }: {
    nix.buildMachines = [
      {
        hostName = "mac-mini";
        system = "aarch64-linux";
        protocol = "ssh-ng";
        sshUser = "connorfuhrman";
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
