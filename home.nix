{ config, pkgs, gitConfig, ... }: {
  
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
      asitop  # TODO currently is specific to Apple Silicon
    ]);
  };

  programs = {
    git = {
      enable = true;
      userName = gitConfig.userName;
      userEmail = gitConfig.userEmail;
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
        atop = "sudo asitop --show_cores 1";
      };
    };
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };

}
