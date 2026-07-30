{ inputs, ... }: {
  # Wire the brew-installed emacs-plus to the wrapped prelude-based config
  # from github.com/connorfuhrman/emacs.
  #
  # Emacs 27+ reads ~/.config/emacs as its init directory (XDG), so linking
  # the flake's emacs-config package there works for both the GUI app and
  # the emacs CLI — no wrapper flags needed. The config redirects writable
  # state to ~/.cache/emacs itself (same as the flake's wrapped binaries).
  flake.modules.homeManager.emacs-plus = { pkgs, ... }: {
    home.file.".config/emacs".source =
      inputs.emacs.packages.${pkgs.stdenv.hostPlatform.system}.emacs-config;
  };
}
