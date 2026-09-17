{ ... }: {
  # aarch64-linux NixOS VM builder + x86_64-linux via qemu-user binfmt.
  # Rosetta (faster x86_64) can be enabled when the Virtualization.framework
  # share is confirmed — see comment in config below. Podman+Rosetta is an
  # alternate bootstrap if the stock linux-builder is unavailable.
  flake.modules.darwin.linux-builder = { ... }: {
    nix.linux-builder = {
      enable = true;
      ephemeral = false;
      maxJobs = 8;
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      config = { pkgs, lib, ... }: {
        virtualisation.cores = 8;
        virtualisation.darwin-builder.memorySize = 8 * 1024;
        virtualisation.darwin-builder.diskSize = 124 * 1024;

        # Emulate x86_64-linux inside the aarch64 builder VM (works without
        # host Rosetta share). Slower than Rosetta; reliable bootstrap.
        boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
        nix.settings.extra-platforms = [ "x86_64-linux" ];

        # Faster path once the host VF exposes the "rosetta" virtiofs tag
        # (macOS Virtualization + linux-builder support). Enable deliberately:
        #   virtualisation.rosetta.enable = true;
        # If the mount is missing, the guest can fail to boot — keep off by default.
      };
    };

    nix.settings.trusted-users = [ "connorfuhrman" ];
  };
}
