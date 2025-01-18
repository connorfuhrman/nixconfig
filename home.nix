{ config, pkgs, ... }: {
  
  home = {
    stateVersion = "24.11";
    packages = with pkgs; [
      gh  # GitHub CLI 
      wget
      bat
      screen
      htop
      direnv
      portal
      python3
      julia-bin
    ] ++ (if !stdenv.isDarwin then [
      # Packages to include only on non-Darwin systems
      pkgs.emacs
    ] else []);
  };

  programs = {
    git = {
      enable = true;
      userName = "Connor Fuhrman";
      userEmail = "connormfuhrman@gmail.com";
    };
    zsh = {
      enable = true;
      shellAliases = {
        ls = "ls --color";
        ll = "ls -alh";
      };
    };
  };

}
