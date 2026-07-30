{ ... }: {
  # Everyday CLI upgrades shared across all home configurations.
  flake.modules.homeManager.coreutils = { pkgs, ... }: {
    home.packages = with pkgs; [
      bat
      ydiff
      dust
      jq
      gtop
      gping
    ];

    programs.eza.enable = true;
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.zsh.shellAliases = {
      ls = "eza";
    };
  };
}
