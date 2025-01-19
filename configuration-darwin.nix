{ config, pkgs, ... }: {
  # System-wide configuration
  system.defaults = {
    dock = {
      tilesize = 36;
      autohide = true;
      magnification = true;
      largesize = 46;  # Size of dock icons when magnified (max: 128)
      show-recents = false;
      persistent-apps = [
        "/System/Cryptexes/App/System/Applications/Safari.app"
        "/Applications/TIDAL.app"
        "/System/Applications/Messages.app"
        "/System/Applications/Mail.app"
        "/System/Applications/Calendar.app"
        "/System/Applications/Maps.app"
        "/System/Applications/Utilities/Terminal.app"
      ];
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
        name = "emacs-plus@30";
        args = [
          "with-native-comp"
          "with-modern-icon"
        ];
      }
      # Install libvterm for emacs vterm package
      {
        name = "libvterm";
      }
    ];
    masApps = {
      "Amazon Prime Video" = 545519333;
      "DaisyDisk" = 411643860;
      "Dark Reader for Safari " = 1438243180;
      # Better to install Tailscale via the package than the App Store
      # "Tailscale" = 1475387142;
      "Amphetamine" = 937984704;
      "Jump Desktop (RDP, VNC, Fluid)" = 524141863;
    };
  };

  # Define users
  users.users.connorfuhrman = {
    name = "connorfuhrman";
    home = "/Users/connorfuhrman";
    shell = pkgs.zsh;
  };

  # Used for backwards compatibility
  system.stateVersion = 4;
}
