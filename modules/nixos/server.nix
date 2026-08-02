{ ... }: {
  flake.modules.nixos.server = { pkgs, ... }: {
    # Headless server baseline. Layered on top of modules/nixos/system.nix.

    services.openssh = {
      enable = true;
      settings = {
        # Password auth stays enabled until SSH keys are deployed
        # (users.users.connorfuhrman.initialPassword in system.nix is the bootstrap path).
        PasswordAuthentication = true;
        KbdInteractiveAuthentication = false;
      };
    };

    environment.systemPackages = with pkgs; [
      git
      vim
      htop
      curl
      wget
      mosh
    ];

    # mosh-server: opens UDP 60000-61000 when the firewall is on.
    programs.mosh.enable = true;
  };
}