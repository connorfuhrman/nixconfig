{ ... }: {
  # aarch64-linux NixOS VM builder + x86_64-linux via qemu-user binfmt.
  # Rosetta (faster x86_64) can be enabled when the Virtualization.framework
  # share is confirmed — see comment in config below. Podman+Rosetta is an
  # alternate bootstrap if the stock linux-builder is unavailable.
  flake.modules.darwin.linux-builder = { ... }: {
    nix.linux-builder = {
      enable = true;
      ephemeral = false;
      # Lower than VM cores: parallel kernel links OOM'd at 8 (build #120).
      maxJobs = 4;
      systems = [ "aarch64-linux" "x86_64-linux" ];
      config = { pkgs, lib, ... }: {
        virtualisation.cores = 8;
        virtualisation.darwin-builder.memorySize = 8 * 1024;
        virtualisation.darwin-builder.diskSize = 124 * 1024;

        nix.settings = {
          max-jobs = 4;
          extra-substituters = [
            "https://nixos-apple-silicon.cachix.org"
            "https://cache.nixos.org"
          ];
          extra-trusted-public-keys = [
            "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
            "cache.nixos.org-1:6NCHdD59X431o0gWyp1MrYtA1W29A03ad25ERVQ9Fb0="
            "cache.nixos.org-1:fj7Fj4A0i1u5w0Wd6T1cxxXZ30KHC4GKn2ax4P4CjY4="
          ];
        };

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
