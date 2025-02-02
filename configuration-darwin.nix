{ config, pkgs, user, dockApps, masApps,  ... }: {
  # System-wide configuration
  system.defaults = {
    dock = {
      tilesize = 36;  # Size of dock icons when not magnified
      autohide = true;
      magnification = true;
      largesize = 46;  # Size of dock icons when magnified
      show-recents = false;
      persistent-apps = dockApps;
    };
    
    NSGlobalDomain = {
      # Scroll the correct way - down is down and up is up 
      "com.apple.swipescrolldirection" = false;

      # Trackpad speed
      "com.apple.trackpad.scaling" = 1.2;

      # Switch automatically between light and dark mode
      "AppleInterfaceStyleSwitchesAutomatically" = true;
    };

    controlcenter = {
      BatteryShowPercentage = true;
    };
  };

  # From https://github.com/LnL7/nix-darwin/issues/967
  # this is a mechanism to enable the three finger swipe down app expose
  system.activationScripts.postUserActivation.text = ''
    # activateSettings -u will reload the settings from the database and apply them to the current session,
    # so we do not need to logout and login again to make the changes take effect.
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

    # Enable App Exposé
    defaults write com.apple.dock showAppExposeGestureEnabled -bool true
    killall Dock
  '';

  # Enable keyboard navigation
  system.keyboard.enableKeyMapping = true;

  nixpkgs.config.allowUnfree = false;

  # Homebrew configuration
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap"; 
    };
    taps = [
      "d12frosted/emacs-plus"
    ];
    brews = [
      {
        name = "emacs-plus@29";
        args = [
          "with-native-comp"
          "with-savchenkovaleriy-big-sur-3d-icon"
        ];
      }
    ];
    masApps = masApps;
  };

  # Define users
  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    shell = pkgs.zsh;
  };

  # Used for backwards compatibility
  system.stateVersion = 4;
}
