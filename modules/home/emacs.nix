{ inputs, ... }: {
  # GUI Emacs (Linux native / macOS macport), wrapped with the prelude-based
  # config from github.com/connorfuhrman/emacs.
  flake.modules.homeManager.emacs-gui = { pkgs, ... }: {
    home.packages = [ inputs.emacs.packages.${pkgs.stdenv.hostPlatform.system}.emacs ];
  };

  # Terminal Emacs for headless machines.
  flake.modules.homeManager.emacs-nox = { pkgs, ... }: {
    home.packages = [ inputs.emacs.packages.${pkgs.stdenv.hostPlatform.system}.emacs-nox ];
  };
}
