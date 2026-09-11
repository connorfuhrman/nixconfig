{ inputs, ... }: {
  # Single home Emacs module for all hosts.
  # Always install the flake-wrapped Emacs (emacsWithPackages +
  # --init-directory). The config alone is not enough: prelude package.el
  # installs are disabled and packages come only from the Nix wrapper.
  # Brew emacs-plus cannot see that package set.
  flake.modules.homeManager.emacs = { pkgs, ... }: {
    home.file.".config/emacs".source =
      inputs.emacs.packages.${pkgs.stdenv.hostPlatform.system}.emacs-config;

    home.packages = [
      inputs.emacs.packages.${pkgs.stdenv.hostPlatform.system}.emacs
    ];
  };
}
