{ inputs, ... }: {
  # Single home Emacs module for all hosts.
  # - Darwin: brew emacs-plus-app supplies the binary (darwin.emacs-plus);
  #   we only link the flake's emacs-config into the XDG init dir.
  # - Linux: install GUI Emacs from github:connorfuhrman/emacs (wrapped).
  flake.modules.homeManager.emacs = { pkgs, lib, ... }: {
    home.file.".config/emacs".source =
      inputs.emacs.packages.${pkgs.stdenv.hostPlatform.system}.emacs-config;

    home.packages = lib.optionals pkgs.stdenv.isLinux [
      inputs.emacs.packages.${pkgs.stdenv.hostPlatform.system}.emacs
    ];
  };
}
