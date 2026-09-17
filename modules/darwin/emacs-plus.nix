{ ... }: {
  # OPTIONAL legacy module — not imported by any host.
  # Darwin Emacs comes from homeManager.emacs (flake-wrapped emacs-macport
  # with packages + --init-directory). Brew emacs-plus cannot see the Nix
  # package set, and prelude package.el installs are disabled in emacs-config.
  # Kept only if you deliberately want a parallel Homebrew Emacs.app.
  flake.modules.darwin.emacs-plus = { ... }: {
    homebrew.enable = true;
    homebrew.taps = [
      {
        name = "d12frosted/emacs-plus";
        trusted = true;
      }
    ];
    homebrew.casks = [ "emacs-plus-app" ];
  };
}
