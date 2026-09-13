{ ... }: {
  # Use the Mac mini as a remote builder over SSH. The mini's own
  # nix.linux-builder VM provides aarch64-linux and x86_64-linux (Rosetta/binfmt).
  #
  # Assumes passwordless SSH to Host `mac-mini` as connorfuhrman is already
  # configured (user SSH config / keys). The Nix daemon runs as root, so that
  # access must work for root as well (system ssh_config IdentityFile, or a
  # key root can read). Prefer 1Password SSH agent once rolled out — see
  # docs/plans/1password-ssh-workplan.md.
  flake.modules.generic.mac-mini-builder = { lib, pkgs, ... }: {
    nix.distributedBuilds = true;

    nix.buildMachines = [
      {
        hostName = "mac-mini";
        protocol = "ssh-ng";
        sshUser = "connorfuhrman";
        maxJobs = 4;
        speedFactor = 2;
        supportedFeatures = [ "benchmark" "big-parallel" "kvm" ];
        mandatoryFeatures = [ ];
        # aarch64-linux always (native in the mini's linux-builder VM).
        # x86_64-linux only when this host cannot build it locally (Darwin,
        # aarch64-linux NixOS). x86_64-linux NixOS hosts build x86 locally.
        systems = [ "aarch64-linux" ]
          ++ lib.optional (!pkgs.stdenv.hostPlatform.isx86_64) "x86_64-linux";
      }
    ];

    nix.settings.builders-use-substitutes = true;
  };
}
