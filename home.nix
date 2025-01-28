{ config, pkgs, ... }: {
  
  home = {
    stateVersion = "24.11";
    packages = with pkgs; [
      wget
      bat
      screen
      htop
      portal
      cmake
      ispell
    ] ++ (if !stdenv.isDarwin then [
      # Packages to include only on non-Darwin systems
      pkgs.emacs
    ] else [
      # Apple-specific packages
      asitop  # TODO currently is specific to Apple Sillicon
    ]);
  };

  programs = {
    git = {
      enable = true;
      userName = "Connor Fuhrman";
      userEmail = "connormfuhrman@gmail.com";
      extraConfig = {
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
      };
    };
    zsh = {
      enable = true;
      shellAliases = {
        ls = "ls --color";
        ll = "ls -alh";
      };
    };
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };

}
