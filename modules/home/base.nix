{ ... }: {
  # Shared base for all standalone home-manager configurations (user connor).
  flake.modules.homeManager.base = { pkgs, ... }: {
    home.username = "connorfuhrman";
    home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/connorfuhrman" else "/home/connorfuhrman";
    home.stateVersion = "25.11";

    # Let home-manager manage itself.
    programs.home-manager.enable = true;
  };
}
