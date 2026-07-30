{ ... }: {
  flake.modules.nixos.server = { pkgs, ... }: {
    # Headless server baseline. Layered on top of modules/nixos/system.nix.

    services.openssh = {
      enable = true;
      settings = {
        # Password auth stays enabled until SSH keys are deployed
        # (users.users.connor.initialPassword in system.nix is the bootstrap path).
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
    ];
  };
}