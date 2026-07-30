{ ... }: {
  # Runs an aarch64-linux NixOS VM and registers it as a remote builder,
  # letting this Mac build anything for aarch64-linux (e.g. Asahi images).
  flake.modules.darwin.linux-builder = { ... }: {
    nix.linux-builder = {
      enable = true;
      ephemeral = true;
      maxJobs = 4;
    };

    # Lets connor dispatch builds to the builder VM without sudo.
    nix.settings.trusted-users = [ "connorfuhrman" ];
  };
}
