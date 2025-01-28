{
  description = "Connor Fuhrman Darwin System Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-24.11";

    darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, darwin, nixpkgs, home-manager }:
    let
      mkConfig = {system ? "aarch64-darwin", user, dockApps, masApps ? {}, gitConfig} :
        darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit user dockApps masApps;
          };
          modules = [
            ./configuration-darwin.nix
        
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${user} = { ... }: {
                imports = [ ./home.nix ];
                _module.args = {
                  inherit gitConfig;
                };
              };
            }
          ];
        };

      mkPersonalConfig = mkConfig {
        user = "connorfuhrman";
        dockApps = [
          "/System/Cryptexes/App/System/Applications/Safari.app"
          "/Applications/TIDAL.app"
          "/System/Applications/Messages.app"
          "/System/Applications/Mail.app"
          "/System/Applications/Calendar.app"
          "/System/Applications/Maps.app"
          "/System/Applications/Utilities/Terminal.app"
        ];
        masApps = {
          "Amazon Prime Video" = 545519333;
          "DaisyDisk" = 411643860;
          "Dark Reader for Safari " = 1438243180;
          "Amphetamine" = 937984704;
          "Jump Desktop (RDP, VNC, Fluid)" = 524141863;
        };
        gitConfig = {
          userName = "Connor Fuhrman";
          userEmail = "connormfuhrman@gmail.com";
        };
      };
    in
    {
        darwinConfigurations = {
          Connors-MacBook-Air = mkPersonalConfig;
          Connors-Mac-mini = mkPersonalConfig;
        };
    };
}
