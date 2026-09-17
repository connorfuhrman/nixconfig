{ config, inputs, ... }: {
  # EXPERIMENTAL — see flake.hostStatus.cursor-cloud.
  # Home-only host: Cursor Cloud Agent VMs are Ubuntu we do not own.
  # No nixosConfigurations / darwinConfigurations.
  flake.homeConfigurations."ubuntu@cursor-cloud" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = config.flake.lib.pkgsFor "x86_64-linux";
    modules = [ config.flake.modules.homeManager.cursor-cloud ];
  };
}
