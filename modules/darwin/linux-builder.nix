{ ... }: {
  # aarch64-linux NixOS VM builder + x86_64-linux via qemu-user binfmt.
  # Rosetta (faster x86_64) can be enabled when the Virtualization.framework
  # share is confirmed — see comment in config below. Podman+Rosetta is an
  # alternate bootstrap if the stock linux-builder is unavailable.
  flake.modules.darwin.linux-builder = { lib, ... }: {
    nix.linux-builder = {
      enable = true;
      ephemeral = false;
      # 4 jobs: the 16 GiB host also runs a 10 GiB Podman VM for CI docker
      # jobs, so keep concurrent remote builds modest.
      maxJobs = 4;
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      config = { pkgs, lib, ... }: {
        virtualisation.cores = 4;
        virtualisation.darwin-builder.memorySize = 10 * 1024;
        virtualisation.darwin-builder.diskSize = 124 * 1024;

        # Emulate x86_64-linux inside the aarch64 builder VM (works without
        # host Rosetta share). Slower than Rosetta; reliable bootstrap.
        boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
        nix.settings.extra-platforms = [ "x86_64-linux" ];

        # All host→VM connections share one slirp source IP, so OpenSSH >= 10
        # per-source penalties lock out ALL builder connections for minutes
        # after routine teardown SIGKILLs.
        services.openssh.settings.PerSourcePenalties = false;

        # Faster path once the host VF exposes the "rosetta" virtiofs tag
        # (macOS Virtualization + linux-builder support). Enable deliberately:
        #   virtualisation.rosetta.enable = true;
        # If the mount is missing, the guest can fail to boot — keep off by default.
      };
    };

    # OpenSSH refuses to load a root-owned key that is group-readable, and the
    # daemon's remote-build ssh runs as root — so any chgrp of
    # /etc/nix/builder_ed25519 silently breaks all remote builds. Enforce the
    # install-credentials perms (root:nixbld 0600) on every activation; this
    # must extend postActivation since nix-darwin ignores custom script names.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      if [ -f /etc/nix/builder_ed25519 ]; then
        chgrp nixbld /etc/nix/builder_ed25519 2>/dev/null || true
        chmod 600 /etc/nix/builder_ed25519
      fi
    '';

    nix.settings.trusted-users = [ "connorfuhrman" ];
  };
}
