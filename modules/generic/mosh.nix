{ ... }: {
  # mosh client on every platform module; server (UDP 60000-61000) via programs.mosh
  # on NixOS server hosts. Import flake.modules.*.mosh from system/server/home.

  flake.modules.nixos.mosh = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.mosh ];
  };

  flake.modules.darwin.mosh = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.mosh ];
  };

  flake.modules.homeManager.mosh = { pkgs, ... }: {
    home.packages = [ pkgs.mosh ];
  };

  # Always-on Linux servers: enable moshd firewall holes.
  flake.modules.nixos.mosh-server = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.mosh ];
    programs.mosh.enable = true;
  };
}
