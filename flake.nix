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
      mkBasicConfig = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./configuration-darwin.nix
        
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.connorfuhrman = import ./home.nix;
          }
        ];
      };
    in
    {
        darwinConfigurations = {
          Connors-MacBook-Air = mkBasicConfig;
          Connors-Mac-mini = mkBasicConfig;
        };
    };
}
